import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'auth_service.dart';
import 'database_service.dart';

class DriveService {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  static const String _backupFileName = 'medicine_reminder_backup.json';

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  /// Searches for the backup file in the user's Drive.
  /// Returns the file ID if found, otherwise null.
  Future<String?> findBackupFile(drive.DriveApi driveApi) async {
    try {
      final query = "name = '$_backupFileName' and trashed = false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime)',
      );
      
      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }
      return null;
    } catch (e) {
      print("Error finding backup file: $e");
      return null;
    }
  }

  /// Retrieves the remote file metadata (specifically modifiedTime) to check for conflicts.
  Future<DateTime?> getRemoteBackupTimestamp() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    final fileId = await findBackupFile(driveApi);
    if (fileId == null) return null;

    try {
      final file = await driveApi.files.get(fileId, $fields: 'modifiedTime') as drive.File;
      return file.modifiedTime;
    } catch (e) {
      print("Error getting remote timestamp: $e");
      return null;
    }
  }

  /// Downloads the backup JSON and returns the parsed map.
  Future<Map<String, dynamic>?> downloadBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    final fileId = await findBackupFile(driveApi);
    if (fileId == null) return null;

    try {
      final drive.Media mediaResponse = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> bytes = [];
      await for (final chunk in mediaResponse.stream) {
        bytes.addAll(chunk);
      }

      final jsonStr = utf8.decode(bytes);
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print("Error downloading backup: $e");
      return null;
    }
  }

  /// Uploads the current local database state to Google Drive.
  /// If the backup file already exists, it is overwritten. Otherwise, a new one is created.
  Future<bool> uploadBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    try {
      final localData = _dbService.exportBackupData();
      final jsonBytes = utf8.encode(json.encode(localData));
      
      final media = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
      );

      final fileId = await findBackupFile(driveApi);
      if (fileId != null) {
        // Update existing file
        final driveFile = drive.File();
        await driveApi.files.update(driveFile, fileId, uploadMedia: media);
      } else {
        // Create new file
        final driveFile = drive.File()
          ..name = _backupFileName
          ..mimeType = 'application/json';
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      
      await _dbService.setLastSync(DateTime.now());
      return true;
    } catch (e) {
      print("Error uploading backup: $e");
      return false;
    }
  }

  /// Performs conflict resolution and synchronization.
  /// Returns one of:
  /// - 'success': Sync completed successfully without issues.
  /// - 'no_backup': No backup found on Google Drive, created a new one.
  /// - 'conflict': Remote backup is newer than local data; user intervention needed.
  /// - 'error': General network or permission failure.
  Future<String> sync() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return 'error';

    final hasPermission = await _authService.hasDrivePermission();
    if (!hasPermission) {
      final granted = await _authService.requestDrivePermission();
      if (!granted) return 'error';
    }

    try {
      final fileId = await findBackupFile(driveApi);
      if (fileId == null) {
        // First sync, upload local data to create the remote backup file
        final uploaded = await uploadBackup();
        return uploaded ? 'no_backup' : 'error';
      }

      // Check remote file metadata
      final file = await driveApi.files.get(fileId, $fields: 'modifiedTime') as drive.File;
      final remoteTime = file.modifiedTime;
      final localLastSync = _dbService.getLastSync();

      if (remoteTime != null && localLastSync != null) {
        // If remote file is modified after our last sync timestamp, we have a potential conflict
        // (i.e. another device uploaded changes)
        // Allow a small safety margin of 2 seconds for clock skew
        if (remoteTime.isAfter(localLastSync.add(const Duration(seconds: 2)))) {
          return 'conflict';
        }
      }

      // No conflict, download any remote data and merge, then upload consolidated changes
      final remoteData = await downloadBackup();
      if (remoteData != null) {
        // Sync merge logic: for simplicity, we overwrite local data if remote is newer, 
        // or we upload if local is newer.
        // In a true production app, we would merge collections by object UUID & timestamp.
        // Since we are using Hive with transaction-like overrides:
        await _dbService.importBackupData(remoteData);
      }

      // Upload local state back to ensure timestamps align
      final uploaded = await uploadBackup();
      return uploaded ? 'success' : 'error';
    } catch (e) {
      print("Sync exception: $e");
      return 'error';
    }
  }

  /// Explicitly forces overwriting local database with remote backup.
  Future<bool> forceRestoreFromRemote() async {
    final remoteData = await downloadBackup();
    if (remoteData != null) {
      await _dbService.importBackupData(remoteData);
      await _dbService.setLastSync(DateTime.now());
      return true;
    }
    return false;
  }
}
