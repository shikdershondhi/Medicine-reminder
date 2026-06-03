import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/database_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shared/app_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportBackupToFile(BuildContext context, DatabaseService db) async {
    final backupData = db.exportBackupData();
    final jsonString = jsonEncode(backupData);
    String? savedPath;

    try {
      if (Platform.isAndroid) {
        try {
          const channel = MethodChannel('com.example.medicine_reminder/backup');
          savedPath = await channel.invokeMethod<String>('saveToDownloads', {
            'fileName': 'medicine_reminder_backup.json',
            'content': jsonString,
          });
        } catch (methodChannelError) {
          print("MethodChannel failed, running fallback: $methodChannelError");
          // Fallback logic if MethodChannel fails
          final status = await Permission.storage.request();
          if (status.isGranted) {
            final downloadDir = Directory('/storage/emulated/0/Download');
            if (await downloadDir.exists()) {
              final file = File('${downloadDir.path}/medicine_reminder_backup.json');
              await file.writeAsString(jsonString);
              savedPath = file.path;
            }
          }
          
          if (savedPath == null) {
            final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
            if (extDirs != null && extDirs.isNotEmpty) {
              final file = File('${extDirs.first.path}/medicine_reminder_backup.json');
              await file.writeAsString(jsonString);
              savedPath = file.path;
            }
          }
        }
      } else if (Platform.isIOS) {
        // Write to Application Documents Directory (shows up in Files app due to plist keys)
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/medicine_reminder_backup.json');
        await file.writeAsString(jsonString);
        savedPath = file.path;
      }
    } catch (e) {
      print("Error saving backup file: $e");
    }

    // Fallback: copy to clipboard if saving to files failed
    if (savedPath == null) {
      await Clipboard.setData(ClipboardData(text: jsonString));
    }
    
    await db.setLastSync(DateTime.now());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath != null
                ? 'Backup file downloaded successfully to: $savedPath'
                : 'Could not write file. Backup copied to clipboard instead!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _importBackupFromFile(BuildContext context, WidgetRef ref) async {
    String? jsonContent;

    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.example.medicine_reminder/backup');
        jsonContent = await channel.invokeMethod<String>('selectBackupFile');
        if (jsonContent == null) {
          // User cancelled selection
          return;
        }
      } catch (e) {
        print("Error reading file via MethodChannel: $e");
        if (context.mounted) {
          _showImportDialog(context, ref);
        }
        return;
      }
    } else {
      _showImportDialog(context, ref);
      return;
    }

    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonContent);
      final db = ref.read(dbServiceProvider);
      await db.importBackupData(backupData);
      await db.setLastSync(DateTime.now());

      // Reload all provider states
      ref.read(profileProvider.notifier).refresh();
      ref.read(prescriptionsProvider.notifier).load();
      ref.read(medicinesProvider.notifier).load();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data imported and restored successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid backup format: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final db = ref.watch(dbServiceProvider);

    final lastSyncDate = db.getLastSync();
    final formattedLastSync = lastSyncDate != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(lastSyncDate)
        : 'Never exported';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // Profile Header Card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isNotEmpty ? profile.name : 'Health User',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${profile.sex} • ${profile.age} Yrs • ${profile.weight} kg',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/profile-edit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Preferences Section
          _buildSectionHeader(context, 'Preferences'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).toggle(),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Optimize screen display for nighttime use'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notification Permissions'),
                  subtitle: const Text('Manage reminder access status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref.read(notificationServiceProvider).requestPermissions(),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.volume_up_outlined),
                  title: Text('Alarm Ringtone'),
                  subtitle: Text('Default: 1-Second Silence (System Default)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Local Backup & Restore Section
          _buildSectionHeader(context, 'Backup & Restore'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Last Export / Backup'),
                    subtitle: Text(formattedLastSync),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.upload_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      'Export Data (Backup)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('Download database backup file'),
                    onTap: () => _exportBackupToFile(context, db),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.download_outlined, color: Theme.of(context).colorScheme.secondary),
                    title: Text(
                      'Import Data (Restore)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      Platform.isAndroid
                          ? 'Select backup JSON file from Downloads/storage'
                          : 'Restore database from pasted backup text',
                    ),
                    onTap: () => Platform.isAndroid
                        ? _importBackupFromFile(context, ref)
                        : _showImportDialog(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Application Details
          _buildSectionHeader(context, 'About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  const AppLogo(size: 40, padding: 12),
                  const SizedBox(height: 8),
                  Text(
                    'MedTrack',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    trailing: Text('1.0 (beta)', style: TextStyle(color: Colors.grey)),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('Build by'),
                    trailing: Text('Shikder shondhi', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Logout Button
          ElevatedButton(
            onPressed: () => _showLogoutConfirmation(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiaryContainer,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 48),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: 4,
          onTap: (index) {
            if (index == 0) {
              context.go('/dashboard');
            } else if (index == 1) {
              context.push('/prescriptions');
            } else if (index == 2) {
              context.push('/analytics');
            } else if (index == 3) {
              context.push('/scan');
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          'Are you sure you want to log out? All your local prescription data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: Text('Log Out', style: TextStyle(color: AppColors.tertiary)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Backup Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste the exported backup text here to restore all your prescriptions, medicines, and logs. This will overwrite current local data.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Paste backup JSON string here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final jsonStr = textController.text.trim();
              if (jsonStr.isEmpty) return;

              try {
                final Map<String, dynamic> backupData = jsonDecode(jsonStr);
                final db = ref.read(dbServiceProvider);
                await db.importBackupData(backupData);
                await db.setLastSync(DateTime.now());

                // Reload all provider states
                ref.read(profileProvider.notifier).refresh();
                ref.read(prescriptionsProvider.notifier).load();
                ref.read(medicinesProvider.notifier).load();

                Navigator.pop(dialogContext);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Data imported and restored successfully!'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid backup format: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: Text(
              'Import',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
