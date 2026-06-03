import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/providers.dart';
import '../../core/services/medex_service.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';

class MedicineFormScreen extends ConsumerStatefulWidget {
  final String prescriptionId;
  final String? medicineId;
  const MedicineFormScreen({
    super.key,
    required this.prescriptionId,
    this.medicineId,
  });

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _strengthController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;

  int _frequencyPerDay = 1;
  String _foodRelation = 'Unspecified';
  late DateTime _startDate;
  late DateTime _endDate;
  bool _alarmEnabled = false;
  
  List<String> _reminderTimes = ['08:00'];

  // MedEx Autocomplete states
  List<MedExSearchResult> _autocompleteSuggestions = [];
  bool _isSearchingMedex = false;
  Timer? _debounceTimer;
  final FocusNode _nameFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 6)); // default 7 days duration

    Medicine? medicine;
    if (widget.medicineId != null) {
      final list = ref.read(medicinesProvider);
      medicine = list.firstWhere((m) => m.id == widget.medicineId);
    }

    _nameController = TextEditingController(text: medicine?.name ?? '');
    _strengthController = TextEditingController(text: medicine?.strength ?? '');
    _durationController = TextEditingController(text: medicine?.durationDays.toString() ?? '7');
    _notesController = TextEditingController(text: medicine?.notes ?? '');

    if (medicine != null) {
      _frequencyPerDay = medicine.intakePerDay;
      _foodRelation = medicine.foodRelation;
      _startDate = medicine.startDate;
      _endDate = medicine.endDate;
      _alarmEnabled = medicine.alarmEnabled;
      _reminderTimes = List<String>.from(medicine.reminderTimes);
    } else {
      _updateReminderTimesCount(_frequencyPerDay);
    }

    _nameFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _nameFocusNode.hasFocus && _autocompleteSuggestions.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _debounceTimer?.cancel();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // Auto-generate default spacing for times based on daily frequency
  void _updateReminderTimesCount(int frequency) {
    setState(() {
      _frequencyPerDay = frequency;
      
      final currentLength = _reminderTimes.length;
      if (frequency > currentLength) {
        // Add more default slots (evenly spaced)
        final defaults = ['08:00', '20:00', '14:00', '12:00', '18:00', '22:00'];
        for (int i = currentLength; i < frequency; i++) {
          if (i < defaults.length) {
            _reminderTimes.add(defaults[i]);
          } else {
            _reminderTimes.add('08:00');
          }
        }
      } else if (frequency < currentLength) {
        // Truncate
        _reminderTimes = _reminderTimes.sublist(0, frequency);
      }
      
      // Sort times chronologically
      _reminderTimes.sort();
    });
  }

  void _onNameChanged(String value) {
    _debounceTimer?.cancel();
    if (value.length < 2) {
      setState(() {
        _autocompleteSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearchingMedex = true);
      try {
        final results = await ref.read(medExServiceProvider).search(value);
        setState(() {
          _autocompleteSuggestions = results;
          _showSuggestions = _nameFocusNode.hasFocus && results.isNotEmpty;
        });
      } catch (e) {
        // Fail silently
      } finally {
        setState(() => _isSearchingMedex = false);
      }
    });
  }

  void _selectSuggestion(MedExSearchResult result) {
    setState(() {
      _nameController.text = result.name;
      _strengthController.text = result.strength;
      _showSuggestions = false;
      _autocompleteSuggestions = [];
      
      // Auto pre-populate default notes with generic/manufacturer info
      _notesController.text = 'Generic: ${result.generic}\nMfg: ${result.manufacturer}';
    });
    _nameFocusNode.unfocus();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _recalculateEndDate();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _recalculateDuration();
      });
    }
  }

  void _recalculateEndDate() {
    final days = int.tryParse(_durationController.text) ?? 1;
    setState(() {
      _endDate = _startDate.add(Duration(days: days - 1));
    });
  }

  void _recalculateDuration() {
    setState(() {
      final diff = _endDate.difference(_startDate).inDays + 1;
      _durationController.text = diff > 0 ? diff.toString() : '1';
    });
  }

  Future<void> _selectTimeSlot(BuildContext context, int index) async {
    final timeStr = _reminderTimes[index];
    final parts = timeStr.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 8;
    final initialMinute = int.tryParse(parts[1]) ?? 0;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      setState(() {
        final newHour = picked.hour.toString().padLeft(2, '0');
        final newMinute = picked.minute.toString().padLeft(2, '0');
        _reminderTimes[index] = '$newHour:$newMinute';
        _reminderTimes.sort(); // Keep sorted chronologically
      });
    }
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.medicineId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final duration = int.tryParse(_durationController.text) ?? 1;

    final medicine = Medicine(
      id: id,
      prescriptionId: widget.prescriptionId,
      medicineNumber: widget.medicineId != null ? id : 'MED-$id',
      name: _nameController.text.trim(),
      strength: _strengthController.text.trim(),
      intakePerDay: _frequencyPerDay,
      foodRelation: _foodRelation,
      startDate: _startDate,
      endDate: _endDate,
      durationDays: duration,
      notes: _notesController.text.trim(),
      reminderTimes: _reminderTimes,
      alarmEnabled: _alarmEnabled,
    );

    await ref.read(medicinesProvider.notifier).saveMedicine(medicine);
    
    // Upload local database changes backup to Drive
    ref.read(driveServiceProvider).uploadBackup();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.medicineId != null ? 'Medicine updated!' : 'Medicine added to prescription!'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicineId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Autocomplete Medicine Input Container
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Medicine Name',
                          prefixIcon: const Icon(Icons.medication),
                          suffixIcon: _isSearchingMedex
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter medicine name' : null,
                        onChanged: _onNameChanged,
                      ),
                    ],
                  ),
                ],
              ),
              
              // Autocomplete List Overlay Panel (Renders directly below name input)
              if (_showSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _autocompleteSuggestions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _autocompleteSuggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.strength} • Generic: ${item.generic} • ${item.manufacturer}'),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
                
              const SizedBox(height: 20),
              
              // Strength Input
              TextFormField(
                controller: _strengthController,
                decoration: const InputDecoration(
                  labelText: 'Strength (e.g. 500 mg, 10 ml)',
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter strength' : null,
              ),
              const SizedBox(height: 20),

              // Frequency Dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _frequencyPerDay,
                      decoration: const InputDecoration(
                        labelText: 'Intake Per Day',
                        prefixIcon: Icon(Icons.loop),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 time')),
                        DropdownMenuItem(value: 2, child: Text('2 times')),
                        DropdownMenuItem(value: 3, child: Text('3 times')),
                        DropdownMenuItem(value: 4, child: Text('4 times')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateReminderTimesCount(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Meal relation
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _foodRelation,
                      decoration: const InputDecoration(
                        labelText: 'Meal Relation',
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Before Meal', child: Text('Before Meal')),
                        DropdownMenuItem(value: 'After Meal', child: Text('After Meal')),
                        DropdownMenuItem(value: 'Unspecified', child: Text('Unspecified')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _foodRelation = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Date pickers Bento Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM dd, yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM dd, yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Total Days Input
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Course Duration (Days)',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (val) => val == null || int.tryParse(val) == null ? 'Please enter duration in days' : null,
                onChanged: (val) {
                  if (int.tryParse(val) != null) {
                    _recalculateEndDate();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Reminder Times List Header
              Text(
                'Intake Notification Schedule',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reminderTimes.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.access_time),
                        title: Text('Dose #${index + 1} Notification Time'),
                        trailing: Text(
                          _reminderTimes[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () => _selectTimeSlot(context, index),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Alarm Enabled Card
              Card(
                color: _alarmEnabled ? AppColors.secondaryContainer.withOpacity(0.05) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _alarmEnabled ? AppColors.secondaryContainer : Theme.of(context).colorScheme.outlineVariant),
                ),
                child: SwitchListTile(
                  value: _alarmEnabled,
                  title: const Text('Enable Ringing Alarm', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Play custom ringing alarm and vibrate full-screen when dose is scheduled.'),
                  activeColor: AppColors.secondaryContainer,
                  onChanged: (val) {
                    setState(() => _alarmEnabled = val);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Notes Input
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (e.g. Swallow with warm water)',
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Schedule Medication',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
