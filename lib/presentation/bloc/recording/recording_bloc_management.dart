// File: presentation/bloc/recording/recording_bloc_management.dart
part of 'recording_bloc.dart';

extension _RecordingBlocManagement on RecordingBloc {
  // ==== LOAD ====
  Future<void> _onLoadRecordings(
    LoadRecordings event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      emit(const RecordingLoading());
      final recordings = await _recordingRepository.getRecordingsByFolder(
        event.folderId,
      );
      emit(RecordingLoaded(recordings));
    } catch (e) {
      emit(
        RecordingError(
          'Failed to load recordings: $e',
          errorType: RecordingErrorType.unknown,
        ),
      );
    }
  }

  // ==== DELETE (SINGLE) ====
  Future<void> _onDeleteRecording(
    DeleteRecording event,
    Emitter<RecordingState> emit,
  ) async {
    final result = await _recordingRepository.deleteRecording(
      event.recordingId,
    );

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) {
        if (state is RecordingLoaded) {
          final s = state as RecordingLoaded;
          emit(
            s.copyWith(
              recordings: s.recordings
                  .where((r) => r.id != event.recordingId)
                  .toList(),
            ),
          );
          _refreshFolderCounts();
        }
      },
    );
  }

  Future<void> _onSoftDeleteRecording(
    SoftDeleteRecording event,
    Emitter<RecordingState> emit,
  ) async {
    final result = await _recordingRepository.softDeleteRecording(
      event.recordingId,
    );

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) {
        if (state is RecordingLoaded) {
          final s = state as RecordingLoaded;
          emit(
            s.copyWith(
              recordings: s.recordings
                  .where((r) => r.id != event.recordingId)
                  .toList(),
            ),
          );
          _refreshFolderCounts();
        }
      },
    );
  }

  Future<void> _onPermanentDeleteRecording(
    PermanentDeleteRecording event,
    Emitter<RecordingState> emit,
  ) async {
    final result = await _recordingRepository.permanentlyDeleteRecording(
      event.recordingId,
    );

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) {
        if (state is RecordingLoaded) {
          final s = state as RecordingLoaded;
          emit(
            s.copyWith(
              recordings: s.recordings
                  .where((r) => r.id != event.recordingId)
                  .toList(),
            ),
          );
          _refreshFolderCounts();
        }
      },
    );
  }

  // ==== RESTORE ====
  Future<void> _onRestoreRecording(
    RestoreRecording event,
    Emitter<RecordingState> emit,
  ) async {
    final result = await _recordingRepository.restoreRecording(
      event.recordingId,
    );

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) {
        if (state is RecordingLoaded) {
          final s = state as RecordingLoaded;
          emit(
            s.copyWith(
              recordings: s.recordings
                  .where((r) => r.id != event.recordingId)
                  .toList(),
            ),
          );
          _refreshFolderCounts();
        }
      },
    );
  }

  // ==== CLEANUP ====
  Future<void> _onCleanupExpiredRecordings(
    CleanupExpiredRecordings event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      final deleted = await _recordingRepository.cleanupExpiredRecordings();
      print('✅ Cleaned up $deleted expired recordings');
    } catch (e) {
      print('❌ Error cleaning up expired recordings: $e');
    }
  }

  // ==== BULK DELETE ====
  Future<void> _onDeleteSelectedRecordings(
    DeleteSelectedRecordings event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;
    final selectedIds = s.selectedRecordings;
    if (selectedIds.isEmpty) return;

    for (final id in selectedIds) {
      if (event.folderId == 'recently_deleted') {
        await _recordingRepository.deleteRecording(id);
      } else {
        await _recordingRepository.softDeleteRecording(id);
      }
    }
    emit(
      s.copyWith(
        recordings: s.recordings
            .where((r) => !selectedIds.contains(r.id))
            .toList(),
        selectedRecordings: <String>{},
      ),
    );
    _refreshFolderCounts();
  }

  // ==== FAVORITE ====
  Future<void> _onToggleFavoriteRecording(
    ToggleFavoriteRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;

    final result = await _recordingRepository.toggleFavorite(event.recordingId);

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) {
        if (!isClosed) {
          final updatedRecordings = s.recordings.map((r) {
            return r.id == event.recordingId ? r.toggleFavorite() : r;
          }).toList();

          emit(
            RecordingLoaded(
              updatedRecordings,
              isEditMode: s.isEditMode,
              selectedRecordings: s.selectedRecordings,
              timestamp: DateTime.now(),
            ),
          );
          _refreshFolderCounts();
        }
      },
    );
  }

  // ==== MOVE ====
  Future<void> _onMoveRecordingToFolder(
    MoveRecordingToFolder event,
    Emitter<RecordingState> emit,
  ) async {
    final result = await _recordingRepository.moveRecordingsToFolder([
      event.recordingId,
    ], event.targetFolderId);

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) async {
        if (state is RecordingLoaded && !isClosed) {
          final s = state as RecordingLoaded;
          final updated = await _recordingRepository.getRecordingsByFolder(
            event.currentFolderId,
          );
          if (!isClosed) emit(s.copyWith(recordings: updated));
        }
        _refreshFolderCounts();
      },
    );
  }

  Future<void> _onMoveSelectedRecordingsToFolder(
    MoveSelectedRecordingsToFolder event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingLoaded) return;
    final s = state as RecordingLoaded;
    final selectedIds = s.selectedRecordings.toList();
    if (selectedIds.isEmpty) return;

    final result = await _recordingRepository.moveRecordingsToFolder(
      selectedIds,
      event.targetFolderId,
    );

    result.fold(
      (failure) {
        emit(
          RecordingError(
            failure.userMessage,
            errorType: RecordingErrorType.unknown,
          ),
        );
      },
      (unit) async {
        if (!isClosed) {
          final updated = await _recordingRepository.getRecordingsByFolder(
            event.currentFolderId,
          );
          if (!isClosed) {
            emit(
              s.copyWith(
                recordings: updated,
                selectedRecordings: const {},
                isEditMode: false,
              ),
            );
          }
        }
        _refreshFolderCounts();
      },
    );
  }

  // ==== DEBUG ====
  Future<void> _onDebugLoadAllRecordings(
    DebugLoadAllRecordings event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      emit(const RecordingLoading());
      final all = await _recordingRepository.getAllRecordings();
      emit(RecordingLoaded(all));
    } catch (e) {
      emit(
        RecordingError(
          'Debug error: $e',
          errorType: RecordingErrorType.unknown,
        ),
      );
    }
  }

  Future<void> _onDebugCreateTestRecording(
    DebugCreateTestRecording event,
    Emitter<RecordingState> emit,
  ) async {
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
      emit(
        RecordingError(
          'Debug test recording error: $e',
          errorType: RecordingErrorType.unknown,
        ),
      );
    }
  }
}
