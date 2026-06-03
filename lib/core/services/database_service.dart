import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../shared/models.dart';

class DatabaseService {
  late Box _settingsBox;
  late Box _prescriptionsBox;
  late Box _medicinesBox;
  late Box _logsBox;
  late Box _searchCacheBox;
  late Box _accountsBox;

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    
    _settingsBox = await Hive.openBox('settings');
    _prescriptionsBox = await Hive.openBox('prescriptions');
    _medicinesBox = await Hive.openBox('medicines');
    _logsBox = await Hive.openBox('logs');
    _searchCacheBox = await Hive.openBox('search_cache');
    _accountsBox = await Hive.openBox('accounts');
  }

  // --- Local User Accounts ---
  Future<void> saveAccount(String username, String password) async {
    await _accountsBox.put(username.toLowerCase().trim(), password);
  }

  String? getAccountPassword(String username) {
    return _accountsBox.get(username.toLowerCase().trim());
  }

  bool hasAccount(String username) {
    return _accountsBox.containsKey(username.toLowerCase().trim());
  }

  // --- Profile & Settings ---
  Future<void> saveProfile(UserProfile profile) async {
    await _settingsBox.put('profile', profile.toMap());
  }

  UserProfile getProfile() {
    final map = _settingsBox.get('profile');
    if (map == null) return UserProfile.empty();
    return UserProfile.fromMap(Map<dynamic, dynamic>.from(map));
  }

  bool isDarkMode() {
    return _settingsBox.get('darkMode', defaultValue: false) == true;
  }

  Future<void> setDarkMode(bool value) async {
    await _settingsBox.put('darkMode', value);
  }

  DateTime? getLastSync() {
    final timeStr = _settingsBox.get('lastSync');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr.toString());
  }

  Future<void> setLastSync(DateTime time) async {
    await _settingsBox.put('lastSync', time.toIso8601String());
  }

  // --- Prescriptions CRUD ---
  List<DoctorPrescription> getPrescriptions() {
    return _prescriptionsBox.values.map((map) {
      return DoctorPrescription.fromMap(Map<dynamic, dynamic>.from(map));
    }).toList();
  }

  DoctorPrescription? getPrescription(String id) {
    final map = _prescriptionsBox.get(id);
    if (map == null) return null;
    return DoctorPrescription.fromMap(Map<dynamic, dynamic>.from(map));
  }

  Future<void> savePrescription(DoctorPrescription prescription) async {
    await _prescriptionsBox.put(prescription.id, prescription.toMap());
  }

  Future<void> deletePrescription(String id) async {
    await _prescriptionsBox.delete(id);
    // Delete all medicines under this prescription
    final medicines = getMedicines(id);
    for (var med in medicines) {
      await deleteMedicine(med.id);
    }
  }

  // --- Medicines CRUD ---
  List<Medicine> getAllMedicines() {
    return _medicinesBox.values.map((map) {
      return Medicine.fromMap(Map<dynamic, dynamic>.from(map));
    }).toList();
  }

  List<Medicine> getMedicines(String prescriptionId) {
    return getAllMedicines().where((med) => med.prescriptionId == prescriptionId).toList();
  }

  Medicine? getMedicine(String id) {
    final map = _medicinesBox.get(id);
    if (map == null) return null;
    return Medicine.fromMap(Map<dynamic, dynamic>.from(map));
  }

  Future<void> saveMedicine(Medicine medicine) async {
    await _medicinesBox.put(medicine.id, medicine.toMap());
  }

  Future<void> deleteMedicine(String id) async {
    await _medicinesBox.delete(id);
    // Delete logs for this medicine
    final logs = getLogsForMedicine(id);
    for (var log in logs) {
      await deleteLog(log.id);
    }
  }

  // --- Medicine Logs CRUD ---
  List<MedicineLog> getAllLogs() {
    return _logsBox.values.map((map) {
      return MedicineLog.fromMap(Map<dynamic, dynamic>.from(map));
    }).toList();
  }

  List<MedicineLog> getLogsForMedicine(String medicineId) {
    return getAllLogs().where((log) => log.medicineId == medicineId).toList();
  }

  Future<void> saveLog(MedicineLog log) async {
    await _logsBox.put(log.id, log.toMap());
  }

  Future<void> deleteLog(String id) async {
    await _logsBox.delete(id);
  }

  // --- MedEx Search Cache ---
  List<String> getRecentSearches() {
    return List<String>.from(_searchCacheBox.get('recent_searches', defaultValue: []));
  }

  Future<void> addRecentSearch(String query) async {
    final list = getRecentSearches();
    if (list.contains(query)) {
      list.remove(query);
    }
    list.insert(0, query);
    if (list.length > 20) {
      list.removeLast();
    }
    await _searchCacheBox.put('recent_searches', list);
  }

  // --- Clear Data ---
  Future<void> clearAllData() async {
    await _settingsBox.clear();
    await _prescriptionsBox.clear();
    await _medicinesBox.clear();
    await _logsBox.clear();
    await _searchCacheBox.clear();
  }

  // --- Backup & Restore ---
  Map<String, dynamic> exportBackupData() {
    final profile = getProfile();
    final prescriptions = getPrescriptions().map((p) => p.toMap()).toList();
    final medicines = getAllMedicines().map((m) => m.toMap()).toList();
    final logs = getAllLogs().map((l) => l.toMap()).toList();
    final lastSync = getLastSync()?.toIso8601String();
    final darkMode = isDarkMode();

    return {
      'version': 1,
      'profile': profile.toMap(),
      'prescriptions': prescriptions,
      'medicines': medicines,
      'logs': logs,
      'darkMode': darkMode,
      'lastSync': lastSync,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importBackupData(Map<String, dynamic> backup) async {
    // Basic structural verification
    if (backup['profile'] != null) {
      await saveProfile(UserProfile.fromMap(backup['profile']));
    }
    if (backup['darkMode'] != null) {
      await setDarkMode(backup['darkMode'] == true);
    }

    // Replace prescriptions
    await _prescriptionsBox.clear();
    if (backup['prescriptions'] != null) {
      final list = backup['prescriptions'] as List;
      for (var p in list) {
        if (p is Map) {
          final prescription = DoctorPrescription.fromMap(p);
          await savePrescription(prescription);
        }
      }
    }

    // Replace medicines
    await _medicinesBox.clear();
    if (backup['medicines'] != null) {
      final list = backup['medicines'] as List;
      for (var m in list) {
        if (m is Map) {
          final medicine = Medicine.fromMap(m);
          await saveMedicine(medicine);
        }
      }
    }

    // Replace logs
    await _logsBox.clear();
    if (backup['logs'] != null) {
      final list = backup['logs'] as List;
      for (var l in list) {
        if (l is Map) {
          final log = MedicineLog.fromMap(l);
          await saveLog(log);
        }
      }
    }

    if (backup['timestamp'] != null) {
      final date = DateTime.tryParse(backup['timestamp'].toString());
      if (date != null) {
        await setLastSync(date);
      }
    }
  }
}
