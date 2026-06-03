import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/providers.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_screen.dart';

class DailyStats {
  final DateTime date;
  final int total;
  final int taken;
  final int skipped;
  final int missed;
  final int pending;
  final List<TodayDose> doses;

  DailyStats({
    required this.date,
    required this.total,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.doses,
  });

  int get adherencePercent => total > 0 ? (taken / total * 100).toInt() : 0;
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _historyDays = 30; // Track stats for last 30 days

  List<DailyStats> _calculateHistory(List<Medicine> medicines, List<MedicineLog> logs, int daysCount) {
    final List<DailyStats> history = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < daysCount; i++) {
      final targetDate = today.subtract(Duration(days: i));
      final todayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final todayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final List<TodayDose> dayDoses = [];

      for (final med in medicines) {
        if (med.startDate.isAfter(todayEnd) || med.endDate.isBefore(todayStart)) {
          continue;
        }

        for (final time in med.reminderTimes) {
          final dateKey = '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';
          final logId = '${med.id}_${dateKey}_$time';

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
            // Check if it's in the past relative to now
            final parts = time.split(':');
            if (parts.length >= 2) {
              final hour = int.tryParse(parts[0]) ?? 0;
              final minute = int.tryParse(parts[1]) ?? 0;
              final slotTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
              if (slotTime.isBefore(now)) {
                if (targetDate.isBefore(today)) {
                  status = 'missed';
                } else {
                  status = 'skipped';
                }
              }
            }
          }

          dayDoses.add(TodayDose(
            medicine: med,
            time: time,
            status: status,
            logId: logId,
          ));
        }
      }

      dayDoses.sort((a, b) => a.time.compareTo(b.time));

      final total = dayDoses.length;
      final taken = dayDoses.where((d) => d.status == 'taken').length;
      final skipped = dayDoses.where((d) => d.status == 'skipped').length;
      final missed = dayDoses.where((d) => d.status == 'missed').length;
      final pending = dayDoses.where((d) => d.status == 'pending').length;

      history.add(DailyStats(
        date: targetDate,
        total: total,
        taken: taken,
        skipped: skipped,
        missed: missed,
        pending: pending,
        doses: dayDoses,
      ));
    }

    return history;
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

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(logsProvider);

    final historyList = _calculateHistory(medicines, logs, _historyDays);

    // Calculate aggregated metrics
    int totalExpected = 0;
    int totalTaken = 0;
    int totalSkipped = 0;
    int totalMissed = 0;

    for (final dayStats in historyList) {
      totalExpected += dayStats.total;
      totalTaken += dayStats.taken;
      totalSkipped += dayStats.skipped;
      totalMissed += dayStats.missed;
    }

    final double overallAdherence = totalExpected > 0 ? totalTaken / totalExpected : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period Selector Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overview History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: _historyDays,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                    DropdownMenuItem(value: 14, child: Text('Last 14 Days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _historyDays = val;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Adherence Overall Card
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 90,
                          width: 90,
                          child: CircularProgressIndicator(
                            value: overallAdherence,
                            strokeWidth: 10,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(_getAdherenceColor(overallAdherence)),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(overallAdherence * 100).toInt()}%',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getAdherenceColor(overallAdherence),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Adherence',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Calculated over the last $_historyDays days of active prescriptions.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stat Block Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.green, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(height: 8),
                          Text('$totalTaken', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                          const Text('Taken', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.amber.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.amber, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Icon(Icons.remove_circle, color: Colors.amber, size: 24),
                          const SizedBox(height: 8),
                          Text('$totalSkipped', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                          const Text('Skipped', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.red.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.red, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 24),
                          const SizedBox(height: 8),
                          Text('$totalMissed', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                          const Text('Missed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bar Chart visual representing last 7 days
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last 7 Days Trend',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final idx = 6 - index; // Show from left to right chronologically
                        if (idx >= historyList.length) {
                          return const SizedBox.shrink();
                        }
                        final dayStats = historyList[idx];
                        final pct = dayStats.adherencePercent;
                        final dayLabel = DateFormat('E').format(dayStats.date).substring(0, 1);

                        return Column(
                          children: [
                            Text(
                              '$pct%',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 80 * (pct / 100.0),
                              width: 16,
                              decoration: BoxDecoration(
                                color: _getAdherenceColor(pct / 100.0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dayLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Expandable day lists
            Text(
              'Detailed Log History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final dayStats = historyList[index];
                final formattedDay = DateFormat('EEEE, MMM d, yyyy').format(dayStats.date);
                final adherence = dayStats.adherencePercent;

                return ExpansionTile(
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  title: Text(
                    formattedDay,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getAdherenceColor(adherence / 100.0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$adherence% Adherence',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getAdherenceColor(adherence / 100.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${dayStats.total} doses',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (dayStats.doses.isEmpty)
                            const Text('No medicines scheduled on this day.', style: TextStyle(color: Colors.grey))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dayStats.doses.length,
                              separatorBuilder: (context, index) => const Divider(height: 12),
                              itemBuilder: (context, idx) {
                                final dose = dayStats.doses[idx];
                                IconData icon;
                                Color color;
                                if (dose.status == 'taken') {
                                  icon = Icons.check_circle;
                                  color = Colors.green;
                                } else if (dose.status == 'skipped') {
                                  icon = Icons.remove_circle;
                                  color = Colors.amber;
                                } else if (dose.status == 'missed') {
                                  icon = Icons.error;
                                  color = Colors.red;
                                } else {
                                  icon = Icons.schedule;
                                  color = Colors.blue;
                                }

                                return Row(
                                  children: [
                                    Icon(icon, color: color, size: 18),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dose.medicine.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '${dose.time} • ${dose.medicine.strength}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      dose.status.toUpperCase(),
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Set selectedDateProvider to this date
                              ref.read(selectedDateProvider.notifier).state = dayStats.date;
                              // Navigate back to Dashboard
                              context.go('/dashboard');
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Log / Edit Doses on Dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: 2,
          onTap: (index) {
            if (index == 0) {
              context.go('/dashboard');
            } else if (index == 1) {
              context.push('/prescriptions');
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
}
