import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'database_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MedExSearchResult {
  final String name;
  final String strength;
  final String generic;
  final String manufacturer;
  final String url;

  MedExSearchResult({
    required this.name,
    required this.strength,
    required this.generic,
    required this.manufacturer,
    required this.url,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'strength': strength,
      'generic': generic,
      'manufacturer': manufacturer,
      'url': url,
    };
  }

  factory MedExSearchResult.fromMap(Map<String, dynamic> map) {
    return MedExSearchResult(
      name: map['name'] ?? '',
      strength: map['strength'] ?? '',
      generic: map['generic'] ?? '',
      manufacturer: map['manufacturer'] ?? '',
      url: map['url'] ?? '',
    );
  }
}

class MedExService {
  final DatabaseService _dbService = DatabaseService();
  final Map<String, List<MedExSearchResult>> _memoryCache = {};

  static final MedExService _instance = MedExService._internal();
  factory MedExService() => _instance;
  MedExService._internal();

  /// Searches for medicines on MedEx.
  /// First checks memory cache, then local database cache, and finally crawls the live site.
  Future<List<MedExSearchResult>> search(String query) async {
    final cleanedQuery = query.trim().toLowerCase();
    if (cleanedQuery.isEmpty) return [];

    // 1. Check Memory Cache
    if (_memoryCache.containsKey(cleanedQuery)) {
      return _memoryCache[cleanedQuery]!;
    }

    // 2. Check Database Cache (recent offline searches)
    final cachedData = _dbService.getRecentSearches();
    // We can also store the actual query results in a dedicated Box in DB.
    // To make it easy, we store in database_service.dart the queries, 
    // and let's check if we can fetch results from the database.
    // To implement search caching inside Hive, we will use a cache box key: 'query_$cleanedQuery'.
    final dbBox = Hive.box('search_cache');
    final dbCachedList = dbBox.get('results_$cleanedQuery');
    if (dbCachedList != null) {
      try {
        final list = (dbCachedList as List).map((item) {
          return MedExSearchResult.fromMap(Map<String, dynamic>.from(item as Map));
        }).toList();
        _memoryCache[cleanedQuery] = list;
        return list;
      } catch (e) {
        print("Error parsing DB search cache: $e");
      }
    }

    // 3. Crawl Live Site
    try {
      final url = Uri.parse('https://medex.com.bd/search?search=${Uri.encodeComponent(query)}');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception("Failed to load page");
      }

      final document = html_parser.parse(response.body);
      final rows = document.querySelectorAll('.search-result-row');
      final List<MedExSearchResult> results = [];

      for (final row in rows) {
        final aTag = row.querySelector('.search-result-title a');
        if (aTag == null) continue;
        
        final title = aTag.text.trim();
        final href = aTag.attributes['href'] ?? '';
        
        final pTag = row.querySelector('p');
        String manufacturer = 'Unknown';
        String genericName = 'Unknown';
        
        if (pTag != null) {
          final iTag = pTag.querySelector('i');
          if (iTag != null) {
            genericName = iTag.text.replaceAll('(', '').replaceAll(')', '').trim();
          }
          final pText = pTag.text;
          final mIndex = pText.indexOf('is manufactured by');
          if (mIndex != -1) {
            manufacturer = pText.substring(mIndex + 'is manufactured by'.length).trim();
            if (manufacturer.endsWith('.')) {
              manufacturer = manufacturer.substring(0, manufacturer.length - 1);
            }
          }
        }

        // Separate Name and Strength if possible
        // Example title: "Napa One 1000 mg (Tablet)" or "Napa 120 mg/5 ml (Syrup)"
        String name = title;
        String strength = '';
        
        // Remove dosage form (e.g. "(Tablet)" or "(Syrup)")
        final formRegex = RegExp(r'\s*\([^)]+\)$');
        name = name.replaceAll(formRegex, '').trim();

        // Extract strength (e.g. "1000 mg" or "120 mg/5 ml")
        final strengthRegex = RegExp(r'\s+(\d+\s*(?:mg|ml|mcg|g|%)(?:\/\d+\s*(?:mg|ml|mcg|g|%))*)');
        final match = strengthRegex.firstMatch(name);
        if (match != null) {
          strength = match.group(1)?.trim() ?? '';
          name = name.replaceFirst(strength, '').trim();
        }

        results.add(MedExSearchResult(
          name: name,
          strength: strength,
          generic: genericName,
          manufacturer: manufacturer,
          url: href,
        ));
      }

      // Add to search caches
      if (results.isNotEmpty) {
        _memoryCache[cleanedQuery] = results;
        await dbBox.put('results_$cleanedQuery', results.map((r) => r.toMap()).toList());
        await _dbService.addRecentSearch(query);
      }

      return results;
    } catch (e) {
      print("MedEx crawl failed: $e");
      // Fallback: If offline/unreachable and not cached, return empty list or look at similar cached searches.
      return [];
    }
  }

  /// Get autocomplete suggestions based on recently searched terms
  List<String> getSuggestions(String query) {
    final history = _dbService.getRecentSearches();
    if (query.isEmpty) return history;
    
    return history
        .where((q) => q.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
