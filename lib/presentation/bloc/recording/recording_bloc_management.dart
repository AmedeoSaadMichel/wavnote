// File: presentation/bloc/recording/recording_bloc_management.dart
//
// Recording BLoC — Management Handlers
// ======================================
// Part of recording_bloc.dart. Contains event handlers for recording list
// management: load, delete, restore, move, favorites, and debug utilities.
//
// Declared as an extension on RecordingBloc (same library → full access to
// private fields like _recordingRepository, _folderBloc, etc.)

part of 'recording_bloc.dart';

extension _RecordingBlocManagement on RecordingBloc {
  // ==== LOAD ====

  Future<void> _onLoadRecordings(
      LoadRecordings event, Emitter<RecordingState> emit) async {
    try {
      emit(const RecordingLoading());
      final recordings =
          await _recordingRepository.getRecordingsByFolder(event.folderId);
      emit(RecordingLoaded(recordings));
    } catch (e) {
      print('❌ Error loading recordings: $e');
      emit(RecordingError('Failed to load recordings: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== DELETE (SINGLE) ====

  Future<void> _onDeleteRecording(
      DeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      await _recordingRepository.deleteRecording(event.recordingId);
      if (state is RecordingLoaded) {
        final s = state as RecordingLoaded;
        emit(s.copyWith(
          recordings: s.recordings
              .where((r) => r.id != event.recordingId)
              .toList(),
        ));
        _refreshFolderCounts();
      }
    } catch (e) {
      print('❌ Error deleting recording: $e');
      emit(RecordingError('Failed to delete recording: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  Future<void> _onSoftDeleteRecording(
      SoftDeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      final success =
          await _recordingRepository.softDeleteRecording(event.recordingId);
      if (success && state is RecordingLoaded) {
        final s = state as RecordingLoaded;
        emit(s.copyWith(
          recordings: s.recordings
              .where((r) => r.id != event.recordingId)
              .toList(),
        ));
        _refreshFolderCounts();
      } else if (!success) {
        throw Exception('Repository returned false for soft delete');
      }
    } catch (e) {
      print('❌ Error soft deleting recording: $e');
      emit(RecordingError('Failed to delete recording: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  Future<void> _onPermanentDeleteRecording(
      PermanentDeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      final success = await _recordingRepository
          .permanentlyDeleteRecording(event.recordingId);
      if (success && state is RecordingLoaded) {
        final s = state as RecordingLoaded;
        emit(s.copyWith(
          recordings: s.recordings
              .where((r) => r.id != event.recordingId)
              .toList(),
        ));
        _refreshFolderCounts();
      } else if (!success) {
        throw Exception('Repository returned false for permanent delete');
      }
    } catch (e) {
      print('❌ Error permanently deleting recording: $e');
      emit(RecordingError('Failed to permanently delete recording: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== RESTORE ====

  Future<void> _onRestoreRecording(
      RestoreRecording event, Emitter<RecordingState> emit) async {
    try {
      final success =
          await _recordingRepository.restoreRecording(event.recordingId);
      if (success && state is RecordingLoaded) {
        final s = state as RecordingLoaded;
        emit(s.copyWith(
          recordings: s.recordings
              .where((r) => r.id != event.recordingId)
              .toList(),
        ));
        _refreshFolderCounts();
      } else if (!success) {
        throw Exception('Repository returned false for restore');
      }
    } catch (e) {
      print('❌ Error restoring recording: $e');
      emit(RecordingError('Failed to restore recording: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== CLEANUP ====

  Future<void> _onCleanupExpiredRecordings(
      CleanupExpiredRecordings event, Emitter<RecordingState> emit) async {
    try {
      final deleted =
          await _recordingRepository.cleanupExpiredRecordings();
      print('✅ Cleaned up $deleted expired recordings');
    } catch (e) {
      print('❌ Error cleaning up expired recordings: $e');
      emit(RecordingError('Failed to clean up expired recordings: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== BULK DELETE ====

  Future<void> _onDeleteSelectedRecordings(
      DeleteSelectedRecordings event, Emitter<RecordingState> emit) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;
    final selectedIds = s.selectedRecordings;
    if (selectedIds.isEmpty) return;

    try {
      for (final id in selectedIds) {
        if (event.folderId == 'recently_deleted') {
          await _recordingRepository.deleteRecording(id);
        } else {
          await _recordingRepository.softDeleteRecording(id);
        }
      }
      emit(s.copyWith(
        recordings:
            s.recordings.where((r) => !selectedIds.contains(r.id)).toList(),
        selectedRecordings: <String>{},
      ));
      _refreshFolderCounts();
    } catch (e) {
      print('❌ Error deleting selected recordings: $e');
      emit(RecordingError('Failed to delete selected recordings: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== FAVORITE ====

  Future<void> _onToggleFavoriteRecording(
      ToggleFavoriteRecording event, Emitter<RecordingState> emit) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;

    try {
      final target = s.recordings.firstWhere(
        (r) => r.id == event.recordingId,
        orElse: () => throw Exception('Recording not found'),
      );

      final success =
          await _recordingRepository.toggleFavorite(event.recordingId);

      if (success && !isClosed) {
        final updatedRecordings = s.recordings.map((r) {
          return r.id == event.recordingId ? r.toggleFavorite() : r;
        }).toList();

        emit(RecordingLoaded(
          updatedRecordings,
          isEditMode: s.isEditMode,
          selectedRecordings: s.selectedRecordings,
          timestamp: DateTime.now(),
        ));
        _refreshFolderCounts();
      } else {
        throw Exception('Failed to toggle favorite for ${target.name}');
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
      emit(RecordingError('Failed to toggle favorite: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== MOVE ====

  Future<void> _onMoveRecordingToFolder(
      MoveRecordingToFolder event, Emitter<RecordingState> emit) async {
    try {
      await _recordingRepository
          .moveRecordingsToFolder([event.recordingId], event.targetFolderId);

      if (state is RecordingLoaded && !isClosed) {
        final s = state as RecordingLoaded;
        final updated = await _recordingRepository
            .getRecordingsByFolder(event.currentFolderId);
        if (!isClosed) emit(s.copyWith(recordings: updated));
      }
      _refreshFolderCounts();
    } catch (e) {
      print('❌ Error moving recording: $e');
      emit(RecordingError('Failed to move recording: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  Future<void> _onMoveSelectedRecordingsToFolder(
      MoveSelectedRecordingsToFolder event,
      Emitter<RecordingState> emit) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;
    final selectedIds = s.selectedRecordings.toList();
    if (selectedIds.isEmpty) return;

    try {
      await _recordingRepository.moveRecordingsToFolder(
          selectedIds, event.targetFolderId);

      if (!isClosed) {
        final updated = await _recordingRepository
            .getRecordingsByFolder(event.currentFolderId);
        if (!isClosed) {
          emit(s.copyWith(
            recordings: updated,
            selectedRecordings: const {},
            isEditMode: false,
          ));
        }
      }
      _refreshFolderCounts();
    } catch (e) {
      print('❌ Error moving selected recordings: $e');
      emit(RecordingError('Failed to move recordings: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  // ==== DEBUG ====

  Future<void> _onDebugLoadAllRecordings(
      DebugLoadAllRecordings event, Emitter<RecordingState> emit) async {
    try {
      emit(const RecordingLoading());
      final all = await _recordingRepository.getAllRecordings();
      emit(RecordingLoaded(all));
    } catch (e) {
      print('❌ DEBUG: Error loading all recordings: $e');
      emit(RecordingError('Debug error: $e',
          errorType: RecordingErrorType.unknown));
    }
  }

  Future<void> _onDebugCreateTestRecording(
      DebugCreateTestRecording event, Emitter<RecordingState> emit) async {
    try {
      final testRecording = RecordingEntity.create(
        name: 'Test Recording ${DateTime.now().millisecondsSinceEpoch}',
        filePath: '/test/path/recording.m4a',
        folderId: event.folderId ?? 'all_recordings',
        format: AudioFormat.m4a,
        duration: const Duration(seconds: 30),
        fileSize: 1024,
        sampleRate: 44100,
      );
      final saved = await _recordingRepository.createRecording(testRecording);
      emit(RecordingCompleted(recording: saved));
      _refreshFolderCounts();
    } catch (e) {
      print('❌ DEBUG: Error creating test recording: $e');
      emit(RecordingError('Debug test recording error: $e',
          errorType: RecordingErrorType.unknown));
    }
  }
}
