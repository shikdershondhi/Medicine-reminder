import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../shared/models.dart';
import 'database_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final DatabaseService _dbService = DatabaseService();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
        
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;
    
    if (payload == null) return;
    
    // Payload format: "medicineId|scheduledTime"
    final parts = payload.split('|');
    if (parts.length < 2) return;
    
    final medicineId = parts[0];
    final scheduledTime = parts[1];

    if (actionId == 'taken') {
      await _logIntake(medicineId, scheduledTime, 'taken');
    } else if (actionId == 'skip') {
      await _logIntake(medicineId, scheduledTime, 'skipped');
    } else if (actionId == 'snooze') {
      await snoozeNotification(medicineId, scheduledTime);
    }
  }

  Future<void> _logIntake(String medicineId, String scheduledTime, String status) async {
    final log = MedicineLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicineId: medicineId,
      takenDateTime: DateTime.now(),
      scheduledTime: scheduledTime,
      status: status,
    );
    await _dbService.saveLog(log);
  }

  /// Unique notification ID based on medicine database ID hash and time index
  int _getNotificationId(String medicineId, int timeIndex) {
    return (medicineId.hashCode + timeIndex).abs() % 100000;
  }

  /// Schedules daily repeating notifications for the medicine's reminder times.
  Future<void> scheduleMedicineReminders(Medicine medicine) async {
    // First cancel any existing notifications for this medicine
    await cancelMedicineReminders(medicine);

    // If the medicine duration has already ended, don't schedule
    final today = DateTime.now();
    final endOfCourse = DateTime(medicine.endDate.year, medicine.endDate.month, medicine.endDate.day, 23, 59, 59);
    if (today.isAfter(endOfCourse)) {
      return;
    }

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Channel for scheduled medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('taken', 'Mark as Taken', showsUserInterface: false),
        const AndroidNotificationAction('snooze', 'Snooze 10m', showsUserInterface: false),
        const AndroidNotificationAction('skip', 'Skip', showsUserInterface: false),
      ],
    );

    const iosPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'medicine_actions',
    );

    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final timeStr = medicine.reminderTimes[i];
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) continue;

      final hour = int.tryParse(timeParts[0]) ?? 8;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final notificationId = _getNotificationId(medicine.id, i);

      // Construct matching daily time component
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Time for ${medicine.name} ${medicine.strength}',
        body: 'Please take your medicine (${medicine.foodRelation}).',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '${medicine.id}|$timeStr',
      );
    }
  }

  /// Cancels all scheduled notifications for a medicine.
  Future<void> cancelMedicineReminders(Medicine medicine) async {
    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final notificationId = _getNotificationId(medicine.id, i);
      await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    }
  }

  /// Schedules a one-off reminder notification 10 minutes in the future.
  Future<void> snoozeNotification(String medicineId, String scheduledTime) async {
    final medicine = _dbService.getMedicine(medicineId);
    final medName = medicine?.name ?? 'Medicine';
    final medStrength = medicine?.strength ?? '';
    
    final androidDetails = const AndroidNotificationDetails(
      'medicine_snoozes',
      'Snoozed Reminders',
      channelDescription: 'Channel for snoozed medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    final notificationId = Random().nextInt(100000) + 100000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Snoozed: $medName $medStrength',
      body: 'Reminder for your dose scheduled at $scheduledTime.',
      scheduledDate: snoozeTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$medicineId|$scheduledTime',
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedules a one-off notification for a doctor visit one day before.
  Future<void> schedulePrescriptionVisitReminder(DoctorPrescription prescription) async {
    final nextVisit = prescription.nextVisitDate;
    if (nextVisit == null) return;

    // First cancel any existing visit reminder for this prescription
    await cancelPrescriptionVisitReminder(prescription);

    // Calculate the notification date: one day before the next visit at 9:00 AM
    final visitDateOnly = DateTime(nextVisit.year, nextVisit.month, nextVisit.day);
    final notificationDate = visitDateOnly.subtract(const Duration(days: 1));
    
    final tzNotificationDate = tz.TZDateTime(
      tz.local,
      notificationDate.year,
      notificationDate.month,
      notificationDate.day,
      9, // Hour
      0, // Minute
    );

    // If the notification date is in the past, don't schedule
    final now = tz.TZDateTime.now(tz.local);
    if (tzNotificationDate.isBefore(now)) {
      return;
    }

    final androidDetails = const AndroidNotificationDetails(
      'visit_reminders',
      'Doctor Visit Reminders',
      channelDescription: 'Channel for scheduled doctor visit reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    // Generate unique notification ID
    final notificationId = (prescription.id.hashCode).abs() % 100000 + 200000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Upcoming Appointment: ${prescription.doctorName}',
      body: 'You have a visit scheduled tomorrow for "${prescription.title}".',
      scheduledDate: tzNotificationDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'visit|${prescription.id}',
    );
  }

  /// Cancels scheduled doctor visit reminder for a prescription.
  Future<void> cancelPrescriptionVisitReminder(DoctorPrescription prescription) async {
    final notificationId = (prescription.id.hashCode).abs() % 100000 + 200000;
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
  }
}
