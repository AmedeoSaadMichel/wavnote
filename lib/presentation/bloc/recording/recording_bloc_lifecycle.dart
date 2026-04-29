// File: lib/presentation/bloc/recording/recording_bloc_lifecycle.dart
part of 'recording_bloc.dart';

extension _RecordingBlocLifecycle on RecordingBloc {
  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    final recordings = state is RecordingLoaded
        ? (state as RecordingLoaded).recordings
        : <RecordingEntity>[];
    emit(RecordingStarting(recordings: recordings));
    final result = await _startRecordingUseCase.execute(
      folderId: event.folderId ?? 'all_recordings',
      format: event.format,
      sampleRate: event.sampleRate,
      bitRate: event.bitRate,
    );
    result.fold((failure) => emit(RecordingError(failure.message)), (data) {
      _startAmplitudeUpdates();
      _startDurationUpdates();
      emit(
        RecordingInProgress(
          filePath: data.filePath,
          folderId: data.folderId,
          folderName: event.folderName,
          format: data.format,
          sampleRate: data.sampleRate,
          bitRate: data.bitRate,
          duration: Duration.zero,
          amplitude: 0.0,
          startTime: data.startTime,
          title: data.title,
          recordings: recordings,
        ),
      );
      _refreshTitleInBackground();
    });
  }

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingInProgress && state is! RecordingPaused) return;

    // Ferma il preview se era in esecuzione
    if (state is RecordingPaused &&
        (state as RecordingPaused).isPlayingPreview) {
      emit((state as RecordingPaused).copyWith(isPlayingPreview: false));
    }

    // Pulisci il file preview se esiste
    if (state is RecordingPaused) {
      final pausedState = state as RecordingPaused;
      if (pausedState.previewFilePath != null) {
        try {
          final absolutePreviewPath = await pausedState.resolvedPreviewFilePath;
          if (absolutePreviewPath != null) {
            File(absolutePreviewPath).deleteSync();
          }
        } catch (_) {}
      }
    }

    final s = state;

    final seekBasePath = (s is RecordingInProgress)
        ? s.seekBasePath
        : (s as RecordingPaused).seekBasePath;
    final originalFilePathForOverwrite = (s is RecordingInProgress)
        ? s.originalFilePathForOverwrite
        : (s as RecordingPaused).originalFilePathForOverwrite;
    final format = (s is RecordingInProgress)
        ? s.format
        : (s as RecordingPaused).format;
    final sampleRate = (s is RecordingInProgress)
        ? s.sampleRate
        : (s as RecordingPaused).sampleRate;
    final bitRate = (s is RecordingInProgress)
        ? s.bitRate
        : (s as RecordingPaused).bitRate;
    final overwriteStartTime = (s is RecordingInProgress)
        ? s.overwriteStartTime
        : (s as RecordingPaused).overwriteStartTime;
    final folderId = (s is RecordingInProgress)
        ? s.folderId
        : (s as RecordingPaused).folderId;
    final truncatedWaveData = (s is RecordingInProgress)
        ? s.truncatedWaveData
        : (s as RecordingPaused).truncatedWaveData;

    final List<RecordingEntity> recordings;
    if (s is RecordingInProgress) {
      recordings = s.recordings;
    } else if (s is RecordingPaused) {
      recordings = s.recordings;
    } else {
      // Fallback, though this state should not be reached if canStopRecording is enforced.
      recordings = [];
    }
    emit(
      RecordingStopping(
        recordings: recordings,
        truncatedWaveData: truncatedWaveData,
      ),
    );
    _stopAmplitudeUpdates();
    _stopDurationUpdates();

    // Logica di Seek-and-Resume (se c'è un base path tagliato)
    if (seekBasePath != null && originalFilePathForOverwrite != null) {
      final part2ResultEntity = await _audioService.stopRecording(raw: true);

      if (part2ResultEntity == null || part2ResultEntity.filePath.isEmpty) {
        emit(const RecordingError('Failed to stop part 2 recording'));
        return;
      }

      final part2Path = await AppFileUtils.resolve(part2ResultEntity.filePath);
      final finalWavPath =
          "${originalFilePathForOverwrite}_final_${DateTime.now().millisecondsSinceEpoch}.wav";

      final insertionDurationMs = part2ResultEntity.duration.inMilliseconds;

      try {
        final owResult1 = await _overwriteRecordingUseCase.execute(
          originalPath: await AppFileUtils.resolve(seekBasePath),
          insertionPath: part2Path,
          startTime: overwriteStartTime ?? Duration.zero,
          overwriteDuration: Duration(milliseconds: insertionDurationMs),
          outputPath: finalWavPath,
          format: 'wav',
        );
        if (owResult1.isLeft()) {
          emit(
            RecordingError(
              owResult1.fold((f) => f.message, (_) => 'Overwrite failed'),
            ),
          );
          return;
        }

        // Delete partial files
        try {
          File(await AppFileUtils.resolve(seekBasePath)).deleteSync();
          File(part2Path).deleteSync();
        } catch (_) {}

        String finalOutputPath = finalWavPath;

        // Se l'utente ha richiesto un formato diverso da WAV, convertiamo
        if (format.fileExtension != '.wav') {
          final convertedPath = await _audioService.convertAudioFile(
            inputPath: finalWavPath,
            outputPath: await AppFileUtils.resolve(
              originalFilePathForOverwrite,
            ),
            targetFormat: format,
            targetSampleRate: sampleRate,
            targetBitRate: bitRate,
          );

          if (convertedPath != null) {
            finalOutputPath = convertedPath;
            try {
              File(finalWavPath).deleteSync();
            } catch (_) {}
          } else {
            emit(const RecordingError('Failed to convert concatenated audio'));
            return;
          }
        }

        final duration = await _audioService.getAudioDuration(finalOutputPath);
        final file = File(finalOutputPath);
        final fileSize = await file.length();

        String locationName = 'Recording';
        try {
          locationName = await _locationRepository
              .getRecordingLocationName()
              .timeout(const Duration(seconds: 3));
        } catch (_) {}

        final existingRecordings = await _recordingRepository
            .getRecordingsByFolder(folderId ?? 'all_recordings');
        final matchingRecordings = existingRecordings
            .where((r) => r.name.startsWith(locationName))
            .toList();

        String newName = locationName;
        if (matchingRecordings.isNotEmpty) {
          int highestNumber = 0;
          for (final r in matchingRecordings) {
            if (r.name == locationName) {
              highestNumber = highestNumber > 1 ? highestNumber : 1;
            } else {
              final escaped = RegExp.escape(locationName);
              final match = RegExp('^$escaped (\\d+)\$').firstMatch(r.name);
              if (match != null) {
                final num = int.tryParse(match.group(1) ?? '0') ?? 0;
                if (num > highestNumber) highestNumber = num;
              }
            }
          }
          newName = '$locationName ${highestNumber + 1}';
        }

        final recording =
            RecordingEntity.create(
              name: newName,
              filePath:
                  finalOutputPath, // Sarà convertito in relativo nel Repository
              folderId: folderId ?? 'all_recordings',
              format: format,
              duration: duration,
              fileSize: fileSize,
              sampleRate: sampleRate,
            ).copyWith(
              waveformData: event.waveformData ?? truncatedWaveData,
              locationName: locationName,
            );

        // Ora che abbiamo l'entità, rinominiamo il file fisico
        final absoluteFinalOutputPath = await recording.resolvedFilePath;
        final oldFile = File(absoluteFinalOutputPath);
        final directory = oldFile.parent.path;
        final fileExtension = path.extension(absoluteFinalOutputPath);
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        final safeNewName = newName
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');

        final newFileName = '${safeNewName}_$timestamp$fileExtension';
        final newPath = path.join(directory, newFileName);

        RecordingEntity finalRecording;

        try {
          await oldFile.rename(newPath);
          debugPrint('✅ Renamed recording to: $newPath');
          finalRecording = recording.copyWith(
            filePath: await AppFileUtils.toRelative(newPath),
          );
        } catch (e) {
          debugPrint(
            '⚠️ Could not rename recording file, using original path. Error: $e',
          );
          finalRecording = recording;
        }

        final saved = await _recordingRepository.createRecording(
          finalRecording,
        );
        emit(RecordingCompleted(recording: saved));
        _refreshFolderCounts();
      } catch (e) {
        emit(RecordingError('Seek-and-Resume finalization failed: $e'));
      }
    } else {
      final result = await _stopRecordingUseCase.execute(
        waveformData: event.waveformData,
      );
      result.fold((failure) => emit(RecordingError(failure.message)), (
        recording,
      ) {
        emit(RecordingCompleted(recording: recording));
        _refreshFolderCounts();
      });
    }
  }

  Future<void> _onPauseRecording(
    PauseRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingInProgress) return;
    final s = state as RecordingInProgress;
    _stopAmplitudeUpdates();
    _stopDurationUpdates();

    final result = await _pauseRecordingUseCase.executePause();

    final Duration? nativeDuration = result.fold((_) => null, (d) => d);
    if (nativeDuration == null) {
      emit(
        RecordingError(result.fold((f) => f.message, (_) => 'Unknown error')),
      );
      return;
    }

    // Calcolo seekBarIndex per la source of truth
    int pausedSeekBarIndex = 0;
    final int segmentDurationMs = nativeDuration.inMilliseconds;

    if (s.seekBasePath == null) {
      final bars = (segmentDurationMs / 100).floor();
      pausedSeekBarIndex = bars > 0 ? bars - 1 : 0;
      debugPrint(
        '⏸️ PAUSE CALC [NORMAL] segmentDurationMs=$segmentDurationMs bars=$bars pausedSeekBarIndex=$pausedSeekBarIndex',
      );
    } else {
      int baseDurationMs = 0;
      try {
        final baseDuration = await _audioService.getAudioDuration(
          await AppFileUtils.resolve(s.seekBasePath!),
        );
        baseDurationMs = baseDuration.inMilliseconds;
      } catch (_) {
        // Fallback se il file base non è leggibile
      }
      final overwriteStartMs = s.overwriteStartTime?.inMilliseconds ?? 0;
      final totalDurationMs = [
        baseDurationMs,
        overwriteStartMs + segmentDurationMs,
      ].reduce((a, b) => a > b ? a : b);

      final bars = (totalDurationMs / 100).floor();
      pausedSeekBarIndex = bars > 0 ? bars - 1 : 0;
      debugPrint(
        '⏸️ PAUSE CALC [OVERDUB] baseDurationMs=$baseDurationMs overwriteStartMs=$overwriteStartMs segmentDurationMs=$segmentDurationMs totalDurationMs=$totalDurationMs bars=$bars pausedSeekBarIndex=$pausedSeekBarIndex',
      );
    }

    final pausedState = RecordingPaused(
      filePath: s.filePath,
      folderId: s.folderId,
      folderName: s.folderName,
      recordings: s.recordings,
      title: s.title,
      format: s.format,
      sampleRate: s.sampleRate,
      bitRate: s.bitRate,
      duration: nativeDuration, // <-- Usa la durata nativa del segmento
      startTime: s.startTime,
      seekBasePath: s.seekBasePath,
      originalFilePathForOverwrite: s.originalFilePathForOverwrite,
      overwriteStartTime: s.overwriteStartTime,
      truncatedWaveData: s.truncatedWaveData,
      waveformAmplitudeSamples: s.waveformAmplitudeSamples,
      waveformAmplitudeSampleCount: s.waveformAmplitudeSampleCount,
      previewFilePath: null,
      seekBarIndex: pausedSeekBarIndex, // <-- Passa l'indice calcolato
    );

    final previewPath = await _assemblePreviewFile(pausedState);

    if (emit.isDone) return;

    debugPrint(
      '⏸️ EMIT RecordingPaused durationMs=${pausedState.duration.inMilliseconds} seekBarIndex=${pausedState.seekBarIndex} seekBasePath=${pausedState.seekBasePath} overwriteStartMs=${pausedState.overwriteStartTime?.inMilliseconds}',
    );
    emit(pausedState.copyWith(previewFilePath: previewPath));
  }

  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    if (s.previewFilePath != null) {
      try {
        final absolutePreviewPath = await s.resolvedPreviewFilePath;
        if (absolutePreviewPath != null) File(absolutePreviewPath).deleteSync();
      } catch (_) {}
    }

    final result = await _pauseRecordingUseCase.executeResume();
    result.fold((failure) => emit(RecordingError(failure.message)), (duration) {
      emit(
        RecordingInProgress(
          filePath: s.filePath,
          folderId: s.folderId,
          recordings: s.recordings,
          folderName: s.folderName,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: duration,
          amplitude: 0.0,
          startTime: s.startTime,
          title: s.title,
          seekBasePath: s.seekBasePath,
          originalFilePathForOverwrite: s.originalFilePathForOverwrite,
          overwriteStartTime: s.overwriteStartTime,
          truncatedWaveData: s.truncatedWaveData,
          waveformAmplitudeSamples: s.waveformAmplitudeSamples,
          waveformAmplitudeSampleCount: s.waveformAmplitudeSampleCount,
        ),
      );
      _startAmplitudeUpdates();
      _startDurationUpdates();
    });
  }

  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      _stopAmplitudeUpdates();
      _stopDurationUpdates();

      if (state is RecordingPaused) {
        final pausedState = state as RecordingPaused;
        final absolutePreviewPath = await pausedState.resolvedPreviewFilePath;
        if (absolutePreviewPath != null) {
          try {
            File(absolutePreviewPath).deleteSync();
          } catch (_) {}
        }
      }
      await _audioService.cancelRecording();
      emit(const RecordingCancelled());
    } catch (e) {
      debugPrint('❌ Error cancelling recording: $e');
    }
  }

  Future<void> _onUpdateSeekBarIndex(
    UpdateSeekBarIndex event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    if (event.isFromPlayback && !s.isPlayingPreview) return;

    int totalDurationMs = s.duration.inMilliseconds;
    if (s.seekBasePath != null) {
      try {
        final baseDuration = await _audioService.getAudioDuration(
          await AppFileUtils.resolve(s.seekBasePath!),
        );
        final baseDurationMs = baseDuration.inMilliseconds;
        final overwriteMs = s.overwriteStartTime?.inMilliseconds ?? 0;
        final endMs = overwriteMs + s.duration.inMilliseconds;
        totalDurationMs = endMs > baseDurationMs ? endMs : baseDurationMs;
      } catch (_) {
        final overwriteMs = s.overwriteStartTime?.inMilliseconds ?? 0;
        totalDurationMs = overwriteMs + s.duration.inMilliseconds;
      }
    }

    final maxIndex = (totalDurationMs ~/ 100);
    final clampedIndex = event.seekBarIndex.clamp(0, maxIndex);

    if (s.seekBarIndex == clampedIndex) return;
    debugPrint(
      '📍 SEEK UPDATE from=${s.seekBarIndex} requested=${event.seekBarIndex} clamped=$clampedIndex maxIndex=$maxIndex stopPreview=${event.stopPreview} isFromPlayback=${event.isFromPlayback} totalDurationMs=$totalDurationMs',
    );

    if (s.isPlayingPreview) {
      if (event.stopPreview) {
        debugPrint('⏹ Preview stop richiesto dalla UI durante drag waveform');
      }
    }

    emit(s.copyWith(seekBarIndex: clampedIndex));
  }
}
