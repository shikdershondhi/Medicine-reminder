import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/providers.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shared/app_logo.dart';

class TodayDose {
  final Medicine medicine;
  final String time;
  final String status; // "taken", "skipped", "pending", "missed"
  final String logId;

  TodayDose({
    required this.medicine,
    required this.time,
    required this.status,
    required this.logId,
  });
}

// Provider to compute today's list of scheduled doses dynamically
final todayDosesProvider = Provider<List<TodayDose>>((ref) {
  final medicines = ref.watch(medicinesProvider);
  final logs = ref.watch(logsProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  
  final now = DateTime.now();
  final todayStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final todayEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
  
  final List<TodayDose> doses = [];
  
  for (final med in medicines) {
    if (med.startDate.isAfter(todayEnd) || med.endDate.isBefore(todayStart)) {
      continue;
    }
    
    for (final time in med.reminderTimes) {
      final dateKey = '${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}';
      final logId = '${med.id}_${dateKey}_$time';
      
      // Find log matching this unique ID
      MedicineLog? log;
      for (final l in logs) {
        if (l.id == logId) {
          log = l;
          break;
        }
      }
      
      String status = 'pending';
      if (log != null) {
        status = log.status;
      } else {
        // Check if the scheduled time has passed
        final parts = time.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          final slotTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour, minute);
          if (slotTime.isBefore(now)) {
            final today = DateTime(now.year, now.month, now.day);
            final checkDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
            if (checkDate.isBefore(today)) {
              status = 'missed';
            } else {
              status = 'skipped';
            }
          }
        }
      }
      
      doses.add(TodayDose(
        medicine: med,
        time: time,
        status: status,
        logId: logId,
      ));
    }
  }
  
  doses.sort((a, b) => a.time.compareTo(b.time));
  return doses;
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh page every minute to update countdowns and status transitions
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
    
    // Check permissions after frame is drawn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermissions();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  TodayDose? _getNextDose(List<TodayDose> doses) {
    final now = DateTime.now();
    for (final dose in doses) {
      if (dose.status == 'pending') {
        final parts = dose.time.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final doseTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (doseTime.isAfter(now)) {
          return dose;
        }
      }
    }
    // Fallback: first pending dose of the day if any
    return doses.where((d) => d.status == 'pending').firstOrNull;
  }

  Color _getAdherenceColor(double ratio) {
    final percentage = (ratio * 100).toInt();
    if (percentage < 33) {
      return Colors.red;
    } else if (percentage < 100) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate.isAtSameMomentAs(today)) {
      return "Today, ${DateFormat('MMM dd').format(date)}";
    } else if (checkDate.isAtSameMomentAs(yesterday)) {
      return "Yesterday, ${DateFormat('MMM dd').format(date)}";
    } else if (checkDate.isAtSameMomentAs(tomorrow)) {
      return "Tomorrow, ${DateFormat('MMM dd').format(date)}";
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final todayDoses = ref.watch(todayDosesProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    
    final takenDoses = todayDoses.where((d) => d.status == 'taken').length;
    final loggedDoses = todayDoses.where((d) => d.status == 'taken' || d.status == 'skipped').length;
    final totalDoses = todayDoses.length;
    final double completionRatio = totalDoses > 0 ? takenDoses / totalDoses : 0.0;
    
    final nextDose = _getNextDose(todayDoses);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 18, padding: 6),
            const SizedBox(width: 8),
            Text(
              'MedTrack',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(prescriptionsProvider.notifier).load();
          ref.read(medicinesProvider.notifier).load();
          ref.read(logsProvider.notifier).load();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting Section
              Text(
                'Hello, ${profile.name.isNotEmpty ? profile.name.split(' ').first : 'there'}.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              // Date Selection Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatSelectedDate(selectedDate),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalDoses == 0
                              ? 'No medications scheduled.'
                              : '${totalDoses - loggedDoses} doses remaining.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        ref.read(selectedDateProvider.notifier).state = picked;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Horizontal Calendar Row
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final day = selectedDate.add(Duration(days: index - 3));
                    final isSelected = DateUtils.isSameDay(day, selectedDate);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());
                    
                    return GestureDetector(
                      onTap: () => ref.read(selectedDateProvider.notifier).state = day,
                      child: Container(
                        width: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isToday
                                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.surfaceContainerLow),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (isToday
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                    : Theme.of(context).colorScheme.outlineVariant),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(day).substring(0, 3),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('d').format(day),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Progress Overview (Bento Grid)
              Row(
                children: [
                  // Circular Progress Indicator Card
                  Expanded(
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showAdherenceDetailsSheet(todayDoses),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Adherence',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      height: 80,
                                      width: 80,
                                      child: CircularProgressIndicator(
                                        value: completionRatio,
                                        strokeWidth: 10,
                                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                        valueColor: AlwaysStoppedAnimation<Color>(_getAdherenceColor(completionRatio)),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Text(
                                      '${(completionRatio * 100).toInt()}%',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _getAdherenceColor(completionRatio),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Next Dose Card in Amethyst
                  Expanded(
                    child: Card(
                      color: AppColors.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEXT DOSE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.onSecondaryContainer.withOpacity(0.8),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            if (nextDose != null) ...[
                              Text(
                                nextDose.medicine.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${nextDose.medicine.strength} at ${nextDose.time}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                    ),
                              ),
                            ] else ...[
                              Text(
                                'All clear!',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No upcoming doses.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                    ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Today's Schedule Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Schedule",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/prescriptions'),
                    child: const Text('Prescriptions'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Timetable Doses List
              if (todayDoses.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        Icon(Icons.done_all, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        const Text(
                          'No medicines scheduled for today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add a doctor prescription to schedule reminders.',
                          textAlign: TextAlign.center,
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
                  itemCount: todayDoses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final dose = todayDoses[index];
                    return _buildDoseCard(context, dose);
                  },
                ),
              const SizedBox(height: 80), // spacer for bottom nav or FAB
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            if (index == 1) {
              context.push('/prescriptions');
            } else if (index == 2) {
              context.push('/analytics');
            } else if (index == 3) {
              context.push('/scan');
            } else if (index == 4) {
              context.push('/settings');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Prescriptions'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDoseCard(BuildContext context, TodayDose dose) {
    bool isTaken = dose.status == 'taken';
    bool isSkipped = dose.status == 'skipped';
    bool isMissed = dose.status == 'missed';

    Color cardBorderColor = Theme.of(context).colorScheme.outlineVariant;
    Color indicatorColor = Colors.transparent;
    Widget actionWidget = const SizedBox.shrink();

    if (isTaken) {
      cardBorderColor = AppColors.primary.withOpacity(0.3);
      indicatorColor = AppColors.primary;
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text('Taken', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      );
    } else if (isSkipped) {
      cardBorderColor = Colors.grey.withOpacity(0.3);
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Skipped', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    } else if (isMissed) {
      cardBorderColor = AppColors.tertiary.withOpacity(0.3);
      indicatorColor = AppColors.tertiary;
      actionWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _updateDoseStatus(dose, 'taken'),
            child: Text('Take', style: TextStyle(color: AppColors.secondaryContainer, fontWeight: FontWeight.bold)),
          ),
          Text('Missed', style: TextStyle(fontSize: 12, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
        ],
      );
    } else {
      // Pending / Upcoming
      actionWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _updateDoseStatus(dose, 'skipped'),
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _updateDoseStatus(dose, 'taken'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Take'),
          ),
        ],
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: cardBorderColor, width: isTaken ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showChangeStatusSheet(dose),
        child: Stack(
          children: [
            if (indicatorColor != Colors.transparent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isTaken
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
                          : Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      dose.medicine.foodRelation.contains('Before') ? Icons.backpack_outlined : Icons.medication,
                      color: isTaken ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dose.medicine.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: (isTaken || isSkipped) ? TextDecoration.lineThrough : null,
                                color: (isTaken || isSkipped) ? Colors.grey : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dose.time} • ${dose.medicine.strength} • ${dose.medicine.foodRelation}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action Widgets
                  actionWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeStatusSheet(TodayDose dose) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Change Status: ${dose.medicine.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduled for ${dose.time}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.check_circle, color: AppColors.primary),
                  title: const Text('Mark as Taken'),
                  trailing: dose.status == 'taken' ? Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    _updateDoseStatus(dose, 'taken');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                  title: const Text('Mark as Skipped'),
                  trailing: dose.status == 'skipped' ? const Icon(Icons.check, color: Colors.grey) : null,
                  onTap: () {
                    _updateDoseStatus(dose, 'skipped');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Reset to Pending / Untaken'),
                  trailing: (dose.status != 'taken' && dose.status != 'skipped') ? const Icon(Icons.check, color: Colors.orange) : null,
                  onTap: () async {
                    await ref.read(logsProvider.notifier).deleteLog(dose.logId);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdherenceDetailsSheet(List<TodayDose> doses) {
    final total = doses.length;
    final taken = doses.where((d) => d.status == 'taken').length;
    final skipped = doses.where((d) => d.status == 'skipped').length;
    final pending = doses.where((d) => d.status == 'pending').length;
    final missed = doses.where((d) => d.status == 'missed').length;
    final adherencePercent = total > 0 ? (taken / total * 100).toInt() : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Daily Adherence Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Adherence Rate:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$adherencePercent%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _getAdherenceColor(total > 0 ? taken / total : 0.0))),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Taken', taken, AppColors.primary),
                    _buildStatItem('Skipped', skipped, Colors.grey),
                    _buildStatItem('Pending', pending, Colors.blue),
                    _buildStatItem('Missed', missed, AppColors.tertiary),
                  ],
                ),
                const Divider(height: 24),
                const Text('Today\'s Schedule Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                if (doses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No doses scheduled for today.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: doses.length,
                      itemBuilder: (context, index) {
                        final dose = doses[index];
                        IconData icon;
                        Color color;
                        if (dose.status == 'taken') {
                          icon = Icons.check_circle;
                          color = AppColors.primary;
                        } else if (dose.status == 'skipped') {
                          icon = Icons.remove_circle_outline;
                          color = Colors.grey;
                        } else if (dose.status == 'missed') {
                          icon = Icons.error_outline;
                          color = AppColors.tertiary;
                        } else {
                          icon = Icons.schedule;
                          color = Colors.blue;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(icon, color: color, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${dose.medicine.name} (${dose.medicine.strength})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${dose.time} • ${dose.status.toUpperCase()}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _updateDoseStatus(TodayDose dose, String status) async {
    final selectedDate = ref.read(selectedDateProvider);
    final now = DateTime.now();
    final logDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );
    await ref.read(logsProvider.notifier).markDose(
          medicineId: dose.medicine.id,
          scheduledTime: dose.time,
          status: status,
          date: logDateTime,
        );
    
    // Automatically trigger Drive upload in background
    ref.read(driveServiceProvider).uploadBackup();
  }

  void _showConflictResolutionSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.tertiary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Sync Conflict Detected',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.tertiary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'A newer backup file exists on Google Drive. Which version of your data do you want to keep?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(syncProvider.notifier).resolveConflictKeepRemote();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Keep Remote Backup (Recommended)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    ref.read(syncProvider.notifier).resolveConflictKeepLocal();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary),
                  ),
                  child: Text('Overwrite Remote with Local Data', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
