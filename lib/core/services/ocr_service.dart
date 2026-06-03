import 'dart:io';

abstract class OcrService {
  /// Processes the image file and returns recognized text block
  Future<String> recognizeText(File imageFile);

  /// Parsers the recognized text block to find potential medicine matches
  Future<List<Map<String, dynamic>>> extractMedicines(String text);
}

class MockOcrService implements OcrService {
  @override
  Future<String> recognizeText(File imageFile) async {
    // Simulate OCR background thread delay
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
    // Simulation parser returning structured fields matching database format
    return [
      {
        'name': 'Napa',
        'strength': '500 mg',
        'intakePerDay': 2,
        'foodRelation': 'After Meal',
        'durationDays': 7,
        'reminderTimes': ['08:00', '20:00'],
      },
      {
        'name': 'Amoxicillin',
        'strength': '500 mg',
        'intakePerDay': 3,
        'foodRelation': 'Before Meal',
        'durationDays': 5,
        'reminderTimes': ['08:00', '14:00', '20:00'],
      }
    ];
  }
}
