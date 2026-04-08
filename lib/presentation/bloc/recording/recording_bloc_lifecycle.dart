// File: presentation/bloc/recording/recording_bloc_lifecycle.dart
//
// Recording BLoC — Lifecycle Handlers
// =====================================
// Part of recording_bloc.dart. Contains event handlers for the core
// recording lifecycle: start, stop, pause, resume, cancel.
//
// Declared as an extension on RecordingBloc (same library → full access to
// private fields like _startRecordingUseCase, _audioService, etc.)

part of 'recording_bloc.dart';

extension _RecordingBlocLifecycle on RecordingBloc {
  // ==== START ====

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

    result.fold(
      (failure) => emit(
        RecordingError(
          failure.message,
          errorType: RecordingErrorType.recording,
        ),
      ),
      (data) {
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
        // Risolve il titolo geolocalizzato in background; la registrazione
        // è già partita e l'UI è aggiornata con il titolo temporaneo.
        _refreshTitleInBackground();
      },
    );
  }

  // ==== STOP ====

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingInProgress && state is! RecordingPaused) {
      emit(
        const RecordingError(
          'No active recording to stop',
          errorType: RecordingErrorType.state,
        ),
      );
      return;
    }

    // Recupera seekBasePath prima dell'emit di RecordingStopping
    String? seekBasePath;
    if (state is RecordingInProgress) {
      seekBasePath = (state as RecordingInProgress).seekBasePath;
    }

    emit(const RecordingStopping());
    _stopAmplitudeUpdates();
    _stopDurationUpdates();

    Duration? currentDuration;
    if (state is RecordingInProgress) {
      currentDuration = (state as RecordingInProgress).duration;
    } else if (state is RecordingPaused) {
      currentDuration = (state as RecordingPaused).duration;
    }

    // Approccio 1: se seek-and-resume, usa raw mode per mantenere tutto in WAV
    final useRaw = seekBasePath != null;
    final result = await _stopRecordingUseCase.execute(
      waveformData: event.waveformData,
      overrideDuration: currentDuration,
      raw: useRaw,
    );

    await result.fold(
      (failure) async => emit(
        RecordingError(
          failure.message,
          errorType: RecordingErrorType.recording,
        ),
      ),
      (recording) async {
        var finalRecording = recording;

        if (seekBasePath != null) {
          try {
            // Approccio 1: tutto in WAV → singola codifica finale
            // 1. Concatena WAV base + WAV continuazione → WAV combinato
            final combinedWavPath = '${recording.filePath}.combined.wav';
            await _trimmerService.concatenateAudio(
              basePath: seekBasePath,
              appendPath: recording.filePath,
              outputPath: combinedWavPath,
              format: 'wav', // PCM lossless concat
            );

            // 2. Rimuovi i file intermedi
            final baseFile = File(seekBasePath);
            if (await baseFile.exists()) await baseFile.delete();
            final contFile = File(recording.filePath);
            if (await contFile.exists()) await contFile.delete();

            // 3. Converti WAV combinato → formato finale (singola codifica)
            final formatExt = recording.format.fileExtension.substring(1);
            final finalPath = recording.filePath.replaceAll(
              '.wav',
              '.$formatExt',
            );
            final convertResult = await _audioService.convertAudioFile(
              inputPath: combinedWavPath,
              outputPath: finalPath,
              targetFormat: recording.format,
            );

            // 4. Rimuovi il WAV combinato
            try {
              await File(combinedWavPath).delete();
            } catch (_) {}

            if (convertResult != null) {
              final finalFile = File(finalPath);
              final fileSize = await finalFile.exists()
                  ? await finalFile.length()
                  : 0;
              finalRecording = recording.copyWith(
                filePath: finalPath,
                fileSize: fileSize,
              );
            }
          } catch (e) {
            debugPrint(
              '⚠️ Concatenazione/conversione seek-and-resume fallita: $e',
            );
          }
        }

        emit(RecordingCompleted(recording: finalRecording));
        _refreshFolderCounts();
      },
    );
  }

  // ==== PAUSE ====

  Future<void> _onPauseRecording(
    PauseRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingInProgress) return;

    _stopAmplitudeUpdates();
    _stopDurationUpdates();
    final s = state as RecordingInProgress;

    final result = await _pauseRecordingUseCase.executePause();
    result.fold(
      (failure) => print('❌ Failed to pause: ${failure.message}'),
      (duration) => emit(
        RecordingPaused(
          filePath: s.filePath,
          folderId: s.folderId,
          folderName: s.folderName,
          title: s.title,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: duration,
          startTime: s.startTime,
        ),
      ),
    );
  }

  // ==== RESUME ====

  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;

    final s = state as RecordingPaused;

    // Se il preview è attivo, fermalo prima di riprendere la registrazione
    if (s.isPlayingPreview) {
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      await _audioService.stopPlaying();
    }

    final result = await _pauseRecordingUseCase.executeResume();
    result.fold((failure) => print('❌ Failed to resume: ${failure.message}'), (
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
        ),
      );
      _startAmplitudeUpdates();
      _startDurationUpdates();
    });
  }

  // ==== SEEK-AND-RESUME ====

  Future<void> _onSeekAndResumeRecording(
    SeekAndResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;

    final s = state as RecordingPaused;
    emit(const RecordingStarting());
    _stopAmplitudeUpdates();
    _stopDurationUpdates();

    final result = await _seekAndResumeUseCase.execute(
      filePath: s.filePath,
      seekBarIndex: event.seekBarIndex,
      format: s.format,
      sampleRate: s.sampleRate,
      bitRate: s.bitRate,
      waveData: event.waveData,
    );

    result.fold(
      (failure) => emit(
        RecordingError(
          failure.message,
          errorType: RecordingErrorType.recording,
        ),
      ),
      (data) {
        final seekTimeMs = event.seekBarIndex * 100;
        emit(
          RecordingInProgress(
            filePath: s.filePath,
            folderId: s.folderId,
            folderName: s.folderName,
            format: s.format,
            sampleRate: s.sampleRate,
            bitRate: s.bitRate,
            duration: Duration(milliseconds: seekTimeMs),
            amplitude: 0.0,
            startTime: s.startTime,
            title: s.title,
            seekBasePath: data.seekBasePath,
            truncatedWaveData: data.truncatedWaveData,
          ),
        );
        _startAmplitudeUpdates();
        _startDurationUpdates();
      },
    );
  }

  // ==== CANCEL ====

  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      _stopAmplitudeUpdates();
      _stopDurationUpdates();
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      if (await _audioService.isPlaying()) await _audioService.stopPlaying();
      await _audioService.cancelRecording();
      emit(const RecordingCancelled());
    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
  }

  // ==== SEEK BAR INDEX ====

  Future<void> _onUpdateSeekBarIndex(
    UpdateSeekBarIndex event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
    if (s.seekBarIndex == event.seekBarIndex) return;
    debugPrint(
      '📍 SeekBar → bar ${event.seekBarIndex} (${event.seekBarIndex * 100}ms)',
    );
    emit(s.copyWith(seekBarIndex: event.seekBarIndex));
  }

  // ==== PLAYBACK PREVIEW ====

  Future<void> _onPlayRecordingPreview(
    PlayRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    // Ferma eventuale playback in corso
    if (await _audioService.isPlaying()) await _audioService.stopPlaying();

    final seekMs = s.seekBarIndex * 100;
    debugPrint('🔊 Play preview from bar ${s.seekBarIndex} (${seekMs}ms)');

    final initialPosition = seekMs > 0 ? Duration(milliseconds: seekMs) : null;
    final started = await _audioService.startPlaying(
      s.filePath,
      initialPosition: initialPosition,
    );
    if (!started) {
      debugPrint(
        '❌ PlayRecordingPreview: impossibile avviare il playback di ${s.filePath}',
      );
      return;
    }

    emit(s.copyWith(isPlayingPreview: true));

    // Aggiorna seekBarIndex durante il playback preview
    _previewPositionSubscription?.cancel();
    _previewPositionSubscription = _audioService
        .getPlaybackPositionStream()
        .listen((position) {
          final newIndex = position.inMilliseconds ~/ 100;
          if (state is RecordingPaused) {
            final current = (state as RecordingPaused).seekBarIndex;
            if (newIndex != current) {
              add(UpdateSeekBarIndex(seekBarIndex: newIndex));
            }
          }
        });

    // Auto-stop quando il playback finisce naturalmente
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
    _previewPositionSubscription = null;
    _previewCompletionSubscription?.cancel();
    _previewCompletionSubscription = null;
    await _audioService.stopPlaying();

    // Completamento naturale → cursore all'ULTIMA barra della waveform.
    // Nessun -1, altrimenti si fissa a 1 tick di distanza dalla vera fine visiva.
    final newSeekBarIndex = event.isNaturalCompletion
        ? (s.duration.inMilliseconds ~/ 100).clamp(0, 999999)
        : s.seekBarIndex;

    emit(s.copyWith(isPlayingPreview: false, seekBarIndex: newSeekBarIndex));
  }
}
