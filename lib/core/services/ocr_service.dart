import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------
abstract class OcrService {
  Future<String> recognizeText(File imageFile);
  Future<List<Map<String, dynamic>>> extractMedicines(String text);
}

// ---------------------------------------------------------------------------
// Real ML Kit–powered OCR service (offline, on-device, Latin script)
// ---------------------------------------------------------------------------
class RealOcrService implements OcrService {
  static final RealOcrService _instance = RealOcrService._internal();
  factory RealOcrService() => _instance;
  RealOcrService._internal();

  /// Runs Google ML Kit text recognition on [imageFile] and returns raw text.
  @override
  Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    // Create a fresh recognizer per call so we can close it and free memory
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Parses the raw OCR text into structured medicine entries.
  @override
  Future<List<Map<String, dynamic>>> extractMedicines(String text) async {
    return PrescriptionParser.parse(text);
  }
}

// ---------------------------------------------------------------------------
// Prescription text parser
// Handles common formats found on hand-written and printed prescriptions:
//   • Numbered entries  — "1. Napa 500mg"
//   • Dot-notation dose — "1+0+1", "1+1+1"
//   • Medical abbreviations — OD, BD, TDS/TID, QDS/QID
//   • Plain English    — "twice daily", "three times a day"
//   • Duration         — "7 days", "for 5 days"
//   • Food relation    — "before meal", "after food", "with meal"
// ---------------------------------------------------------------------------
class PrescriptionParser {
  // ---- compiled regex patterns (static, compiled once) -------------------

  // Strength: "500 mg", "250mg", "10 mcg", "5 ml"
  static final _strengthRx = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|iu)\b',
    caseSensitive: false,
  );

  // Duration: "7 days", "for 5 days", "7 day"
  static final _durationRx = RegExp(
    r'\b(?:for\s+)?(\d+)\s*days?\b',
    caseSensitive: false,
  );

  // Food relation
  static final _foodRx = RegExp(
    r'\b(before|after|with)\s+(?:meal|food|meals|eating)\b',
    caseSensitive: false,
  );

  // Dose notation "1+0+1" or "1+1+1" (sum = intakePerDay)
  static final _dotDoseRx = RegExp(r'(\d)\s*\+\s*(\d)\s*\+\s*(\d)');

  // Numbered prescription entry start: "1." or "1)"
  static final _entryStartRx = RegExp(
    r'(?:^|\n)\s*\d+\s*[.)]\s*',
    multiLine: true,
  );

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> parse(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final entryMatches = _entryStartRx.allMatches(rawText).toList();

    if (entryMatches.isEmpty) {
      // No numbered entries — try to treat the whole block as one medicine
      return _parseSingleBlock(rawText);
    }

    final meds = <Map<String, dynamic>>[];
    for (int i = 0; i < entryMatches.length; i++) {
      final blockStart = entryMatches[i].end;
      final blockEnd =
          i + 1 < entryMatches.length ? entryMatches[i + 1].start : rawText.length;
      final block = rawText.substring(blockStart, blockEnd).trim();
      if (block.isEmpty) continue;

      final med = _parseBlock(block);
      if (med != null) meds.add(med);
    }
    return meds;
  }

  // ---------------------------------------------------------------------------
  // Parse one numbered medicine block
  // ---------------------------------------------------------------------------
  static Map<String, dynamic>? _parseBlock(String block) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    // First line usually has "MedicineName Strength (Form)"
    final firstLine = lines.first;

    // Strip bracketed form type: "(Tablet)", "(Capsule)", "(Syrup)"
    final cleanFirst = firstLine.replaceAll(RegExp(r'\(.*?\)'), '').trim();

    // Extract strength from the first line
    final strengthMatch = _strengthRx.firstMatch(cleanFirst);
    final String strength;
    final String name;

    if (strengthMatch != null) {
      strength =
          '${strengthMatch.group(1)} ${strengthMatch.group(2)!.toLowerCase()}';
      name = cleanFirst.substring(0, strengthMatch.start).trim();
    } else {
      // Strength may be on a later line
      strength = _extractStrength(block);
      name = cleanFirst;
    }

    // Sanity check: name must be non-empty and reasonably alphabetic
    final cleanName = name.replaceAll(RegExp(r'[^A-Za-z\s\-]'), '').trim();
    if (cleanName.length < 2) return null;

    final freq = _parseFrequency(block);
    final duration = _parseDuration(block);
    final food = _parseFoodRelation(block);

    return {
      'name': _toTitleCase(cleanName),
      'strength': strength,
      'intakePerDay': freq,
      'foodRelation': food,
      'durationDays': duration,
      'reminderTimes': _reminderTimes(freq),
    };
  }

  // ---------------------------------------------------------------------------
  // Single-block fallback (no numbered entries found)
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _parseSingleBlock(String text) {
    final strength = _extractStrength(text);
    final freq = _parseFrequency(text);
    final duration = _parseDuration(text);
    final food = _parseFoodRelation(text);

    // Try to grab the first meaningful word sequence as the name
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    final firstLine = lines.isNotEmpty ? lines.first : '';
    final cleanFirst = firstLine
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(_strengthRx, '')
        .trim();
    final cleanName = cleanFirst.replaceAll(RegExp(r'[^A-Za-z\s\-]'), '').trim();
    if (cleanName.length < 2) return [];

    return [
      {
        'name': _toTitleCase(cleanName),
        'strength': strength,
        'intakePerDay': freq,
        'foodRelation': food,
        'durationDays': duration,
        'reminderTimes': _reminderTimes(freq),
      }
    ];
  }

  // ---------------------------------------------------------------------------
  // Helper extractors
  // ---------------------------------------------------------------------------

  static String _extractStrength(String block) {
    final m = _strengthRx.firstMatch(block);
    if (m == null) return '';
    return '${m.group(1)} ${m.group(2)!.toLowerCase()}';
  }

  static int _parseFrequency(String block) {
    // 1. Check dot-dose notation  "1+0+1" → sum non-zero pills
    final dotMatch = _dotDoseRx.firstMatch(block);
    if (dotMatch != null) {
      final sum = int.parse(dotMatch.group(1)!) +
          int.parse(dotMatch.group(2)!) +
          int.parse(dotMatch.group(3)!);
      if (sum > 0) return sum;
    }

    // 2. Medical abbreviations (case-insensitive whole-word)
    if (RegExp(r'\bQDS\b|\bQID\b', caseSensitive: false).hasMatch(block)) return 4;
    if (RegExp(r'\bTDS\b|\bTID\b', caseSensitive: false).hasMatch(block)) return 3;
    if (RegExp(r'\bBD\b', caseSensitive: false).hasMatch(block)) return 2;
    if (RegExp(r'\bOD\b', caseSensitive: false).hasMatch(block)) return 1;

    // 3. Plain English
    if (RegExp(r'\bfour\s*times\b|\b4\s*times\b', caseSensitive: false).hasMatch(block)) return 4;
    if (RegExp(r'\bthree\s*times\b|\bthrice\b|\b3\s*times\b', caseSensitive: false).hasMatch(block)) return 3;
    if (RegExp(r'\btwice\b|\btwo\s*times\b|\b2\s*times\b', caseSensitive: false).hasMatch(block)) return 2;
    if (RegExp(r'\bonce\b|\bone\s*time\b|\b1\s*time\b', caseSensitive: false).hasMatch(block)) return 1;

    // 4. Qty-based guess: Qty NN → if duration is known, freq = Qty / duration
    final qtyMatch = RegExp(r'Qty[:\s]+(\d+)', caseSensitive: false).firstMatch(block);
    if (qtyMatch != null) {
      final qty = int.tryParse(qtyMatch.group(1)!) ?? 0;
      final dur = _parseDuration(block);
      if (qty > 0 && dur > 0) {
        final computed = (qty / dur).round();
        if (computed >= 1 && computed <= 4) return computed;
      }
    }

    return 1; // Default: once daily
  }

  static int _parseDuration(String block) {
    final m = _durationRx.firstMatch(block);
    if (m == null) return 7; // default 7 days
    return int.tryParse(m.group(1)!) ?? 7;
  }

  static String _parseFoodRelation(String block) {
    final m = _foodRx.firstMatch(block);
    if (m == null) return 'After Meal';
    switch (m.group(1)!.toLowerCase()) {
      case 'before': return 'Before Meal';
      case 'with':   return 'With Meal';
      default:       return 'After Meal';
    }
  }

  static List<String> _reminderTimes(int frequency) {
    switch (frequency) {
      case 1:  return ['08:00'];
      case 2:  return ['08:00', '20:00'];
      case 3:  return ['08:00', '14:00', '20:00'];
      case 4:  return ['08:00', '12:00', '16:00', '20:00'];
      default: return ['08:00'];
    }
  }

  static String _toTitleCase(String s) {
    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

// ---------------------------------------------------------------------------
// Keep MockOcrService for unit testing / offline demo fallback only
// ---------------------------------------------------------------------------
class MockOcrService implements OcrService {
  @override
  Future<String> recognizeText(File imageFile) async {
    await Future.delayed(const Duration(seconds: 2));
    return """
Dr. Rashedul Islam
MD, Medicine
Visit Date: 2026-06-03
Rx
1. Napa 500 mg (Tablet)
   Qty: 14 Tablets
   Dose: 1 pill - twice daily (1+0+1) - After Meal
   Duration: 7 Days
   
2. Amoxicillin 500 mg (Capsule)
   Qty: 15 Capsules
   Dose: 1 pill - three times daily (1+1+1) - Before Meal
   Duration: 5 Days
    """;
  }

  @override
  Future<List<Map<String, dynamic>>> extractMedicines(String text) async {
    return PrescriptionParser.parse(text);
  }
}
