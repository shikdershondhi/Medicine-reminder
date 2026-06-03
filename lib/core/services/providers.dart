import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/models.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'drive_service.dart';
import 'notification_service.dart';
import 'alarm_service.dart';
import 'medex_service.dart';

// --- Services Providers ---
final dbServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final driveServiceProvider = Provider<DriveService>((ref) => DriveService());
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
final alarmServiceProvider = Provider<AlarmService>((ref) => AlarmService());
final medExServiceProvider = Provider<MedExService>((ref) => MedExService());

// --- Theme State ---
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(dbServiceProvider);
  return ThemeModeNotifier(db);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final DatabaseService _db;
  ThemeModeNotifier(this._db) : super(_db.isDarkMode() ? ThemeMode.dark : ThemeMode.light);

  void toggle() async {
    final value = state == ThemeMode.dark;
    await _db.setDarkMode(!value);
    state = !value ? ThemeMode.dark : ThemeMode.light;
  }
}

// --- Auth State ---
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    // Sync current user
    state = AsyncValue.data(_authService.currentUser);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null) {
        state = AsyncValue.data(credential.user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithEmailAndPassword(email, password);
      if (credential != null) {
        state = AsyncValue.data(credential.user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signUpWithEmailAndPassword(email, password);
      if (credential != null) {
        state = AsyncValue.data(credential.user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      await DatabaseService().clearAllData(); // Clear local cache on logout
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// --- Profile State ---
final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  final db = ref.watch(dbServiceProvider);
  return ProfileNotifier(db);
});

class ProfileNotifier extends StateNotifier<UserProfile> {
  final DatabaseService _db;
  ProfileNotifier(this._db) : super(_db.getProfile());

  Future<void> saveProfile(UserProfile profile) async {
    await _db.saveProfile(profile);
    state = profile;
  }
  
  void refresh() {
    state = _db.getProfile();
  }
}

// --- Prescriptions State ---
final prescriptionsProvider = StateNotifierProvider<PrescriptionsNotifier, List<DoctorPrescription>>((ref) {
  final db = ref.watch(dbServiceProvider);
  final notif = ref.watch(notificationServiceProvider);
  return PrescriptionsNotifier(db, notif);
});

class PrescriptionsNotifier extends StateNotifier<List<DoctorPrescription>> {
  final DatabaseService _db;
  final NotificationService _notificationService;
  PrescriptionsNotifier(this._db, this._notificationService) : super([]) {
    load();
  }

  void load() {
    final list = _db.getPrescriptions();
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate)); // latest visit first
    state = list;
  }

  Future<void> addPrescription(DoctorPrescription prescription) async {
    await _db.savePrescription(prescription);
    await _notificationService.schedulePrescriptionVisitReminder(prescription);
    load();
  }

  Future<void> updatePrescription(DoctorPrescription prescription) async {
    await _db.savePrescription(prescription);
    await _notificationService.schedulePrescriptionVisitReminder(prescription);
    load();
  }

  Future<void> deletePrescription(String id) async {
    final prescription = _db.getPrescription(id);
    if (prescription != null) {
      await _notificationService.cancelPrescriptionVisitReminder(prescription);
    }
    await _db.deletePrescription(id);
    load();
  }
}

// --- Medicines State ---
final medicinesProvider = StateNotifierProvider<MedicinesNotifier, List<Medicine>>((ref) {
  final db = ref.watch(dbServiceProvider);
  final notif = ref.watch(notificationServiceProvider);
  final alarm = ref.watch(alarmServiceProvider);
  return MedicinesNotifier(db, notif, alarm);
});

class MedicinesNotifier extends StateNotifier<List<Medicine>> {
  final DatabaseService _db;
  final NotificationService _notificationService;
  final AlarmService _alarmService;

  MedicinesNotifier(this._db, this._notificationService, this._alarmService) : super([]) {
    load();
  }

  void load() {
    state = _db.getAllMedicines();
  }

  Future<void> saveMedicine(Medicine medicine) async {
    await _db.saveMedicine(medicine);
    
    // Reschedule notifications & alarms
    await _notificationService.scheduleMedicineReminders(medicine);
    await _alarmService.scheduleMedicineAlarms(medicine);
    
    load();
  }

  Future<void> deleteMedicine(String id) async {
    final medicine = _db.getMedicine(id);
    if (medicine != null) {
      await _notificationService.cancelMedicineReminders(medicine);
      await _alarmService.cancelMedicineAlarms(medicine);
    }
    
    await _db.deleteMedicine(id);
    load();
  }
}

// --- Sync State ---
enum SyncStatus { idle, syncing, success, conflict, error, noBackup }

final syncProvider = StateNotifierProvider<SyncNotifier, SyncStatus>((ref) {
  final drive = ref.watch(driveServiceProvider);
  final db = ref.watch(dbServiceProvider);
  return SyncNotifier(drive, db, ref);
});

class SyncNotifier extends StateNotifier<SyncStatus> {
  final DriveService _driveService;
  final DatabaseService _dbService;
  final Ref _ref;

  SyncNotifier(this._driveService, this._dbService, this._ref) : super(SyncStatus.idle);

  Future<void> performSync() async {
    state = SyncStatus.syncing;
    try {
      final result = await _driveService.sync();
      if (result == 'success') {
        state = SyncStatus.success;
        // Refresh local cache values in UI
        _ref.read(profileProvider.notifier).refresh();
        _ref.read(prescriptionsProvider.notifier).load();
        _ref.read(medicinesProvider.notifier).load();
      } else if (result == 'conflict') {
        state = SyncStatus.conflict;
      } else if (result == 'no_backup') {
        state = SyncStatus.noBackup;
      } else {
        state = SyncStatus.error;
      }
    } catch (e) {
      state = SyncStatus.error;
    }
  }

  Future<void> resolveConflictKeepRemote() async {
    state = SyncStatus.syncing;
    final success = await _driveService.forceRestoreFromRemote();
    if (success) {
      state = SyncStatus.success;
      _ref.read(profileProvider.notifier).refresh();
      _ref.read(prescriptionsProvider.notifier).load();
      _ref.read(medicinesProvider.notifier).load();
    } else {
      state = SyncStatus.error;
    }
  }

  Future<void> resolveConflictKeepLocal() async {
    state = SyncStatus.syncing;
    final success = await _driveService.uploadBackup();
    state = success ? SyncStatus.success : SyncStatus.error;
  }
}

// --- Medicine Intake Logs State ---
final logsProvider = StateNotifierProvider<LogsNotifier, List<MedicineLog>>((ref) {
  final db = ref.watch(dbServiceProvider);
  final meds = ref.watch(medicinesProvider.notifier);
  return LogsNotifier(db, meds);
});

class LogsNotifier extends StateNotifier<List<MedicineLog>> {
  final DatabaseService _db;
  final MedicinesNotifier _medsNotifier;

  LogsNotifier(this._db, this._medsNotifier) : super([]) {
    load();
  }

  void load() {
    state = _db.getAllLogs();
  }

  Future<void> markDose({
    required String medicineId,
    required String scheduledTime,
    required String status, // "taken", "skipped", "missed"
    required DateTime date,
  }) async {
    final dateKey = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final logId = '${medicineId}_${dateKey}_$scheduledTime';
    
    final log = MedicineLog(
      id: logId,
      medicineId: medicineId,
      takenDateTime: DateTime.now(),
      scheduledTime: scheduledTime,
      status: status,
    );

    await _db.saveLog(log);
    load();
  }
  
  Future<void> deleteLog(String id) async {
    await _db.deleteLog(id);
    load();
  }
}

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
