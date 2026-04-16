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
          File(pausedState.previewFilePath!).deleteSync();
        } catch (_) {}
      }
    }

    final s = state; // can be RecordingInProgress or RecordingPaused

    // Estrai le variabili necessarie
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

      final part2Path = part2ResultEntity.filePath;
      final finalWavPath =
          "${originalFilePathForOverwrite}_final_${DateTime.now().millisecondsSinceEpoch}.wav";

      final insertionDurationMs = part2ResultEntity.duration.inMilliseconds;

      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: seekBasePath,
          insertionPath: part2Path,
          startTime: overwriteStartTime ?? Duration.zero,
          overwriteDuration: Duration(milliseconds: insertionDurationMs),
          outputPath: finalWavPath,
          format: 'wav',
        );

        // Delete partial files
        try {
          File(seekBasePath).deleteSync();
          File(part2Path).deleteSync();
        } catch (_) {}

        String finalOutputPath = finalWavPath;

        // Se l'utente ha richiesto un formato diverso da WAV, convertiamo
        if (format.fileExtension != '.wav') {
          final convertedPath = await _audioService.convertAudioFile(
            inputPath: finalWavPath,
            outputPath: originalFilePathForOverwrite,
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
              filePath: finalOutputPath,
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
        // usando il nome finale calcolato.
        final oldFile = File(finalOutputPath);
        final directory = oldFile.parent.path;
        final fileExtension = path.extension(finalOutputPath);
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
          finalRecording = recording.copyWith(filePath: newPath);
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

    // Estrai il valore dal Either senza usare closure async dentro fold
    final Duration? duration = result.fold((_) => null, (d) => d);
    if (duration == null) {
      emit(
        RecordingError(result.fold((f) => f.message, (_) => 'Unknown error')),
      );
      return;
    }

    // Crea uno stato Paused temporaneo per passarlo al helper
    final pausedState = RecordingPaused(
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
      previewFilePath: null,
    );

    // Assembla il preview una volta al pause e lo riutilizza per i playback successivi
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

    // Pulisci il preview se esiste (non lo useremo più fino al prossimo pause)
    if (s.previewFilePath != null) {
      try {
        File(s.previewFilePath!).deleteSync();
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

  /// Resume con auto-stop del preview se attivo.
  /// Se la seek bar è nel mezzo (non alla fine), inizia un overdub.
  Future<void> _onResumeWithAutoStop(
    ResumeWithAutoStop event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    // 1. Se il preview è attivo, fermalo
    if (s.isPlayingPreview) {
      debugPrint('⏹ Auto-stop preview before resume');
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      await _audioService.stopPlaying();

      // Pulisci file temporanei di preview
      try {
        final dir = File(s.filePath).parent;
        final files = dir.listSync();
        for (var f in files) {
          if (f.path.contains('_preview_') && f.path.endsWith('.wav')) {
            f.deleteSync();
          }
        }
      } catch (_) {}

      // Emetti stato senza isPlayingPreview
      emit(s.copyWith(isPlayingPreview: false));
    }

    // 2. Calcola se siamo alla fine della registrazione
    int totalDurationMs = s.duration.inMilliseconds;
    if (s.seekBasePath != null) {
      try {
        final baseDuration = await _audioService.getAudioDuration(
          s.seekBasePath!,
        );
        final baseDurationMs = baseDuration.inMilliseconds;
        final overwriteMs = s.overwriteStartTime?.inMilliseconds ?? 0;
        final endMs = overwriteMs + s.duration.inMilliseconds;
        totalDurationMs = endMs > baseDurationMs ? endMs : baseDurationMs;
      } catch (_) {
        totalDurationMs =
            (s.overwriteStartTime?.inMilliseconds ?? 0) +
            s.duration.inMilliseconds;
      }
    }
    // Tolleranza di 2 barre (200ms) per la fine
    final totalBars = (totalDurationMs / 100).ceil();
    final isAtEnd = event.seekBarIndex >= totalBars - 2;

    debugPrint(
      '▶️ ResumeWithAutoStop: seekBar=${event.seekBarIndex}, totalBars=$totalBars, isAtEnd=$isAtEnd',
    );
    debugPrint('▶️ ResumeWithAutoStop: State seekBarIndex=${s.seekBarIndex}');

    // 3. Se siamo alla fine, resume; altrimenti, inizia overdub
    if (isAtEnd) {
      if (s.seekBasePath == null) {
        // Case A: nessun overdub precedente — resume semplice del motore
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
        // Case B: c'è un overdub precedente — consolida e riparti dalla fine
        await _continueFromEndAfterOverdub(event, emit, s);
      }
    } else {
      // Inizia overdub (seek-and-resume)
      add(
        StartOverwrite(
          seekBarIndex: event.seekBarIndex,
          waveData: event.waveData,
        ),
      );
    }
  }

  /// Consolida il segmento overdub nel base file, poi avvia una nuova registrazione
  /// dalla fine del file consolidato. Usato quando l'utente vuole continuare
  /// a registrare dalla fine dopo aver fatto un overdub nel mezzo.
  Future<void> _continueFromEndAfterOverdub(
    ResumeWithAutoStop event,
    Emitter<RecordingState> emit,
    RecordingPaused s,
  ) async {
    emit(const RecordingStarting());

    // 1. Stoppa/finalizza il segmento overdub corrente
    final overdubEntity = await _audioService.stopRecording(raw: true);

    final String consolidatedPath;
    final Duration consolidatedDuration;

    if (overdubEntity != null && overdubEntity.filePath.isNotEmpty) {
      // 2a. Applica l'overdub al base file per ottenere il file consolidato
      final tempPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_merged_${DateTime.now().millisecondsSinceEpoch}.wav";

      try {
        await _trimmerService.overwriteAudioSegment(
          originalPath: s.seekBasePath!,
          insertionPath: overdubEntity.filePath,
          startTime: s.overwriteStartTime ?? Duration.zero,
          overwriteDuration: overdubEntity.duration,
          outputPath: tempPath,
          format: 'wav',
        );

        // Elimina i frammenti temporanei ora che sono stati uniti
        try {
          File(s.seekBasePath!).deleteSync();
          File(overdubEntity.filePath).deleteSync();
        } catch (_) {}

        consolidatedPath = tempPath;
        consolidatedDuration = await _audioService.getAudioDuration(tempPath);
      } catch (e) {
        emit(RecordingError('Errore consolidamento overdub: $e'));
        return;
      }
    } else {
      // 2b. Nessun segmento da consolidare — usa il seekBasePath direttamente
      consolidatedPath = s.seekBasePath!;
      consolidatedDuration = await _audioService.getAudioDuration(
        consolidatedPath,
      );
    }

    // 3. Avvia una nuova registrazione dalla fine del file consolidato
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

    // 4. Emetti RecordingInProgress con:
    //    - truncatedWaveData = waveform troncata alla durata reale del file consolidato.
    //      event.waveData può contenere barre "in eccesso" se l'overdub precedente aveva
    //      sbordato visivamente oltre la fine dell'audio fisico. Tronchiamo al numero
    //      esatto di barre del file consolidato così UI e motore audio parlano la stessa lingua.
    //    - overwriteStartTime = fine del file consolidato → _onStopRecording userà
    //      overwriteAudioSegment che rileva isSimpleConcatenation e concatena in append.
    final int consolidatedBars = (consolidatedDuration.inMilliseconds / 100)
        .floor();
    final List<double> alignedWaveData = event.waveData
        .take(consolidatedBars)
        .toList();

    emit(
      RecordingInProgress(
        filePath: newPath,
        folderId: s.folderId,
        folderName: s.folderName,
        format: s.format,
        sampleRate: s.sampleRate,
        bitRate: s.bitRate,
        duration: Duration.zero,
        amplitude: 0.0,
        startTime: DateTime.now(),
        title: s.title,
        seekBasePath: consolidatedPath,
        overwriteStartTime: consolidatedDuration,
        originalFilePathForOverwrite:
            s.originalFilePathForOverwrite ?? s.filePath,
        truncatedWaveData:
            alignedWaveData, // allineato all'audio fisico consolidato
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

    // Pulisci il preview pre-assemblato dal pause precedente
    if (s.previewFilePath != null) {
      try {
        File(s.previewFilePath!).deleteSync();
      } catch (_) {}
    }

    // We want to OVERWRITE the current recording from the seek point.
    // 1. Dobbiamo fermare l'engine nel caso fosse attivo
    final baseRecordingEntity = await _audioService.stopRecording(raw: true);

    final int rawDurationMs = event.seekBarIndex * 100;
    final durationMs = rawDurationMs < 100 ? 100 : rawDurationMs;
    debugPrint(
      '✏️ StartOverwrite: event.seekBarIndex=${event.seekBarIndex}, overwriteStartTimeMs=$durationMs',
    );

    String pathToOverwrite = s.seekBasePath ?? s.filePath;

    // Se stavamo già registrando una sovrascrittura precedente (baseWavPath esiste),
    // applichiamo PRIMA quella sovrascrittura, e otteniamo il nuovo base
    if (baseRecordingEntity != null &&
        baseRecordingEntity.filePath.isNotEmpty &&
        s.seekBasePath != null) {
      final baseWavPath = baseRecordingEntity.filePath;
      final tempConcatPath =
          "${s.originalFilePathForOverwrite ?? s.filePath}_temp_concat_${DateTime.now().millisecondsSinceEpoch}.wav";

      final insertionDurationMs = baseRecordingEntity.duration.inMilliseconds;

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
    try {
      _stopAmplitudeUpdates();
      _stopDurationUpdates();
      _previewPositionSubscription?.cancel();
      _previewPositionSubscription = null;
      _previewCompletionSubscription?.cancel();
      _previewCompletionSubscription = null;
      if (await _audioService.isPlaying()) await _audioService.stopPlaying();

      // Pulisci il file preview se esiste
      if (state is RecordingPaused) {
        final pausedState = state as RecordingPaused;
        if (pausedState.previewFilePath != null) {
          try {
            File(pausedState.previewFilePath!).deleteSync();
          } catch (_) {}
        }
      }

      await _audioService.cancelRecording();
      emit(const RecordingCancelled());
    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
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
    if (state is! RecordingPaused) return;
    final s = state as RecordingPaused;

    // Ignora eventi provenienti dal playback se il preview non è più attivo.
    // Previene che eventi già in coda sovrascrivano il seekBarIndex finale
    // calcolato da _onStopRecordingPreview dopo la fine naturale del playback.
    if (event.isFromPlayback && !s.isPlayingPreview) return;

    // Clamp dell'indice all'ultima barra disponibile
    int totalDurationMs = s.duration.inMilliseconds;
    if (s.seekBasePath != null) {
      try {
        final baseDuration = await _audioService.getAudioDuration(
          s.seekBasePath!,
        );
        final baseDurationMs = baseDuration.inMilliseconds;
        final overwriteMs = s.overwriteStartTime?.inMilliseconds ?? 0;
        final endMs = overwriteMs + s.duration.inMilliseconds;
        totalDurationMs = endMs > baseDurationMs ? endMs : baseDurationMs;
      } catch (_) {
        totalDurationMs =
            (s.overwriteStartTime?.inMilliseconds ?? 0) +
            s.duration.inMilliseconds;
      }
    }

    final maxIndex = (totalDurationMs ~/ 100);
    final clampedIndex = event.seekBarIndex.clamp(0, maxIndex);

    if (s.seekBarIndex == clampedIndex) return;
    debugPrint('📍 SeekBar → bar $clampedIndex (${clampedIndex * 100}ms)');

    // Se il playback preview è attivo:
    // Se stopPreview è true (es. drag da UI), fermiamo il preview.
    // Altrimenti (es. pulsanti rewind/forward), facciamo seek senza fermare.
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

    // Usa il preview pre-assemblato al pause, o il file diretto se non in overdub
    String playbackPath = s.previewFilePath ?? s.filePath;

    final initialPosition = seekMs > 0 ? Duration(milliseconds: seekMs) : null;
    final started = await _audioService.startPlaying(
      playbackPath,
      initialPosition: initialPosition,
    );
    if (!started) {
      debugPrint(
        '❌ PlayRecordingPreview: impossibile avviare il playback di $playbackPath',
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
              add(
                UpdateSeekBarIndex(
                  seekBarIndex: newIndex,
                  stopPreview: false,
                  isFromPlayback: true,
                ),
              );
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

    Duration? finalDuration;
    int? finalSeekBarIndex;

    // Pulizia di eventuali file temporanei di preview e calcolo durata finale
    try {
      final dir = File(s.filePath).parent;
      final files = dir.listSync();
      for (var f in files) {
        if (f.path.contains('_preview_') && f.path.endsWith('.wav')) {
          finalDuration = await _audioService.getAudioDuration(f.path);
          f.deleteSync();
        }
      }
    } catch (_) {}

    // Fallback: nessun file di preview trovato (es. playback diretto su filePath).
    // Calcola la durata totale dall'audio base + parte registrata.
    if (finalDuration == null && event.isNaturalCompletion) {
      int totalDurationMs = s.duration.inMilliseconds;
      if (s.seekBasePath != null) {
        try {
          final baseDuration = await _audioService.getAudioDuration(
            s.seekBasePath!,
          );
          final baseDurationMs = baseDuration.inMilliseconds;
          final overwriteMs = s.overwriteStartTime?.inMilliseconds ?? 0;
          final endMs = overwriteMs + s.duration.inMilliseconds;
          totalDurationMs = endMs > baseDurationMs ? endMs : baseDurationMs;
        } catch (_) {
          totalDurationMs =
              (s.overwriteStartTime?.inMilliseconds ?? 0) +
              s.duration.inMilliseconds;
        }
      }
      // NON aggiornare finalDuration: s.duration deve rimanere la durata del
      // segmento registrato. Impostarlo a totalDurationMs (= overwriteMs + s.duration)
      // causerebbe un accumulo a ogni play (+overwriteMs ogni volta).
    }

    emit(
      s.copyWith(
        isPlayingPreview: false,
        duration: finalDuration ?? s.duration,
      ),
    );
  }

  /// Assembla il file di preview dal base file e dal segmento registrato.
  /// Ritorna il path al file preview, o null se non in modalità overdub.
  Future<String?> _assemblePreviewFile(RecordingPaused state) async {
    if (state.seekBasePath == null ||
        state.originalFilePathForOverwrite == null) {
      return null;
    }

    final tempPreviewPath =
        "${state.originalFilePathForOverwrite}_preview_${DateTime.now().millisecondsSinceEpoch}.wav";

    try {
      // Ottieni la durata reale del file base
      final baseDuration = await _audioService.getAudioDuration(
        state.seekBasePath!,
      );
      final baseDurationMs = baseDuration.inMilliseconds;

      // È una semplice concatenazione se stiamo sovrascrivendo dalla fine del file base
      final isSimpleConcatenation =
          state.overwriteStartTime?.inMilliseconds == baseDurationMs;

      if (isSimpleConcatenation) {
        // Caso 1: Concatenazione semplice (pause/resume senza seek)
        debugPrint(
          '🔀 Preview assembly: concatenazione semplice (base: ${baseDurationMs}ms + part2: ${state.duration.inMilliseconds}ms)',
        );
        await _trimmerService.concatenateAudio(
          basePath: state.seekBasePath!,
          appendPath: state.filePath,
          outputPath: tempPreviewPath,
          format: 'wav',
        );
      } else {
        // Caso 2: Overwrite con seek (inserimento nel mezzo)
        debugPrint(
          '✏️ Preview assembly: overwrite da ${state.overwriteStartTime?.inMilliseconds ?? 0}ms, durata insert: ${state.duration.inMilliseconds}ms',
        );

        await _trimmerService.overwriteAudioSegment(
          originalPath: state.seekBasePath!,
          insertionPath: state.filePath,
          startTime: state.overwriteStartTime ?? Duration.zero,
          overwriteDuration: state.duration,
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
}
