import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../core/enums/audio_format.dart';
import '../../core/utils/app_file_utils.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_recording_repository.dart';
import 'file_manager_service.dart';

class VoiceMemoImportSummary {
  final int imported;
  final List<String> failures;
  const VoiceMemoImportSummary(this.imported, this.failures);
}

/// Imports private copies supplied by the native document picker. Originals
/// remain in Files/Voice Memos; temporary copies are removed after each attempt.
class VoiceMemoImportService {
  static const channel = MethodChannel('wavnote/file_actions');
  final IRecordingRepository repository;
  final FileManagerService fileManager;

  VoiceMemoImportService(this.repository, {FileManagerService? fileManager})
    : fileManager = fileManager ?? FileManagerService();

  Future<VoiceMemoImportSummary> import({
    required FolderEntity folder,
    bool selectFolder = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    final entries = await channel.invokeListMethod<dynamic>('pickVoiceMemos', {
      'folder': selectFolder,
    });
    return _importEntries(
      entries ?? [],
      folder: folder,
      onProgress: onProgress,
    );
  }

  Future<VoiceMemoImportSummary> importPendingSharedAudio({
    required FolderEntity folder,
    void Function(int completed, int total)? onProgress,
  }) async {
    final entries = await channel.invokeListMethod<dynamic>(
      'pendingSharedAudio',
    );
    final acknowledged = <String>[];
    final summary = await _importEntries(
      entries ?? [],
      folder: folder,
      onProgress: onProgress,
      onSaved: (entryId) => acknowledged.add(entryId),
    );
    if (acknowledged.isNotEmpty) {
      try {
        await channel.invokeMethod<void>('acknowledgeSharedAudio', {
          'ids': acknowledged,
        });
      } on PlatformException {
        // SQLite already contains these recordings. Stable IDs let the next
        // inbox check retry cleanup without reimporting or hiding this result.
      }
    }
    return summary;
  }

  Future<VoiceMemoImportSummary> _importEntries(
    List<dynamic> items, {
    required FolderEntity folder,
    void Function(int completed, int total)? onProgress,
    void Function(String entryId)? onSaved,
  }) async {
    var imported = 0;
    final failures = <String>[];
    onProgress?.call(0, items.length);
    for (var index = 0; index < items.length; index++) {
      final entry = Map<String, dynamic>.from(items[index] as Map);
      final sourcePath = entry['path'] as String?;
      final entryId = entry['entryId'] as String?;
      final id = entryId == null
          ? '${DateTime.now().microsecondsSinceEpoch}_$index'
          : 'shared_$entryId';
      File? destination;
      var saved = false;
      try {
        // A crash after SQLite commits but before native acknowledgement must
        // not create another recording when the durable inbox is retried.
        if (entryId != null && await repository.getRecordingById(id) != null) {
          onSaved?.call(entryId);
          continue;
        }
        if (entry['error'] != null) throw Exception(entry['error']);
        if (sourcePath == null) {
          throw const FormatException('File non disponibile');
        }
        final source = File(sourcePath);
        if (!await fileManager.validateAudioFile(source)) {
          throw const FormatException(
            'Formato non supportato o file non valido',
          );
        }
        final format = AudioFormat.values.firstWhere(
          (format) =>
              format.fileExtension == path.extension(sourcePath).toLowerCase(),
        );
        final folderId = folder.id == 'favourites'
            ? 'all_recordings'
            : folder.id;
        final directory = await fileManager.createFolderDirectory(folderId);
        destination = File(
          path.join(directory.path, 'voice_memo_$id${format.fileExtension}'),
        );
        await fileManager.copyFile(
          sourceFile: source,
          destinationPath: destination.path,
        );
        if (await source.length() != await destination.length()) {
          throw const FormatException('Copia incompleta');
        }
        await repository.createRecording(
          RecordingEntity(
            id: id,
            name: entry['name'] as String,
            filePath: await AppFileUtils.toRelative(destination.path),
            duration: Duration(milliseconds: entry['durationMs'] as int),
            sampleRate: entry['sampleRate'] as int,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              entry['createdAtMs'] as int,
            ),
            folderId: folderId,
            isFavorite: folder.id == 'favourites',
            fileSize: await destination.length(),
            format: format,
          ),
        );
        saved = true;
        imported++;
        if (entryId != null) onSaved?.call(entryId);
      } catch (error) {
        failures.add('${entry['name']}: $error');
      } finally {
        if (!saved && destination != null && await destination.exists()) {
          try {
            await destination.delete();
          } catch (_) {
            /* best effort */
          }
        }
        // Only remove staging directories created by the native picker.
        if (sourcePath != null) {
          final staging = File(sourcePath).parent;
          if (path.basename(staging.path).startsWith('wavnote-import-')) {
            try {
              await staging.delete(recursive: true);
            } catch (_) {
              /* best effort */
            }
          }
        }
        onProgress?.call(index + 1, items.length);
      }
    }
    return VoiceMemoImportSummary(imported, failures);
  }
}
