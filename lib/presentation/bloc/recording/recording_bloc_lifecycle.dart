// File: presentation/bloc/recording/recording_bloc_lifecycle.dart
part of 'recording_bloc.dart';

extension _RecordingBlocLifecycle on RecordingBloc {
  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    emit(const RecordingStarting());
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
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      await _audioService.stopPlaying();
    }

    // Pulisci il file preview se esiste
    if (state is RecordingPaused) {
      final pausedState = state as RecordingPaused;
      if (pausedState.previewFilePath != null) {
        try {
          final absolutePreviewPath = await pausedState.resolvedPreviewFilePath;
          if (absolutePreviewPath != null)
            File(absolutePreviewPath).deleteSync();
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

    emit(const RecordingStopping());
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
        await _trimmerService.overwriteAudioSegment(
          originalPath: await AppFileUtils.resolve(seekBasePath),
          insertionPath: part2Path,
          startTime: overwriteStartTime ?? Duration.zero,
          overwriteDuration: Duration(milliseconds: insertionDurationMs),
          outputPath: finalWavPath,
          format: 'wav',
        );

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
            if (r.name == locationName)
              highestNumber = highestNumber > 1 ? highestNumber : 1;
            else {
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

    // Se eravamo in overdub, la durata nativa del segmento è sufficiente
    final finalSegmentDuration = nativeDuration;

    final pausedState = RecordingPaused(
      filePath: s.filePath,
      folderId: s.folderId,
      folderName: s.folderName,
      title: s.title,
      format: s.format,
      sampleRate: s.sampleRate,
      bitRate: s.bitRate,
      duration: finalSegmentDuration, // <-- Usa la durata nativa del segmento
      startTime: s.startTime,
      seekBasePath: s.seekBasePath,
      originalFilePathForOverwrite: s.originalFilePathForOverwrite,
      overwriteStartTime: s.overwriteStartTime,
      truncatedWaveData: s.truncatedWaveData,
      previewFilePath: null,
    );

    final previewPath = await _assemblePreviewFile(pausedState);

    if (emit.isDone) return;

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
        ),
      );
      _startAmplitudeUpdates();
      _startDurationUpdates();
    });
  }

  Future<void> _onResumeWithAutoStop(
    ResumeWithAutoStop event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    if (s.isPlayingPreview) {
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      await _audioService.stopPlaying();

      try {
        final dir = File(await s.resolvedFilePath).parent;
        final files = dir.listSync();
        for (var f in files) {
          if (f.path.contains('_preview_') && f.path.endsWith('.wav')) {
            f.deleteSync();
          }
        }
      } catch (_) {}
      emit(s.copyWith(isPlayingPreview: false));
    }

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
    final totalBars = (totalDurationMs / 100).ceil();
    // Tolleranza ripristinata: circa 200 ms
    final isAtEnd = event.seekBarIndex >= totalBars - 2;

    if (isAtEnd) {
      if (s.seekBasePath == null) {
        final result = await _pauseRecordingUseCase.executeResume();
        result.fold((failure) => emit(RecordingError(failure.message)), (
          duration,
        ) {
          emit(
            RecordingInProgress(
              filePath: s.filePath,
              folderId: s.folderId,
              folderName: s.folderName,
              format: s.format,
              sampleRate: s.sampleRate,
              bitRate: s.bitRate,
              duration: duration,
              amplitude: 0.0,
              startTime: s.startTime,
              title: s.title,
              seekBasePath: null,
              originalFilePathForOverwrite: null,
              overwriteStartTime: null,
              truncatedWaveData: null,
            ),
          );
          _startAmplitudeUpdates();
          _startDurationUpdates();
        });
      } else {
        await _continueFromEndAfterOverdub(event, emit, s);
      }
    } else {
      add(
        StartOverwrite(
          seekBarIndex: event.seekBarIndex,
          waveData: event.waveData,
        ),
      );
    }
  }

  Future<void> _continueFromEndAfterOverdub(
    ResumeWithAutoStop event,
    Emitter<RecordingState> emit,
    RecordingPaused s,
  ) async {
    emit(const RecordingStarting());
    final overdubEntity = await _audioService.stopRecording(raw: true);
    final String consolidatedPath;
    final Duration consolidatedDuration;

    if (overdubEntity != null && overdubEntity.filePath.isNotEmpty) {
      final tempPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_merged_${DateTime.now().millisecondsSinceEpoch}.wav";
      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: await AppFileUtils.resolve(s.seekBasePath!),
          insertionPath: await AppFileUtils.resolve(overdubEntity.filePath),
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: overdubEntity.duration,
          outputPath: tempPath,
          format: 'wav',
        );
        try {
          File(await AppFileUtils.resolve(s.seekBasePath!)).deleteSync();
          File(await AppFileUtils.resolve(overdubEntity.filePath)).deleteSync();
        } catch (_) {}
        consolidatedPath = tempPath;
        consolidatedDuration = await _audioService.getAudioDuration(tempPath);
      } catch (e) {
        emit(RecordingError('Errore consolidamento overdub: $e'));
        return;
      }
    } else {
      consolidatedPath = await AppFileUtils.resolve(s.seekBasePath!);
      consolidatedDuration = await _audioService.getAudioDuration(
        consolidatedPath,
      );
    }

    final newPath =
        "${s.originalFilePathForOverwrite ?? s.filePath}_cont_${DateTime.now().millisecondsSinceEpoch}.wav";
    final started = await _audioService.startRecording(
      filePath: newPath,
      format: s.format,
      sampleRate: s.sampleRate,
      bitRate: s.bitRate,
    );

    if (!started) {
      emit(
        const RecordingError('Impossibile avviare la registrazione dalla fine'),
      );
      return;
    }

    final int consolidatedBars = (consolidatedDuration.inMilliseconds / 100)
        .floor();
    final List<double> alignedWaveData = event.waveData
        .take(consolidatedBars)
        .toList();

    emit(
      RecordingInProgress(
        filePath: await AppFileUtils.toRelative(newPath),
        folderId: s.folderId,
        folderName: s.folderName,
        format: s.format,
        sampleRate: s.sampleRate,
        bitRate: s.bitRate,
        duration: Duration.zero,
        amplitude: 0.0,
        startTime: DateTime.now(),
        title: s.title,
        seekBasePath: await AppFileUtils.toRelative(consolidatedPath),
        overwriteStartTime: consolidatedDuration,
        originalFilePathForOverwrite:
            s.originalFilePathForOverwrite ?? s.filePath,
        truncatedWaveData: alignedWaveData,
      ),
    );
    _startAmplitudeUpdates();
    _startDurationUpdates();
  }

  Future<void> _onStartOverwrite(
    StartOverwrite event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
    emit(const RecordingStarting());

    if (s.previewFilePath != null) {
      try {
        final absolutePreviewPath = await s.resolvedPreviewFilePath;
        if (absolutePreviewPath != null) File(absolutePreviewPath).deleteSync();
      } catch (_) {}
    }

    final baseRecordingEntity = await _audioService.stopRecording(raw: true);
    final int rawDurationMs = event.seekBarIndex * 100;
    final durationMs = rawDurationMs < 100 ? 100 : rawDurationMs;

    String pathToOverwrite = s.seekBasePath ?? s.filePath;

    if (baseRecordingEntity != null &&
        baseRecordingEntity.filePath.isNotEmpty &&
        s.seekBasePath != null) {
      final baseWavPath = await AppFileUtils.resolve(
        baseRecordingEntity.filePath,
      );
      final tempConcatPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_temp_concat_${DateTime.now().millisecondsSinceEpoch}.wav";

      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: await AppFileUtils.resolve(s.seekBasePath!),
          insertionPath: baseWavPath,
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: baseRecordingEntity.duration,
          outputPath: tempConcatPath,
          format: 'wav',
        );
        pathToOverwrite = tempConcatPath;
        try {
          File(await AppFileUtils.resolve(s.seekBasePath!)).deleteSync();
          File(baseWavPath).deleteSync();
        } catch (_) {}
      } catch (e) {
        emit(RecordingError('Failed to apply previous overwrite for seek: $e'));
        return;
      }
    }

    final newRecordingPath =
        "${s.filePath}.part2_${DateTime.now().millisecondsSinceEpoch}.wav";
    final started = await _audioService.startRecording(
      filePath: await AppFileUtils.resolve(newRecordingPath),
      format: s.format,
      sampleRate: s.sampleRate,
      bitRate: s.bitRate,
    );

    if (started) {
      final truncatedWave = event.waveData
          .take(event.seekBarIndex + 1)
          .toList();
      emit(
        RecordingInProgress(
          filePath: await AppFileUtils.toRelative(newRecordingPath),
          folderId: s.folderId,
          folderName: s.folderName,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: Duration.zero,
          amplitude: 0.0,
          startTime: DateTime.now(),
          title: s.title,
          seekBasePath: await AppFileUtils.toRelative(pathToOverwrite),
          overwriteStartTime: Duration(milliseconds: durationMs),
          originalFilePathForOverwrite:
              s.originalFilePathForOverwrite ?? s.filePath,
          truncatedWaveData: truncatedWave,
        ),
      );
      _startAmplitudeUpdates();
      _startDurationUpdates();
    } else {
      emit(const RecordingError('Failed to start recording after seek'));
    }
  }

  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      _stopAmplitudeUpdates();
      _stopDurationUpdates();
      _previewPositionSubscription?.cancel();
      _previewCompletionSubscription?.cancel();
      if (await _audioService.isPlaying()) await _audioService.stopPlaying();

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

  Future<void> _onPlayRecordingPreview(
    PlayRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    if (await _audioService.isPlaying()) await _audioService.stopPlaying();

    final seekMs = s.seekBarIndex * 100;
    final playbackPath =
        await s.resolvedPreviewFilePath ?? await s.resolvedFilePath;
    final initialPosition = seekMs > 0 ? Duration(milliseconds: seekMs) : null;

    final started = await _audioService.startPlaying(
      playbackPath,
      initialPosition: initialPosition,
    );
    if (!started) return;

    emit(s.copyWith(isPlayingPreview: true));
    _previewPositionSubscription?.cancel();
    _previewPositionSubscription = _audioService
        .getPlaybackPositionStream()
        .listen((position) {
          final newIndex = position.inMilliseconds ~/ 100;
          if (state is RecordingPaused) {
            final current = (state as RecordingPaused).seekBarIndex;
            if (newIndex != current)
              add(
                UpdateSeekBarIndex(
                  seekBarIndex: newIndex,
                  stopPreview: false,
                  isFromPlayback: true,
                ),
              );
          }
        });
    _previewCompletionSubscription?.cancel();
    _previewCompletionSubscription = _audioService
        .getPlaybackCompletionStream()
        .listen(
          (_) => add(const StopRecordingPreview(isNaturalCompletion: true)),
        );
  }

  Future<void> _onStopRecordingPreview(
    StopRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
    _previewPositionSubscription?.cancel();
    _previewCompletionSubscription?.cancel();
    await _audioService.stopPlaying();

    Duration? finalDuration;
    try {
      final dir = File(await s.resolvedFilePath).parent;
      final files = dir.listSync();
      for (var f in files) {
        if (f.path.contains('_preview_') && f.path.endsWith('.wav')) {
          finalDuration = await _audioService.getAudioDuration(f.path);
          f.deleteSync();
        }
      }
    } catch (_) {}

    emit(
      s.copyWith(
        isPlayingPreview: false,
        duration: finalDuration ?? s.duration,
      ),
    );
  }

  Future<String?> _assemblePreviewFile(RecordingPaused state) async {
    if (state.seekBasePath == null ||
        state.originalFilePathForOverwrite == null)
      return null;
    final tempPreviewPath =
        "${state.originalFilePathForOverwrite}_preview_${DateTime.now().millisecondsSinceEpoch}.wav";
    try {
      final baseDuration = await _audioService.getAudioDuration(
        await AppFileUtils.resolve(state.seekBasePath!),
      );
      final baseDurationMs = baseDuration.inMilliseconds;
      final isSimpleConcatenation =
          state.overwriteStartTime?.inMilliseconds == baseDurationMs;

      if (isSimpleConcatenation) {
        await _trimmerService.concatenateAudio(
          basePath: await AppFileUtils.resolve(state.seekBasePath!),
          appendPath: await state.resolvedFilePath,
          outputPath: tempPreviewPath,
          format: 'wav',
        );
      } else {
        // Usa direttamente la durata del segmento
        final overwriteDuration = state.duration;

        await _trimmerService.overwriteAudioSegment(
          originalPath: await AppFileUtils.resolve(state.seekBasePath!),
          insertionPath: await state.resolvedFilePath,
          startTime: state.overwriteStartTime ?? Duration.zero,
          overwriteDuration: overwriteDuration, // <-- usa il valore direttamente
          outputPath: tempPreviewPath,
          format: 'wav',
        );
      }
      return tempPreviewPath;
    } catch (e) {
      debugPrint('❌ Errore assembly preview: $e');
      return null;
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
    debugPrint('📍 SeekBar → bar $clampedIndex (${clampedIndex * 100}ms)');

    if (s.isPlayingPreview) {
      if (event.stopPreview) {
        debugPrint('⏹ Stop preview due to waveform drag');
        add(const StopRecordingPreview(isNaturalCompletion: false));
      } else if (!event.isFromPlayback) {
        final seekPosition = Duration(milliseconds: clampedIndex * 100);
        debugPrint(
          '🔊 Seek during playback to: ${seekPosition.inMilliseconds}ms',
        );
        await _audioService.seekTo(seekPosition);
      }
    }

    emit(s.copyWith(seekBarIndex: clampedIndex));
  }
}
