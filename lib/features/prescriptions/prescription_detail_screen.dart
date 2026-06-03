import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/providers.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';

class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  final String prescriptionId;
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  ConsumerState<PrescriptionDetailScreen> createState() => _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends ConsumerState<PrescriptionDetailScreen> {
  String? _expandedMedicineId;

  MedicineTracking _calculateTracking(Medicine med, List<MedicineLog> logs) {
    final medLogs = logs.where((l) => l.medicineId == med.id).toList();
    final dosesTaken = medLogs.where((l) => l.status == 'taken').length;
    final dosesMissed = medLogs.where((l) => l.status == 'missed').length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);

    int daysCompleted = 0;
    if (today.isAfter(startDay)) {
      daysCompleted = today.difference(startDay).inDays;
      if (daysCompleted > med.durationDays) {
        daysCompleted = med.durationDays;
      }
    } else if (today.isAtSameMomentAs(startDay)) {
      // Check if there are any logs today
      final hasLogsToday = medLogs.any((l) {
        final logDay = DateTime(l.takenDateTime.year, l.takenDateTime.month, l.takenDateTime.day);
        return logDay.isAtSameMomentAs(today);
      });
      daysCompleted = hasLogsToday ? 1 : 0;
    }

    int daysRemaining = med.durationDays - daysCompleted;
    if (daysRemaining < 0) daysRemaining = 0;

    final totalExpectedDoses = med.durationDays * med.intakePerDay;
    final completionPct = totalExpectedDoses > 0 ? (dosesTaken / totalExpectedDoses) * 100 : 0.0;

    return MedicineTracking(
      medicineId: med.id,
      totalDuration: med.durationDays,
      daysCompleted: daysCompleted,
      daysRemaining: daysRemaining,
      totalDosesTaken: dosesTaken,
      missedDoses: dosesMissed,
      completionPercentage: completionPct > 100.0 ? 100.0 : completionPct,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prescriptions = ref.watch(prescriptionsProvider);
    final allMedicines = ref.watch(medicinesProvider);
    final logs = ref.watch(logsProvider);

    // Find the prescription
    final prescription = prescriptions.firstWhere(
      (p) => p.id == widget.prescriptionId,
      orElse: () => DoctorPrescription(
        id: '',
        title: 'Prescription Not Found',
        doctorName: '',
        visitDate: DateTime.now(),
        visitNumber: '1',
        notes: '',
        advice: '',
      ),
    );

    if (prescription.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Prescription not found.')),
      );
    }

    final prescriptionMeds = allMedicines.where((m) => m.prescriptionId == prescription.id).toList();
    final formattedDate = DateFormat('MMMM dd, yyyy').format(prescription.visitDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(prescription.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/prescriptions/edit/${prescription.id}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Doctor & Info Banner Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.medical_services_outlined, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${prescription.doctorName}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Visit Date: $formattedDate • Visit #${prescription.visitNumber}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (prescription.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Symptom Notes', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(prescription.notes, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (prescription.advice.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Doctor Advice & Instructions', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(prescription.advice, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (prescription.nextVisitDate != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.event_repeat,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Next Visit Scheduled:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(prescription.nextVisitDate!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Medicines Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/prescriptions/${prescription.id}/add-medicine'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Medicine', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Medicines List
            if (prescriptionMeds.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      Icon(Icons.medication_liquid, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      const Text(
                        'No medicines added yet.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Add Medicine" to schedule a course.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prescriptionMeds.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final medicine = prescriptionMeds[index];
                  final tracking = _calculateTracking(medicine, logs);
                  final isExpanded = _expandedMedicineId == medicine.id;

                  return _buildMedicineCard(context, medicine, tracking, isExpanded);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine medicine, MedicineTracking tracking, bool isExpanded) {
    return Card(
      child: Column(
        children: [
          // Header Tappable Title
          ListTile(
            onTap: () {
              setState(() {
                _expandedMedicineId = isExpanded ? null : medicine.id;
              });
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              child: Icon(Icons.medication, color: Theme.of(context).colorScheme.secondary),
            ),
            title: Text(
              medicine.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${medicine.strength} • ${medicine.intakePerDay}x daily • ${medicine.foodRelation}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (medicine.alarmEnabled)
                  Icon(Icons.alarm, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),

          // Collapsible Expanded Tracking Stats
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Course Completion Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${tracking.completionPercentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: tracking.completionPercentage / 100,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tracking Bento-Grid Details
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    children: [
                      _buildStatsCell('Taken', '${tracking.totalDosesTaken} doses', Icons.check_circle_outline, AppColors.primary),
                      _buildStatsCell('Missed', '${tracking.missedDoses} doses', Icons.error_outline, AppColors.tertiary),
                      _buildStatsCell('Remaining', '${tracking.daysRemaining} days', Icons.hourglass_empty, Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Meta Information (Duration, Start, End)
                  Text(
                    'Duration: ${medicine.durationDays} Days (${DateFormat('MMM dd').format(medicine.startDate)} - ${DateFormat('MMM dd').format(medicine.endDate)})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  if (medicine.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${medicine.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 16),
                  // Edit / Delete Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showDeleteConfirmation(context, medicine),
                        icon: Icon(Icons.delete_outline, size: 16, color: AppColors.tertiary),
                        label: Text('Delete', style: TextStyle(color: AppColors.tertiary, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => context.push('/prescriptions/${widget.prescriptionId}/edit-medicine/${medicine.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatsCell(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine?'),
        content: Text('Are you sure you want to delete "${medicine.name}"? This course schedule and all active alarms/notifications will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(medicinesProvider.notifier).deleteMedicine(medicine.id);
              ref.read(driveServiceProvider).uploadBackup(); // Back up changes
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.tertiary)),
          ),
        ],
      ),
    );
  }
}
