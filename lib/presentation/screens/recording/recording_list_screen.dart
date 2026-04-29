// File: lib/presentation/screens/recording/recording_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/utils/app_file_utils.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_recording_repository.dart'
    show IAudioRecordingRepository;
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/dialogs/audio_format_dialog.dart';
import '../../widgets/recording/recording_list_header.dart';
import '../../widgets/common/skeleton_screen.dart';
import '../../../config/dependency_injection.dart';
import 'recording_list_logic.dart';
import 'recording_list_content.dart';
import '../../../core/routing/app_router.dart';
import 'controllers/recording_playback_coordinator.dart';
import 'controllers/recording_playback_view_state.dart';

/// Recording List Screen con singolo motore di playback condiviso
///
/// Features:
/// - Un solo `IAudioPlaybackEngine` condiviso via DI
/// - Pure UI RecordingCards with callbacks
/// - One expanded card at a time
/// - Instant audio playback (like old project)
class RecordingListScreen extends StatefulWidget {
  final FolderEntity folder;

  const RecordingListScreen({super.key, required this.folder});

  @override
  State<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen>
    with RecordingListLogic {
  // Ottieni il coordinator tramite GetIt
  late final RecordingPlaybackCoordinator _playbackCoordinator;
  // Notifier filtrato: si aggiorna SOLO quando cambiano expandedId o activeId.
  // Le card non-attive si iscrivono qui invece che al full state, evitando
  // rebuild ogni ~100ms durante i tick di posizione dell'overdub preview.
  late final ValueNotifier<(String?, String?)> _cardIdsNotifier;
  String? _activePreviewPlaybackId;
  bool _isStoppingPreviewPlayback = false;
  bool _didDispatchPreviewCompletion = false;
  bool _wasPreviewPlaying = false;
  int? _lastSyncedPreviewSeekBarIndex;

  @override
  FolderEntity get folder => widget.folder;

  /// Contatore che si incrementa ad ogni fine registrazione.
  /// Serve come Key per forzare la distruzione del widget Waveform
  /// ed evitare che l'interfaccia ricicli vecchi dati residui.
  int _sessionCounter = 0;

  @override
  void initState() {
    super.initState();
    _playbackCoordinator = GetIt.I<RecordingPlaybackCoordinator>();
    _cardIdsNotifier = ValueNotifier((null, null));
    // Inizializza il coordinator (ora è idempotente)
    unawaited(_playbackCoordinator.initialize());
    // Clean architecture: Single loading point via initializeRecordingList
    initializeRecordingList();
  }

  @override
  void dispose() {
    _playbackCoordinator.state.removeListener(_handlePlaybackStateChanged);
    _playbackCoordinator.state.removeListener(_updateCardIds);
    _cardIdsNotifier.dispose();
    unawaited(
      _playbackCoordinator.dispose(),
    ); // Dispone il coordinator quando la screen muore (corretto per factory)
    super.dispose();
  }

  void _handlePlaybackStateChanged() {
    _syncPausedPreviewPlaybackState();
  }

  void _updateCardIds() {
    final s = _playbackCoordinator.state.value;
    final next = (s.expandedRecordingId, s.activeRecordingId);
    if (_cardIdsNotifier.value != next) {
      _cardIdsNotifier.value = next;
    }
  }

  void _syncPausedPreviewPlaybackState() {
    if (!mounted) return;

    if (_isStoppingPreviewPlayback) return;

    final recordingState = context.read<RecordingBloc>().state;
    final playbackState = _playbackCoordinator.state.value;
    final isPreviewSelected =
        _activePreviewPlaybackId != null &&
        playbackState.expandedRecordingId == _activePreviewPlaybackId;
    final isPreviewPlaying = isPreviewSelected && playbackState.isPlaying;

    if (recordingState is! RecordingPaused) {
      _wasPreviewPlaying = isPreviewPlaying;
      return;
    }

    if (_activePreviewPlaybackId == null || !recordingState.isPlayingPreview) {
      _wasPreviewPlaying = isPreviewPlaying;
      return;
    }

    final hasCompletedNaturally =
        !_isStoppingPreviewPlayback &&
        !_didDispatchPreviewCompletion &&
        _wasPreviewPlaying &&
        isPreviewSelected &&
        !isPreviewPlaying &&
        playbackState.position == Duration.zero &&
        playbackState.status == RecordingPlaybackStatus.ready;

    if (hasCompletedNaturally) {
      _didDispatchPreviewCompletion = true;
      context.read<RecordingBloc>().add(
        StopRecordingPreview(
          isNaturalCompletion: true,
          stoppedSeekBarIndex: _lastPreviewIndex(playbackState.duration),
        ),
      );
      _wasPreviewPlaying = isPreviewPlaying;
      return;
    }

    final previewIndex = _previewSeekIndex(playbackState);
    if (isPreviewSelected &&
        previewIndex != recordingState.seekBarIndex &&
        previewIndex != _lastSyncedPreviewSeekBarIndex) {
      _lastSyncedPreviewSeekBarIndex = previewIndex;
      context.read<RecordingBloc>().add(
        UpdateSeekBarIndex(
          seekBarIndex: previewIndex,
          stopPreview: false,
          isFromPlayback: true,
        ),
      );
    }

    _wasPreviewPlaying = isPreviewPlaying;
  }

  int _previewSeekIndex(RecordingPlaybackViewState playbackState) {
    const tickMs = 100;
    final positionMs = playbackState.position.inMilliseconds;
    final durationMs = playbackState.duration.inMilliseconds;

    if (durationMs > 0 && durationMs - positionMs <= tickMs) {
      return _lastPreviewIndex(playbackState.duration);
    }

    return positionMs ~/ tickMs;
  }

  int _lastPreviewIndex(Duration duration) {
    const tickMs = 100;
    final lastIndex = (duration.inMilliseconds ~/ tickMs) - 1;
    return lastIndex < 0 ? 0 : lastIndex;
  }

  Future<void> _syncPreviewPlaybackWithRecordingState(
    RecordingState recordingState,
  ) async {
    if (recordingState is RecordingPaused || _activePreviewPlaybackId == null) {
      return;
    }

    await _stopPreviewPlaybackEngineOnly(preservePreparedPreview: false);
  }

  Future<void> _stopPreviewPlaybackEngineOnly({
    required bool preservePreparedPreview,
  }) async {
    if (_activePreviewPlaybackId == null) return;

    _isStoppingPreviewPlayback = true;
    try {
      if (preservePreparedPreview) {
        await _playbackCoordinator.pausePlayback();
      } else {
        await _playbackCoordinator.stopPlayback();
      }
    } finally {
      _lastSyncedPreviewSeekBarIndex = null;
      _didDispatchPreviewCompletion = false;
      _wasPreviewPlaying = false;
      if (!preservePreparedPreview) {
        _activePreviewPlaybackId = null;
      }
      _isStoppingPreviewPlayback = false;
    }
  }

  Future<Duration> _resolvePreviewDuration(RecordingPaused state) async {
    var totalDurationMs = state.duration.inMilliseconds;

    if (state.seekBasePath != null) {
      try {
        final baseDuration = await sl<IAudioRecordingRepository>()
            .getAudioDuration(await AppFileUtils.resolve(state.seekBasePath!));
        final baseDurationMs = baseDuration.inMilliseconds;
        final overwriteMs = state.overwriteStartTime?.inMilliseconds ?? 0;
        final endMs = overwriteMs + state.duration.inMilliseconds;
        totalDurationMs = endMs > baseDurationMs ? endMs : baseDurationMs;
      } catch (_) {
        final overwriteMs = state.overwriteStartTime?.inMilliseconds ?? 0;
        totalDurationMs = overwriteMs + state.duration.inMilliseconds;
      }
    }

    return Duration(milliseconds: totalDurationMs);
  }

  @override
  void initializePlaybackStateListener() {
    _playbackCoordinator.state.addListener(_handlePlaybackStateChanged);
    _playbackCoordinator.state.addListener(_updateCardIds);
  }

  @override
  String? get expandedPlaybackRecordingId =>
      _playbackCoordinator.expandedRecordingId;

  @override
  RecordingEntity? getExpandedPlaybackRecording(
    List<RecordingEntity> recordings,
  ) {
    final expandedRecordingId = _playbackCoordinator.expandedRecordingId;
    if (expandedRecordingId == null) return null;

    try {
      return recordings.firstWhere(
        (recording) => recording.id == expandedRecordingId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void resetExpandedPlaybackState() {
    unawaited(_playbackCoordinator.stopPlayback());
  }

  @override
  Future<void> stopExpandedPlayback() => _playbackCoordinator.stopPlayback();

  /// Show dialog to select audio recording format (same as main screen)
  void _showAudioFormatDialog() {
    // Get current format from settings
    AudioFormat currentFormat = AudioFormat.m4a; // Default fallback
    final settingsBloc = context.read<SettingsBloc>();
    final settingsState = settingsBloc.state;

    if (settingsState is SettingsLoaded) {
      currentFormat = settingsState.settings.audioFormat;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioFormatDialog(
          currentFormat: currentFormat,
          onFormatSelected: (AudioFormat format) {
            // Update settings with selected format (synchronized with main screen)
            context.read<SettingsBloc>().add(UpdateAudioFormat(format));
          },
        );
      },
    );
  }

  // Sovrascrivi i metodi di RecordingListLogic per delegare al coordinator
  @override
  Future<void> expandRecording(RecordingEntity recording) async {
    await _playbackCoordinator.expandRecording(recording);
  }

  @override
  Future<void> togglePlayback() async {
    await _playbackCoordinator.togglePlayback();
  }

  @override
  void seekToPosition(double percent) {
    _playbackCoordinator.seekToPercent(percent);
  }

  @override
  void skipBackward() {
    _playbackCoordinator.skipBackward();
  }

  @override
  void skipForward() {
    _playbackCoordinator.skipForward();
  }

  @override
  void playRecordingPreview() {
    unawaited(_playRecordingPreview());
  }

  Future<void> _playRecordingPreview() async {
    final bloc = context.read<RecordingBloc>();
    final recordingState = bloc.state;
    if (recordingState is! RecordingPaused) return;

    final playbackPath =
        await recordingState.resolvedPreviewFilePath ??
        await recordingState.resolvedFilePath;

    final isPreparedPreviewReusable =
        _activePreviewPlaybackId != null &&
        _playbackCoordinator.activeRecordingId == _activePreviewPlaybackId &&
        _playbackCoordinator.expandedRecordingId == _activePreviewPlaybackId;

    if (isPreparedPreviewReusable) {
      final preparedDuration = _playbackCoordinator.state.value.duration;
      final initialPosition = _previewStartPosition(
        recordingState,
        preparedDuration,
      );
      _didDispatchPreviewCompletion = false;
      _lastSyncedPreviewSeekBarIndex = recordingState.seekBarIndex;
      await _playbackCoordinator.seekToPosition(initialPosition);
      await _playbackCoordinator.togglePlayback();
      bloc.add(const PlayRecordingPreview());
      return;
    }

    await _stopPreviewPlaybackEngineOnly(preservePreparedPreview: false);

    final previewDuration = await _resolvePreviewDuration(recordingState);
    final initialPosition = _previewStartPosition(
      recordingState,
      previewDuration,
    );
    final previewRecording = RecordingEntity(
      id: 'preview:${DateTime.now().microsecondsSinceEpoch}',
      name: 'Preview',
      filePath: playbackPath,
      folderId: recordingState.folderId ?? folder.id,
      format: recordingState.format,
      duration: previewDuration,
      fileSize: 0,
      sampleRate: recordingState.sampleRate,
      createdAt: DateTime.now(),
    );

    _activePreviewPlaybackId = previewRecording.id;
    _didDispatchPreviewCompletion = false;
    _lastSyncedPreviewSeekBarIndex = recordingState.seekBarIndex;

    await _playbackCoordinator.expandRecording(previewRecording);
    if (_playbackCoordinator.state.value.status ==
        RecordingPlaybackStatus.error) {
      _activePreviewPlaybackId = null;
      return;
    }
    await _playbackCoordinator.seekToPosition(initialPosition);
    await _playbackCoordinator.togglePlayback();
    bloc.add(const PlayRecordingPreview());
  }

  Duration _previewStartPosition(
    RecordingPaused recordingState,
    Duration previewDuration,
  ) {
    const tickMs = 100;
    final lastIndex = _lastPreviewIndex(previewDuration);
    if (recordingState.seekBarIndex >= lastIndex) {
      return Duration.zero;
    }

    return Duration(milliseconds: recordingState.seekBarIndex * tickMs);
  }

  @override
  void stopRecordingPreview() {
    unawaited(_stopRecordingPreview());
  }

  Future<void> _stopRecordingPreview({bool isNaturalCompletion = false}) async {
    final bloc = context.read<RecordingBloc>();
    final recordingState = bloc.state;
    if (recordingState is! RecordingPaused) return;

    final stoppedSeekBarIndex =
        _playbackCoordinator.state.value.position.inMilliseconds ~/ 100;

    _isStoppingPreviewPlayback = true;
    try {
      await _stopPreviewPlaybackEngineOnly(preservePreparedPreview: true);
    } finally {
      _isStoppingPreviewPlayback = false;
      if (mounted) {
        bloc.add(
          StopRecordingPreview(
            isNaturalCompletion: isNaturalCompletion,
            stoppedSeekBarIndex: isNaturalCompletion
                ? null
                : stoppedSeekBarIndex,
          ),
        );
      }
    }
  }

  @override
  void updateSeekBarIndex(int index) {
    final bloc = context.read<RecordingBloc>();
    final recordingState = bloc.state;
    if (recordingState is! RecordingPaused) return;

    unawaited(_handleSeekBarIndexUpdate(recordingState, index));
  }

  Future<void> _handleSeekBarIndexUpdate(
    RecordingPaused recordingState,
    int index,
  ) async {
    final bloc = context.read<RecordingBloc>();

    if (recordingState.isPlayingPreview) {
      await _stopRecordingPreview();
    }

    if (!mounted) return;
    bloc.add(UpdateSeekBarIndex(seekBarIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RecordingBloc, RecordingState>(
          listener: (context, state) {
            handleRecordingStateChange(state);
            unawaited(_syncPreviewPlaybackWithRecordingState(state));
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8E2DE2), // Main screen purple
                Color(0xFFDA22FF), // Main screen magenta
                Color(0xFFFF4E50), // Main screen coral
              ],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Header - doesn't need to rebuild often
                    _RecordingListHeaderWrapper(
                      folder: widget.folder,
                      onBack: () {
                        context.read<SettingsBloc>().add(
                          const UpdateLastOpenedFolder('main'),
                        );
                        context.goToMain();
                      },
                      onShowFormatDialog: _showAudioFormatDialog,
                      onMoveSelected: moveSelectedRecordings,
                    ),
                    Expanded(child: _buildRecordingsList(context)),
                    // Spazio pari all'altezza del bottom sheet in idle (180px)
                    // così l'ultima card non viene coperta dal bottone record.
                    const SizedBox(height: 180),
                  ],
                ),
              ),
              // Bottom sheet positioned outside SafeArea to reach screen bottom
              if (widget.folder.id != 'recently_deleted')
                _buildRecordingBottomSheet(context),
            ],
          ),
        ),
      ),
    );
  }

  List<RecordingEntity> _extractRecordings(RecordingState state) {
    if (state is RecordingLoaded) return state.recordings;
    if (state is RecordingStopping) return state.recordings;
    if (state is RecordingInProgress) return state.recordings;
    if (state is RecordingPaused) return state.recordings;
    if (state is RecordingStarting) return state.recordings;
    return [];
  }

  /// Build recordings list
  Widget _buildRecordingsList(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      buildWhen: (previous, current) {
        // Non ricostruire durante gli stati di registrazione attiva
        if (current is RecordingInProgress ||
            current is RecordingStarting ||
            current is RecordingPaused) {
          return false;
        }
        if (previous.runtimeType != current.runtimeType) return true;
        if (current is RecordingLoaded) return true;
        return false;
      },
      builder: (context, state) {
        if (state is RecordingLoading) {
          return RecordingListSkeleton(folderName: widget.folder.name);
        }
        if (state is RecordingInitial) return const SizedBox.shrink();
        if (state is RecordingStopping && state.recordings.isEmpty) {
          return const SizedBox.shrink();
        }
        if (state is RecordingError) {
          return Center(
            child: Text(
              'Error: ${state.message}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        final recordings = _extractRecordings(state);
        final isEditMode = state is RecordingLoaded && state.isEditMode;
        final selectedRecordings = state is RecordingLoaded
            ? state.selectedRecordings
            : const <String>[];
        final filteredRecordings = filterRecordings(recordings);

        return RecordingListCardList(
          recordings: filteredRecordings,
          hasAnyRecordings: recordings.isNotEmpty,
          searchQuery: searchQuery,
          onSearchChanged: updateSearchQuery,
          cardIdsNotifier: _cardIdsNotifier,
          playbackStateNotifier: _playbackCoordinator.state,
          currentFolderId: widget.folder.id,
          folderNames: folderNames,
          isEditMode: isEditMode,
          selectedRecordings: selectedRecordings,
          onTap: expandRecording,
          onDelete: deleteRecording,
          onMoveToFolder: moveRecordingToFolder,
          onMoreActions: showMoreActions,
          onRestore: restoreRecording,
          onToggleFavorite: toggleFavoriteRecording,
          onTogglePlayback: togglePlayback,
          onSeek: seekToPosition,
          onSkipBackward: skipBackward,
          onSkipForward: skipForward,
          onSelectionToggle: (id) => context.read<RecordingBloc>().add(
            ToggleRecordingSelection(recordingId: id),
          ),
        );
      },
    );
  }

  /// Build recording bottom sheet
  Widget _buildRecordingBottomSheet(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      buildWhen: (prev, curr) {
        // Per RecordingPaused: ricostruisci solo quando cambiano le proprietà
        // rilevanti per il bottom sheet (preview, seek, durata).
        // Evita rebuild inutili su altri campi (title, format, ecc.)
        if (prev is RecordingPaused && curr is RecordingPaused) {
          return prev.isPlayingPreview != curr.isPlayingPreview ||
              prev.seekBarIndex != curr.seekBarIndex ||
              prev.duration != curr.duration;
        }
        // Negli altri casi ricostruisci sempre (cambio tipo stato, recording in progress, ecc.)
        return true;
      },
      builder: (context, recordingState) {
        final isRecording = recordingState.isRecording;
        final isPaused = recordingState is RecordingPaused;
        final isStarting = recordingState is RecordingStarting;
        final isPlayingPreview =
            recordingState is RecordingPaused &&
            recordingState.isPlayingPreview;
        final currentTitle = recordingState is RecordingInProgress
            ? recordingState.title ?? 'New Recording'
            : recordingState is RecordingPaused
            ? recordingState.title ?? 'New Recording'
            : 'New Recording';
        final elapsed = recordingState.currentDuration ?? Duration.zero;
        final amplitude = recordingState is RecordingInProgress
            ? recordingState.amplitude
            : 0.0;
        final waveformAmplitudeSamples = recordingState is RecordingInProgress
            ? recordingState.waveformAmplitudeSamples
            : recordingState is RecordingPaused
            ? recordingState.waveformAmplitudeSamples
            : const <double>[];
        final waveformAmplitudeSampleCount =
            recordingState is RecordingInProgress
            ? recordingState.waveformAmplitudeSampleCount
            : recordingState is RecordingPaused
            ? recordingState.waveformAmplitudeSampleCount
            : 0;
        final truncatedWaveData = recordingState is RecordingInProgress
            ? recordingState.truncatedWaveData
            : recordingState is RecordingPaused
            ? recordingState.truncatedWaveData
            : recordingState is RecordingStopping
            ? recordingState.truncatedWaveData
            : recordingState is RecordingStarting
            ? recordingState.truncatedWaveData
            : null;
        // Rimosso cast non necessario: final blocSeekBarIndex = recordingState is RecordingPaused ? recordingState.seekBarIndex : null;
        final blocSeekBarIndex = recordingState is RecordingPaused
            ? recordingState.seekBarIndex
            : null;

        final isOverwrite =
            recordingState is RecordingInProgress &&
            recordingState.originalFilePathForOverwrite != null;

        return RecordingBottomSheet(
          title: currentTitle,
          isRecording: isRecording,
          isPaused: isPaused,
          isStarting: isStarting,
          isOverwrite: isOverwrite,
          isPlayingPreview: isPlayingPreview,
          onToggle: () {
            // Incrementa il contatore quando si ferma la registrazione per
            // forzare la distruzione del widget Waveform alla prossima sessione
            final recordingBloc = context.read<RecordingBloc>();
            if (recordingBloc.state.canStopRecording) {
              setState(() {
                _sessionCounter++;
              });
            }
            toggleRecording();
          },
          elapsed: elapsed,
          amplitude: amplitude,
          waveformAmplitudeSamples: waveformAmplitudeSamples,
          waveformAmplitudeSampleCount: waveformAmplitudeSampleCount,
          width: MediaQuery.of(context).size.width,
          truncatedWaveData: truncatedWaveData,
          onTitleChanged: (newTitle) {
            context.read<RecordingBloc>().add(
              UpdateRecordingTitle(title: newTitle),
            );
          },
          onPause: pauseRecording,
          onDone: () {
            // Incrementa il contatore quando si preme Done nel fullscreen
            setState(() {
              _sessionCounter++;
            });
            finishRecording();
          },
          onChat: showTranscriptOptions,
          onResume: resumeRecording,
          onPlayFromPosition: playRecordingPreview,
          onStopPreview: stopRecordingPreview,
          onSeekBarIndexChanged: updateSeekBarIndex,
          blocSeekBarIndex: blocSeekBarIndex,
          onPrepareToOverwrite: (seekBarIndex, waveData) {
            context.read<RecordingBloc>().add(
              StartOverwrite(seekBarIndex: seekBarIndex, waveData: waveData),
            );
          },
          sessionCounter: _sessionCounter,
        );
      },
    );
  }
}

/// Separate header widget to prevent unnecessary rebuilds
class _RecordingListHeaderWrapper extends StatelessWidget {
  final FolderEntity folder;
  final VoidCallback onBack;
  final VoidCallback onShowFormatDialog;
  final VoidCallback onMoveSelected;

  const _RecordingListHeaderWrapper({
    required this.folder,
    required this.onBack,
    required this.onShowFormatDialog,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    return RecordingListHeader(
      folderName: folder.name,
      onBack: onBack,
      onShowFormatDialog: onShowFormatDialog,
      onMoveSelected: onMoveSelected,
    );
  }
}
