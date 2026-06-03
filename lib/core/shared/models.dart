import 'dart:convert';

class UserProfile {
  final String name;
  final String sex;
  final double weight;
  final int age;

  UserProfile({
    required this.name,
    required this.sex,
    required this.weight,
    required this.age,
  });

  UserProfile copyWith({
    String? name,
    String? sex,
    double? weight,
    int? age,
  }) {
    return UserProfile(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      weight: weight ?? this.weight,
      age: age ?? this.age,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sex': sex,
      'weight': weight,
      'age': age,
    };
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    return UserProfile(
      name: map['name']?.toString() ?? '',
      sex: map['sex']?.toString() ?? 'Male',
      weight: double.tryParse(map['weight']?.toString() ?? '') ?? 0.0,
      age: int.tryParse(map['age']?.toString() ?? '') ?? 0,
    );
  }

  factory UserProfile.empty() {
    return UserProfile(name: '', sex: 'Male', weight: 0.0, age: 0);
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}

class DoctorPrescription {
  final String id;
  final String title;
  final String doctorName;
  final DateTime visitDate;
  final String visitNumber;
  final String notes;
  final String advice;
  final DateTime? nextVisitDate;

  DoctorPrescription({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.visitDate,
    required this.visitNumber,
    required this.notes,
    required this.advice,
    this.nextVisitDate,
  });

  DoctorPrescription copyWith({
    String? id,
    String? title,
    String? doctorName,
    DateTime? visitDate,
    String? visitNumber,
    String? notes,
    String? advice,
    DateTime? nextVisitDate,
  }) {
    return DoctorPrescription(
      id: id ?? this.id,
      title: title ?? this.title,
      doctorName: doctorName ?? this.doctorName,
      visitDate: visitDate ?? this.visitDate,
      visitNumber: visitNumber ?? this.visitNumber,
      notes: notes ?? this.notes,
      advice: advice ?? this.advice,
      nextVisitDate: nextVisitDate ?? this.nextVisitDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'doctorName': doctorName,
      'visitDate': visitDate.toIso8601String(),
      'visitNumber': visitNumber,
      'notes': notes,
      'advice': advice,
      'nextVisitDate': nextVisitDate?.toIso8601String(),
    };
  }

  factory DoctorPrescription.fromMap(Map<dynamic, dynamic> map) {
    return DoctorPrescription(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      doctorName: map['doctorName']?.toString() ?? '',
      visitDate: map['visitDate'] != null ? DateTime.parse(map['visitDate'].toString()) : DateTime.now(),
      visitNumber: map['visitNumber']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      advice: map['advice']?.toString() ?? '',
      nextVisitDate: map['nextVisitDate'] != null ? DateTime.parse(map['nextVisitDate'].toString()) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory DoctorPrescription.fromJson(String source) => DoctorPrescription.fromMap(json.decode(source));
}

class Medicine {
  final String id;
  final String prescriptionId;
  final String medicineNumber;
  final String name;
  final String strength;
  final int intakePerDay;
  final String foodRelation; // "Before Meal", "After Meal", "Unspecified"
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final String notes;
  final List<String> reminderTimes; // list of "HH:mm"
  final bool alarmEnabled;

  Medicine({
    required this.id,
    required this.prescriptionId,
    required this.medicineNumber,
    required this.name,
    required this.strength,
    required this.intakePerDay,
    required this.foodRelation,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.notes,
    required this.reminderTimes,
    required this.alarmEnabled,
  });

  Medicine copyWith({
    String? id,
    String? prescriptionId,
    String? medicineNumber,
    String? name,
    String? strength,
    int? intakePerDay,
    String? foodRelation,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    String? notes,
    List<String>? reminderTimes,
    bool? alarmEnabled,
  }) {
    return Medicine(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      medicineNumber: medicineNumber ?? this.medicineNumber,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      intakePerDay: intakePerDay ?? this.intakePerDay,
      foodRelation: foodRelation ?? this.foodRelation,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      notes: notes ?? this.notes,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prescriptionId': prescriptionId,
      'medicineNumber': medicineNumber,
      'name': name,
      'strength': strength,
      'intakePerDay': intakePerDay,
      'foodRelation': foodRelation,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'durationDays': durationDays,
      'notes': notes,
      'reminderTimes': reminderTimes,
      'alarmEnabled': alarmEnabled,
    };
  }

  factory Medicine.fromMap(Map<dynamic, dynamic> map) {
    return Medicine(
      id: map['id']?.toString() ?? '',
      prescriptionId: map['prescriptionId']?.toString() ?? '',
      medicineNumber: map['medicineNumber']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      strength: map['strength']?.toString() ?? '',
      intakePerDay: int.tryParse(map['intakePerDay']?.toString() ?? '1') ?? 1,
      foodRelation: map['foodRelation']?.toString() ?? 'Unspecified',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate'].toString()) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate'].toString()) : DateTime.now(),
      durationDays: int.tryParse(map['durationDays']?.toString() ?? '1') ?? 1,
      notes: map['notes']?.toString() ?? '',
      reminderTimes: map['reminderTimes'] != null ? List<String>.from(map['reminderTimes']) : [],
      alarmEnabled: map['alarmEnabled'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Medicine.fromJson(String source) => Medicine.fromMap(json.decode(source));
}

class MedicineLog {
  final String id;
  final String medicineId;
  final DateTime takenDateTime;
  final String scheduledTime; // "HH:mm"
  final String status; // "taken", "skipped", "missed"

  MedicineLog({
    required this.id,
    required this.medicineId,
    required this.takenDateTime,
    required this.scheduledTime,
    required this.status,
  });

  MedicineLog copyWith({
    String? id,
    String? medicineId,
    DateTime? takenDateTime,
    String? scheduledTime,
    String? status,
  }) {
    return MedicineLog(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      takenDateTime: takenDateTime ?? this.takenDateTime,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'takenDateTime': takenDateTime.toIso8601String(),
      'scheduledTime': scheduledTime,
      'status': status,
    };
  }

  factory MedicineLog.fromMap(Map<dynamic, dynamic> map) {
    return MedicineLog(
      id: map['id']?.toString() ?? '',
      medicineId: map['medicineId']?.toString() ?? '',
      takenDateTime: map['takenDateTime'] != null ? DateTime.parse(map['takenDateTime'].toString()) : DateTime.now(),
      scheduledTime: map['scheduledTime']?.toString() ?? '',
      status: map['status']?.toString() ?? 'taken',
    );
  }

  String toJson() => json.encode(toMap());

  factory MedicineLog.fromJson(String source) => MedicineLog.fromMap(json.decode(source));
}

class MedicineTracking {
  final String medicineId;
  final int totalDuration;
  final int daysCompleted;
  final int daysRemaining;
  final int totalDosesTaken;
  final int missedDoses;
  final double completionPercentage;

  MedicineTracking({
    required this.medicineId,
    required this.totalDuration,
    required this.daysCompleted,
    required this.daysRemaining,
    required this.totalDosesTaken,
    required this.missedDoses,
    required this.completionPercentage,
  });
}
