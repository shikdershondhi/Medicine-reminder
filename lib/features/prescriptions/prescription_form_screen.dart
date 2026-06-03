import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/providers.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';

class PrescriptionFormScreen extends ConsumerStatefulWidget {
  final String? prescriptionId;
  const PrescriptionFormScreen({super.key, this.prescriptionId});

  @override
  ConsumerState<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends ConsumerState<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _doctorController;
  late TextEditingController _visitNumberController;
  late TextEditingController _notesController;
  late TextEditingController _adviceController;
  late DateTime _visitDate;
  DateTime? _nextVisitDate;

  @override
  void initState() {
    super.initState();
    DoctorPrescription? prescription;
    if (widget.prescriptionId != null) {
      final list = ref.read(prescriptionsProvider);
      prescription = list.firstWhere((p) => p.id == widget.prescriptionId);
    }

    _titleController = TextEditingController(text: prescription?.title ?? '');
    _doctorController = TextEditingController(text: prescription?.doctorName ?? '');
    _visitNumberController = TextEditingController(text: prescription?.visitNumber ?? '1');
    _notesController = TextEditingController(text: prescription?.notes ?? '');
    _adviceController = TextEditingController(text: prescription?.advice ?? '');
    _visitDate = prescription?.visitDate ?? DateTime.now();
    _nextVisitDate = prescription?.nextVisitDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _visitNumberController.dispose();
    _notesController.dispose();
    _adviceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _visitDate) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  Future<void> _selectNextVisitDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextVisitDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _nextVisitDate = picked;
      });
    }
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.prescriptionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final prescription = DoctorPrescription(
      id: id,
      title: _titleController.text.trim(),
      doctorName: _doctorController.text.trim(),
      visitDate: _visitDate,
      visitNumber: _visitNumberController.text.trim(),
      notes: _notesController.text.trim(),
      advice: _adviceController.text.trim(),
      nextVisitDate: _nextVisitDate,
    );

    if (widget.prescriptionId != null) {
      await ref.read(prescriptionsProvider.notifier).updatePrescription(prescription);
    } else {
      await ref.read(prescriptionsProvider.notifier).addPrescription(prescription);
    }

    // Backup to Google Drive in the background
    ref.read(driveServiceProvider).uploadBackup();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.prescriptionId != null ? 'Prescription updated!' : 'Prescription added!'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.prescriptionId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Prescription' : 'New Prescription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Prescription Title (e.g. Chronic Pain Clinic)',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _doctorController,
                decoration: const InputDecoration(
                  labelText: 'Doctor\'s Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter the doctor\'s name' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Visit Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(_visitDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _visitNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Visit Number (e.g. 1, 2)',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter visit number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Next Visit Date Input
              InkWell(
                onTap: () => _selectNextVisitDate(context),
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_repeat, size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Next Visit Date (Optional)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _nextVisitDate == null
                                  ? 'Not Scheduled'
                                  : DateFormat('MMMM dd, yyyy').format(_nextVisitDate!),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _nextVisitDate == null ? Colors.grey : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_nextVisitDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _nextVisitDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Prescription Notes (Symptom info)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _adviceController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Special Advice (Dietary restriction, etc.)',
                  prefixIcon: Icon(Icons.lightbulb_outline),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 40),
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
                  isEditing ? 'Save Changes' : 'Create Prescription',
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
