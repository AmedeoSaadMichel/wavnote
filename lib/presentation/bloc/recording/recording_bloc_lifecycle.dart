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
      StartRecording event, Emitter<RecordingState> emit) async {
    emit(const RecordingStarting());

    final result = await _startRecordingUseCase.execute(
      folderId: event.folderId ?? 'all_recordings',
      format: event.format,
      sampleRate: event.sampleRate,
      bitRate: event.bitRate,
    );

    result.fold(
      (failure) => emit(RecordingError(failure.message,
          errorType: RecordingErrorType.recording)),
      (data) {
        _startAmplitudeUpdates();
        _startDurationUpdates();
        emit(RecordingInProgress(
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
        ));
      },
    );
  }

  // ==== STOP ====

  Future<void> _onStopRecording(
      StopRecording event, Emitter<RecordingState> emit) async {
    if (state is! RecordingInProgress && state is! RecordingPaused) {
      emit(const RecordingError('No active recording to stop',
          errorType: RecordingErrorType.state));
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

    final result = await _stopRecordingUseCase.execute(
      waveformData: event.waveformData,
      overrideDuration: currentDuration,
    );

    await result.fold(
      (failure) async => emit(RecordingError(failure.message,
          errorType: RecordingErrorType.recording)),
      (recording) async {
        // Se seek-and-resume è stato usato, concatena base + continuazione
        if (seekBasePath != null) {
          try {
            await _trimmerService.concatenateAudio(
              basePath: seekBasePath,
              appendPath: recording.filePath,
              outputPath: recording.filePath,
              format: recording.format.name.toLowerCase(),
            );
            final baseFile = File(seekBasePath);
            if (await baseFile.exists()) await baseFile.delete();
          } catch (e) {
            print('⚠️ Concatenazione fallita, mantengo solo la continuazione: $e');
          }
        }
        emit(RecordingCompleted(recording: recording));
        _refreshFolderCounts();
      },
    );
  }

  // ==== PAUSE ====

  Future<void> _onPauseRecording(
      PauseRecording event, Emitter<RecordingState> emit) async {
    if (state is! RecordingInProgress) return;

    _stopAmplitudeUpdates();
    _stopDurationUpdates();
    final s = state as RecordingInProgress;

    final result = await _pauseRecordingUseCase.executePause();
    result.fold(
      (failure) => print('❌ Failed to pause: ${failure.message}'),
      (duration) => emit(RecordingPaused(
        filePath: s.filePath,
        folderId: s.folderId,
        folderName: s.folderName,
        format: s.format,
        sampleRate: s.sampleRate,
        bitRate: s.bitRate,
        duration: duration,
        startTime: s.startTime,
      )),
    );
  }

  // ==== RESUME ====

  Future<void> _onResumeRecording(
      ResumeRecording event, Emitter<RecordingState> emit) async {
    if (state is! RecordingPaused) return;

    final s = state as RecordingPaused;

    final result = await _pauseRecordingUseCase.executeResume();
    result.fold(
      (failure) => print('❌ Failed to resume: ${failure.message}'),
      (duration) {
        emit(RecordingInProgress(
          filePath: s.filePath,
          folderId: s.folderId,
          folderName: s.folderName,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: duration,
          amplitude: 0.0,
          startTime: s.startTime,
        ));
        _startAmplitudeUpdates();
        _startDurationUpdates();
      },
    );
  }

  // ==== SEEK-AND-RESUME ====

  Future<void> _onSeekAndResumeRecording(
      SeekAndResumeRecording event, Emitter<RecordingState> emit) async {
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
      (failure) => emit(RecordingError(failure.message,
          errorType: RecordingErrorType.recording)),
      (data) {
        final seekTimeMs = event.seekBarIndex * 50;
        emit(RecordingInProgress(
          filePath: s.filePath,
          folderId: s.folderId,
          folderName: s.folderName,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: Duration(milliseconds: seekTimeMs),
          amplitude: 0.0,
          startTime: s.startTime,
          seekBasePath: data.seekBasePath,
        ));
        _startAmplitudeUpdates();
        _startDurationUpdates();
      },
    );
  }

  // ==== CANCEL ====

  Future<void> _onCancelRecording(
      CancelRecording event, Emitter<RecordingState> emit) async {
    try {
      _stopAmplitudeUpdates();
      _stopDurationUpdates();
      await _audioService.cancelRecording();
      emit(const RecordingCancelled());
    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
  }
}
