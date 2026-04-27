// File: presentation/bloc/recording/recording_bloc_overdub.dart
part of 'recording_bloc.dart';

extension _RecordingBlocOverdub on RecordingBloc {
  Future<void> _onResumeWithAutoStop(
    ResumeWithAutoStop event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    if (s.isPlayingPreview) {
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
    debugPrint(
      '▶️ RESUME CHECK eventSeekBarIndex=${event.seekBarIndex} stateSeekBarIndex=${s.seekBarIndex} totalDurationMs=$totalDurationMs totalBars=$totalBars isAtEnd=$isAtEnd seekBasePath=${s.seekBasePath} overwriteStartMs=${s.overwriteStartTime?.inMilliseconds}',
    );

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
              recordings: s.recordings,
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
    emit(RecordingStarting(recordings: s.recordings, truncatedWaveData: s.truncatedWaveData));
    final overdubEntity = await _audioService.stopRecording(raw: true);
    final String consolidatedPath;
    final Duration consolidatedDuration;

    if (overdubEntity != null && overdubEntity.filePath.isNotEmpty) {
      final tempPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_merged_${DateTime.now().millisecondsSinceEpoch}.wav";
      try {
        final owResult2 = await _overwriteRecordingUseCase.execute(
          originalPath: await AppFileUtils.resolve(s.seekBasePath!),
          insertionPath: await AppFileUtils.resolve(overdubEntity.filePath),
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: overdubEntity.duration,
          outputPath: tempPath,
          format: 'wav',
        );
        if (owResult2.isLeft()) {
          emit(RecordingError(owResult2.fold((f) => f.message, (_) => 'Consolidamento overdub fallito')));
          return;
        }
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
        recordings: s.recordings,
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
    emit(RecordingStarting(recordings: s.recordings, truncatedWaveData: s.truncatedWaveData));

    if (s.previewFilePath != null) {
      try {
        final absolutePreviewPath = await s.resolvedPreviewFilePath;
        if (absolutePreviewPath != null) File(absolutePreviewPath).deleteSync();
      } catch (_) {}
    }

    final baseRecordingEntity = await _audioService.stopRecording(raw: true);
    final int rawDurationMs = event.seekBarIndex * 100;
    final durationMs = rawDurationMs < 100 ? 100 : rawDurationMs;

    // Il native engine registra sempre in WAV ma s.filePath può avere estensione
    // diversa (.m4a, .flac). baseRecordingEntity.filePath punta al WAV effettivo.
    String pathToOverwrite;
    if (s.seekBasePath != null) {
      pathToOverwrite = s.seekBasePath!;
    } else if (baseRecordingEntity != null && baseRecordingEntity.filePath.isNotEmpty) {
      pathToOverwrite = await AppFileUtils.toRelative(baseRecordingEntity.filePath);
    } else {
      pathToOverwrite = s.filePath;
    }

    if (baseRecordingEntity != null &&
        baseRecordingEntity.filePath.isNotEmpty &&
        s.seekBasePath != null) {
      final baseWavPath = await AppFileUtils.resolve(
        baseRecordingEntity.filePath,
      );
      final tempConcatPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_temp_concat_${DateTime.now().millisecondsSinceEpoch}.wav";

      try {
        final owResult3 = await _overwriteRecordingUseCase.execute(
          originalPath: await AppFileUtils.resolve(s.seekBasePath!),
          insertionPath: baseWavPath,
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: baseRecordingEntity.duration,
          outputPath: tempConcatPath,
          format: 'wav',
        );
        if (owResult3.isLeft()) {
          emit(RecordingError(owResult3.fold((f) => f.message, (_) => 'Overwrite seek fallito')));
          return;
        }
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
          recordings: s.recordings,
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
          waveformDataForPlayer: event.waveData,
        ),
      );
      _startAmplitudeUpdates();
      _startDurationUpdates();
    } else {
      emit(const RecordingError('Failed to start recording after seek'));
    }
  }

  Future<void> _onPlayRecordingPreview(
    PlayRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
    emit(s.copyWith(isPlayingPreview: true));
  }

  Future<void> _onStopRecordingPreview(
    StopRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    // Legge la durata del preview file senza eliminarlo.
    // Il file viene eliminato nei punti corretti: _onResumeRecording,
    // _onStartOverwrite, _onResumeWithAutoStop. Eliminarlo qui causerebbe
    // l'errore ExtAudioFileOpenURL alla seconda pressione di Play.
    Duration? finalDuration;
    try {
      final dir = File(await s.resolvedFilePath).parent;
      final files = dir.listSync();
      for (var f in files) {
        if (f.path.contains('_preview_') && f.path.endsWith('.wav')) {
          finalDuration = await _audioService.getAudioDuration(f.path);
        }
      }
    } catch (_) {}

    emit(
      s.copyWith(
        isPlayingPreview: false,
        duration: finalDuration ?? s.duration,
        seekBarIndex: event.isNaturalCompletion
            ? s.seekBarIndex
            : (event.stoppedSeekBarIndex ?? s.seekBarIndex),
      ),
    );
  }

  Future<String?> _assemblePreviewFile(RecordingPaused state) async {
    if (state.seekBasePath == null ||
        state.originalFilePathForOverwrite == null) {
      return null;
    }
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
        final overwriteDuration = state.duration;

        final owResult4 = await _overwriteRecordingUseCase.execute(
          originalPath: await AppFileUtils.resolve(state.seekBasePath!),
          insertionPath: await state.resolvedFilePath,
          startTime: state.overwriteStartTime ?? Duration.zero,
          overwriteDuration: overwriteDuration,
          outputPath: tempPreviewPath,
          format: 'wav',
        );
        if (owResult4.isLeft()) {
          debugPrint('❌ Errore assembly preview: ${owResult4.fold((f) => f.message, (_) => '')}');
          return null;
        }
      }
      return tempPreviewPath;
    } catch (e) {
      debugPrint('❌ Errore assembly preview: $e');
      return null;
    }
  }
}
