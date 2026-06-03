import 'dart:math';
import 'package:alarm/alarm.dart';
import '../shared/models.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  Future<void> init() async {
    await Alarm.init();
  }

  int _getAlarmId(String medicineId, int timeIndex) {
    return (medicineId.hashCode + timeIndex).abs() % 10000;
  }

  /// Schedules alarms for a medicine if alarms are enabled.
  Future<void> scheduleMedicineAlarms(Medicine medicine) async {
    await cancelMedicineAlarms(medicine);

    if (!medicine.alarmEnabled) return;

    final today = DateTime.now();
    final endOfCourse = DateTime(medicine.endDate.year, medicine.endDate.month, medicine.endDate.day, 23, 59, 59);
    if (today.isAfter(endOfCourse)) {
      return;
    }

    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final timeStr = medicine.reminderTimes[i];
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) continue;

      final hour = int.tryParse(timeParts[0]) ?? 8;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final alarmId = _getAlarmId(medicine.id, i);
      final alarmTime = _nextInstanceOfTime(hour, minute);

      // Only schedule if the alarm time is within the medicine course duration
      if (alarmTime.isAfter(endOfCourse)) continue;

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: alarmTime,
        assetAudioPath: 'assets/audio/alarm.mp3', // Configured in pubspec.yaml
        loopAudio: true,
        vibrate: true,
        notificationSettings: NotificationSettings(
          title: 'Medicine Alarm: ${medicine.name}',
          body: 'Time to take your ${medicine.name} ${medicine.strength} (${medicine.foodRelation})!',
          stopButton: 'Stop',
        ),
        volumeSettings: const VolumeSettings.fixed(
          volume: 0.8,
        ),
      );

      try {
        await Alarm.set(alarmSettings: alarmSettings);
        print("Alarm scheduled successfully: id=$alarmId at $alarmTime");
      } catch (e) {
        print("Error scheduling alarm: $e");
      }
    }
  }

  /// Cancels all alarms for a medicine.
  Future<void> cancelMedicineAlarms(Medicine medicine) async {
    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final alarmId = _getAlarmId(medicine.id, i);
      try {
        await Alarm.stop(alarmId);
      } catch (e) {
        // Ignore errors if alarm was not set
      }
    }
  }

  /// Stops an active ringing alarm.
  Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
  }

  /// Snoozes a running alarm by resetting it for 5 minutes later.
  Future<void> snoozeAlarm(AlarmSettings activeAlarm) async {
    await Alarm.stop(activeAlarm.id);
    final snoozedTime = DateTime.now().add(const Duration(minutes: 5));
    final newSettings = activeAlarm.copyWith(
      dateTime: snoozedTime,
    );
    await Alarm.set(alarmSettings: newSettings);
  }

  /// Helper to get the stream of ringing alarms
  Stream<AlarmSettings> get ringStream => Alarm.ringing
      .where((alarmSet) => alarmSet.alarms.isNotEmpty)
      .map((alarmSet) => alarmSet.alarms.first);

  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
