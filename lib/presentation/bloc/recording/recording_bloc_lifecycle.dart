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
    if (state is! RecordingInProgress) return;
    final s = state as RecordingInProgress;

    emit(const RecordingStopping());
    _stopAmplitudeUpdates();
    _stopDurationUpdates();

    // Logica di Seek-and-Resume (se c'è un base path tagliato)
    if (s.seekBasePath != null && s.originalFilePathForOverwrite != null) {
      final part2ResultEntity = await _audioService.stopRecording(raw: true);

      if (part2ResultEntity == null || part2ResultEntity.filePath.isEmpty) {
        emit(const RecordingError('Failed to stop part 2 recording'));
        return;
      }

      final part2Path = part2ResultEntity.filePath;
      final finalWavPath =
          "${s.originalFilePathForOverwrite!}_final_${DateTime.now().millisecondsSinceEpoch}.wav";

      final insertionDurationMs = event.waveformData != null
          ? (event.waveformData!.length - (s.truncatedWaveData?.length ?? 0)) *
                100
          : s.duration.inMilliseconds;

      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: s.seekBasePath!,
          insertionPath: part2Path,
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: Duration(milliseconds: insertionDurationMs),
          outputPath: finalWavPath,
          format: 'wav',
        );

        // Delete partial files
        try {
          File(s.seekBasePath!).deleteSync();
          File(part2Path).deleteSync();
        } catch (_) {}

        String finalOutputPath = finalWavPath;

        // Se l'utente ha richiesto un formato diverso da WAV, convertiamo
        if (s.format.fileExtension != '.wav') {
          final convertedPath = await _audioService.convertAudioFile(
            inputPath: finalWavPath,
            outputPath: s.originalFilePathForOverwrite!,
            targetFormat: s.format,
            targetSampleRate: s.sampleRate,
            targetBitRate: s.bitRate,
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

        // Creiamo la RecordingEntity finale nel DB
        final duration = await _audioService.getAudioDuration(finalOutputPath);
        final file = File(finalOutputPath);
        final fileSize = await file.length();

        // Costruiamo il nome
        String locationName = 'Recording';
        try {
          locationName = await _locationRepository
              .getRecordingLocationName()
              .timeout(const Duration(seconds: 3));
        } catch (_) {}

        final existingRecordings = await _recordingRepository
            .getRecordingsByFolder(s.folderId ?? 'all_recordings');
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
              filePath: finalOutputPath,
              folderId: s.folderId ?? 'all_recordings',
              format: s.format,
              duration: duration,
              fileSize: fileSize,
              sampleRate: s.sampleRate,
            ).copyWith(
              waveformData: event.waveformData ?? s.truncatedWaveData,
              locationName: locationName,
            );

        final saved = await _recordingRepository.createRecording(recording);
        emit(RecordingCompleted(recording: saved));
        _refreshFolderCounts();
      } catch (e) {
        emit(RecordingError('Seek-and-Resume finalization failed: $e'));
      }
    } else {
      // Logica di Stop Normale
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

    // Pausa normale (anche se c'è seekBasePath, mettiamo in pausa solo part2)
    final result = await _pauseRecordingUseCase.executePause();
    result.fold(
      (failure) => emit(RecordingError(failure.message)),
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
          seekBasePath: s.seekBasePath,
          originalFilePathForOverwrite: s.originalFilePathForOverwrite,
          overwriteStartTime: s.overwriteStartTime,
          truncatedWaveData: s.truncatedWaveData,
        ),
      ),
    );
  }

  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
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

  Future<void> _onStartOverwrite(
    StartOverwrite event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;
    emit(const RecordingStarting());

    // We want to OVERWRITE the current recording from the seek point.
    // 1. Dobbiamo fermare l'engine nel caso fosse attivo
    final baseRecordingEntity = await _audioService.stopRecording(raw: true);

    final int rawDurationMs = event.seekBarIndex * 100;
    final durationMs = rawDurationMs < 100 ? 100 : rawDurationMs;

    String pathToOverwrite = s.seekBasePath ?? s.filePath;

    // Se stavamo già registrando una sovrascrittura precedente (baseWavPath esiste),
    // applichiamo PRIMA quella sovrascrittura, e otteniamo il nuovo base
    if (baseRecordingEntity != null &&
        baseRecordingEntity.filePath.isNotEmpty &&
        s.seekBasePath != null) {
      final baseWavPath = baseRecordingEntity.filePath;
      final tempConcatPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_temp_concat_${DateTime.now().millisecondsSinceEpoch}.wav";

      final insertionDurationMs = (s.truncatedWaveData != null)
          ? (event.waveData.length - s.truncatedWaveData!.length) * 100
          : s.duration.inMilliseconds;

      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: s.seekBasePath!,
          insertionPath: baseWavPath,
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: Duration(milliseconds: insertionDurationMs),
          outputPath: tempConcatPath,
          format: 'wav',
        );
        pathToOverwrite = tempConcatPath;

        // Cancelliamo i frammenti che abbiamo appena unito
        try {
          File(s.seekBasePath!).deleteSync();
          File(baseWavPath).deleteSync();
        } catch (_) {}
      } catch (e) {
        emit(RecordingError('Failed to apply previous overwrite for seek: $e'));
        return;
      }
    }

    // Now start a NEW recording that acts as the insertion
    final newRecordingPath =
        "${s.filePath}.part2_${DateTime.now().millisecondsSinceEpoch}.wav";
    final started = await _audioService.startRecording(
      filePath: newRecordingPath,
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
          filePath: newRecordingPath,
          folderId: s.folderId,
          folderName: s.folderName,
          format: s.format,
          sampleRate: s.sampleRate,
          bitRate: s.bitRate,
          duration: Duration.zero,
          amplitude: 0.0,
          startTime: DateTime.now(),
          title: s.title,
          seekBasePath:
              pathToOverwrite, // Store the full base to overwrite on Stop/Pause
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

  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingState> emit,
  ) async {
    // ... implementazione ...
  }

  void _deleteInsertionRecording(RecordingEntity insertion) {
    _recordingRepository
        .deleteRecording(insertion.id)
        .then((_) async {
          try {
            final file = File(insertion.filePath);
            if (await file.exists()) await file.delete();
            debugPrint('🧹 Insertion file eliminato: ${insertion.filePath}');
          } catch (e) {
            debugPrint('⚠️ Errore eliminazione insertion file: $e');
          }
        })
        .catchError((e) {
          debugPrint('⚠️ Errore eliminazione insertion dal DB: $e');
        });
  }

  Future<void> _onUpdateSeekBarIndex(
    UpdateSeekBarIndex event,
    Emitter<RecordingState> emit,
  ) async {
    // ... implementazione ...
  }
  Future<void> _onPlayRecordingPreview(
    PlayRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    // ... implementazione ...
  }
  Future<void> _onStopRecordingPreview(
    StopRecordingPreview event,
    Emitter<RecordingState> emit,
  ) async {
    // ... implementazione ...
  }
}
