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
import '../../widgets/recording/recording_card/recording_card.dart';
import '../../widgets/recording/recording_list_header.dart';
import '../../widgets/recording/pull_to_search_list.dart';
import '../../widgets/common/skeleton_screen.dart';
import '../../../config/dependency_injection.dart';
// import '../../../services/audio/audio_player_service.dart'; // Rimosso o commentato
import 'recording_list_logic.dart';
import '../../../core/routing/app_router.dart';
// import '../../../core/utils/performance_logger.dart'; // Rimosso: import non utilizzato

// Nuovi import per il playback
import 'controllers/recording_playback_coordinator.dart';
import 'controllers/recording_playback_view_state.dart';
import '../playback/playback_screen.dart';

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

    final previewIndex = playbackState.position.inMilliseconds ~/ 100;
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
        const StopRecordingPreview(isNaturalCompletion: true),
      );
    }

    _wasPreviewPlaying = isPreviewPlaying;
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
    final initialPosition = Duration(
      milliseconds: recordingState.seekBarIndex * 100,
    );

    final isPreparedPreviewReusable =
        _activePreviewPlaybackId != null &&
        _playbackCoordinator.activeRecordingId == _activePreviewPlaybackId &&
        _playbackCoordinator.expandedRecordingId == _activePreviewPlaybackId;

    if (isPreparedPreviewReusable) {
      _didDispatchPreviewCompletion = false;
      _lastSyncedPreviewSeekBarIndex = recordingState.seekBarIndex;
      await _playbackCoordinator.seekToPosition(initialPosition);
      await _playbackCoordinator.togglePlayback();
      bloc.add(const PlayRecordingPreview());
      return;
    }

    await _stopPreviewPlaybackEngineOnly(preservePreparedPreview: false);

    final previewDuration = await _resolvePreviewDuration(recordingState);
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
            stoppedSeekBarIndex: isNaturalCompletion ? null : stoppedSeekBarIndex,
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

    debugPrint(
      '🎯 UI -> BLoC UpdateSeekBarIndex currentStateIndex=${recordingState.seekBarIndex} requested=$index isPlayingPreview=${recordingState.isPlayingPreview}',
    );

    if (recordingState.isPlayingPreview) {
      await _stopRecordingPreview();
    }

    if (!mounted) return;
    bloc.add(UpdateSeekBarIndex(seekBarIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🏗️ VERBOSE: RecordingListScreen build() called for folder: ${widget.folder.name}',
    );
    // PerformanceLogger.logRebuild('RecordingListScreen'); // Commentato o rimosso se PerformanceLogger non serve più
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
                        print(
                          '📁 RecordingListScreen: User tapped back button - saving main folder state with pool',
                        );
                        context.read<SettingsBloc>().add(
                          const UpdateLastOpenedFolder('main'),
                        );
                        context.goToMain();
                        print(
                          '📁 RecordingListScreen: Navigation to main completed',
                        );
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

  /// Build recordings list
  Widget _buildRecordingsList(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      buildWhen: (previous, current) {
        // Non ricostruire durante gli stati di registrazione: la lista rimane
        // visibile sotto il bottom sheet con le registrazioni precedenti.
        if (current is RecordingInProgress ||
            current is RecordingStarting ||
            current is RecordingPaused) {
          print(
            '🔍 BUILD_WHEN: Recording state (${current.runtimeType}) - skipping rebuild, keeping previous list',
          );
          return false;
        }

        // Always rebuild when state type changes
        if (previous.runtimeType != current.runtimeType) {
          print(
            '🔍 BUILD_WHEN: State type changed: ${previous.runtimeType} → ${current.runtimeType}',
          );
          return true;
        }

        // Always rebuild for RecordingLoaded states to ensure UI reflects all changes
        // This prevents issues with list equality comparison not detecting entity changes
        if (current is RecordingLoaded) {
          print(
            '🔍 BUILD_WHEN: RecordingLoaded state - forcing rebuild to ensure UI sync',
          );

          // Debug favorite status changes
          if (previous is RecordingLoaded) {
            print('🔍 DEBUG: Comparing RecordingLoaded states...');
            print(
              '🔍 DEBUG: Previous recordings count: ${previous.recordings.length}',
            );
            print(
              '🔍 DEBUG: Current recordings count: ${current.recordings.length}',
            );

            // Check for favorite status changes
            for (
              int i = 0;
              i < current.recordings.length && i < previous.recordings.length;
              i++
            ) {
              final prev = previous.recordings[i];
              final curr = current.recordings[i];
              if (prev.id == curr.id && prev.isFavorite != curr.isFavorite) {
                print(
                  '🔍 DEBUG: Favorite status changed for ${curr.name}: ${prev.isFavorite} → ${curr.isFavorite}',
                );
              }
            }
          }

          return true;
        }

        print('🔍 BUILD_WHEN: No rebuild needed for ${current.runtimeType}');
        return false;
      },
      builder: (context, state) {
        print(
          '🔍 BUILDER: RecordingListScreen builder called with state: ${state.runtimeType}',
        );

        if (state is RecordingLoaded) {
          print(
            '🔍 BUILDER: RecordingLoaded with ${state.recordings.length} recordings',
          );
          // Debug favorite statuses in current build
          for (final recording in state.recordings) {
            print(
              '🔍 BUILDER: Recording ${recording.name} - favorite: ${recording.isFavorite}',
            );
          }
        }

        // PerformanceLogger.logRebuild('_buildRecordingsList'); // Commentato o rimosso se PerformanceLogger non serve più

        if ((state is RecordingLoaded && state.recordings.isNotEmpty) ||
            (state is RecordingStopping && state.recordings.isNotEmpty) ||
            (state is RecordingInProgress && state.recordings.isNotEmpty) ||
            (state is RecordingPaused && state.recordings.isNotEmpty) ||
            (state is RecordingStarting && state.recordings.isNotEmpty)) {
          print(
              '🚀 FAST PATH: Showing content immediately for ${state.runtimeType}');
          final List<RecordingEntity> recordings;
          if (state is RecordingLoaded) {
            recordings = state.recordings;
          } else if (state is RecordingStopping) {
            recordings = state.recordings;
          } else if (state is RecordingInProgress) {
            recordings = state.recordings;
          } else if (state is RecordingPaused) {
            recordings = state.recordings;
          } else if (state is RecordingStarting) {
            recordings = state.recordings;
          } else {
            recordings = [];
          }

          final filteredRecordings = filterRecordings(recordings);
          return _buildRecordingContent(filteredRecordings, state);
        }

        if (state is RecordingLoading) {
          print('🟡 MINIMAL: Brief loading state, showing minimal skeleton');
          return RecordingListSkeleton(folderName: widget.folder.name);
        }

        if (state is RecordingInitial) {
          print(
            '⚠️ UNEXPECTED: RecordingInitial state reached - should be bypassed by immediate loading',
          );
          return const SizedBox.shrink();
        }

        if (state is RecordingLoaded) {
          print(
            '🟢 VERBOSE: Returning RecordingLoaded content with ${state.recordings.length} recordings',
          );
          final filteredRecordings = filterRecordings(state.recordings);

          if (state.recordings.isEmpty) {
            final recordingBloc = context.read<RecordingBloc>();
            final currentState = recordingBloc.state;
            if (currentState.isRecording) {
              return const SizedBox.shrink(); // Hide the message when recording
            }

            return const Center(
              child: Text(
                'No recordings yet',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          return PullToSearchList(
            itemCount: filteredRecordings.length,
            searchQuery: searchQuery,
            onSearchChanged: updateSearchQuery,
            emptyState: searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recordings found for "$searchQuery"',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              final recording = filteredRecordings[index];
              return ValueListenableBuilder<(String?, String?)>(
                valueListenable: _cardIdsNotifier,
                builder: (context, ids, _) {
                  final isExpanded = ids.$1 == recording.id;
                  final isActiveRecording = ids.$2 == recording.id;
                  if (!isExpanded && !isActiveRecording) {
                    return RecordingCard(
                      recording: recording,
                      isExpanded: false,
                      onTap: () => expandRecording(recording),
                      onShowWaveform: () {
                        final nav = Navigator.of(this.context);
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => PlaybackScreen(recording: recording),
                          ),
                        );
                      },
                      onDelete: () => deleteRecording(recording),
                      onMoveToFolder: () => moveRecordingToFolder(recording),
                      onMoreActions: () => showMoreActions(recording),
                      onRestore: () => restoreRecording(recording),
                      onToggleFavorite: () => toggleFavoriteRecording(recording),
                      isPlaying: false,
                      isLoading: false,
                      currentPosition: Duration.zero,
                      actualDuration: null,
                      onPlayPause: togglePlayback,
                      onSeek: seekToPosition,
                      onSkipBackward: skipBackward,
                      onSkipForward: skipForward,
                      currentFolderId: widget.folder.id,
                      folderNames: folderNames,
                      isEditMode: state.isEditMode,
                      isSelected: state.selectedRecordings.contains(recording.id),
                      onSelectionToggle: () => context.read<RecordingBloc>().add(
                        ToggleRecordingSelection(recordingId: recording.id),
                      ),
                    );
                  }
                  return ValueListenableBuilder<RecordingPlaybackViewState>(
                    valueListenable: _playbackCoordinator.state,
                    builder: (context, playbackState, _) {
                      return RecordingCard(
                        recording: recording,
                        isExpanded: isExpanded,
                        onTap: () => expandRecording(recording),
                        onShowWaveform: () {
                          final nav = Navigator.of(this.context);
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => PlaybackScreen(recording: recording),
                            ),
                          );
                        },
                        onDelete: () => deleteRecording(recording),
                        onMoveToFolder: () => moveRecordingToFolder(recording),
                        onMoreActions: () => showMoreActions(recording),
                        onRestore: () => restoreRecording(recording),
                        onToggleFavorite: () => toggleFavoriteRecording(recording),
                        isPlaying: isActiveRecording ? playbackState.isPlaying : false,
                        isLoading: isActiveRecording ? playbackState.isLoading : false,
                        currentPosition: isActiveRecording ? playbackState.position : Duration.zero,
                        actualDuration: isActiveRecording ? playbackState.duration : null,
                        onPlayPause: togglePlayback,
                        onSeek: seekToPosition,
                        onSkipBackward: skipBackward,
                        onSkipForward: skipForward,
                        currentFolderId: widget.folder.id,
                        folderNames: folderNames,
                        isEditMode: state.isEditMode,
                        isSelected: state.selectedRecordings.contains(recording.id),
                        onSelectionToggle: () => context.read<RecordingBloc>().add(
                          ToggleRecordingSelection(recordingId: recording.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
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

        // Gestisce lo stato intermedio di arresto della registrazione.
        // Invece di mostrare uno scheletro (fallback), che causa un flicker visivo,
        // si mostra un contenitore vuoto. La UI si aggiornerà correttamente
        // allo stato successivo (RecordingLoaded) senza un caricamento invasivo.
        if (state is RecordingStopping) {
          return const SizedBox.shrink();
        }

        print('🔴 VERBOSE: FALLBACK - Unhandled state: ${state.runtimeType}');
        print('🔴 VERBOSE: State details: $state');
        print('🔴 VERBOSE: Returning fallback RecordingListSkeleton');
        return RecordingListSkeleton(folderName: widget.folder.name);
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

        debugPrint(
          '🎨 BottomSheet Builder - isPlayingPreview: $isPlayingPreview, blocSeekBarIndex: $blocSeekBarIndex, isPaused: $isPaused',
        );

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

  /// Extract recording content builder to reuse in fast path
  Widget _buildRecordingContent(
    List<RecordingEntity> filteredRecordings,
    RecordingState state,
  ) {
    final List<RecordingEntity> allRecordings;
    final bool isEditMode;
    final List<String> selectedRecordings;

    if (state is RecordingLoaded) {
      allRecordings = state.recordings;
      isEditMode = state.isEditMode;
      selectedRecordings = state.selectedRecordings.toList();
    } else if (state is RecordingStopping) {
      allRecordings = state.recordings;
      isEditMode = false;
      selectedRecordings = [];
    } else if (state is RecordingInProgress) {
      allRecordings = state.recordings;
      isEditMode = false;
      selectedRecordings = [];
    } else if (state is RecordingPaused) {
      allRecordings = state.recordings;
      isEditMode = false;
      selectedRecordings = [];
    } else if (state is RecordingStarting) {
      allRecordings = state.recordings;
      isEditMode = false;
      selectedRecordings = [];
    } else {
      // This case should not be reached given the builder logic
      return const SizedBox.shrink();
    }

    if (allRecordings.isEmpty) {
      final recordingBloc = context.read<RecordingBloc>();
      final currentState = recordingBloc.state;
      if (currentState.isRecording) {
        return const SizedBox.shrink(); // Hide the message when recording
      }

      return const Center(
        child: Text(
          'No recordings yet',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return PullToSearchList(
      itemCount: filteredRecordings.length,
      searchQuery: searchQuery,
      onSearchChanged: updateSearchQuery,
      emptyState: searchQuery.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings found for "$searchQuery"',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : null,
      itemBuilder: (context, index) {
        final recording = filteredRecordings[index];
        return ValueListenableBuilder<(String?, String?)>(
          valueListenable: _cardIdsNotifier,
          builder: (context, ids, _) {
            final isExpanded = ids.$1 == recording.id;
            final isActiveRecording = ids.$2 == recording.id;
            if (!isExpanded && !isActiveRecording) {
              return RecordingCard(
                recording: recording,
                isExpanded: false,
                onTap: () => expandRecording(recording),
                onShowWaveform: () {
                  final nav = Navigator.of(this.context);
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => PlaybackScreen(recording: recording),
                    ),
                  );
                },
                onDelete: () => deleteRecording(recording),
                onMoveToFolder: () => moveRecordingToFolder(recording),
                onMoreActions: () => showMoreActions(recording),
                onRestore: () => restoreRecording(recording),
                onToggleFavorite: () => toggleFavoriteRecording(recording),
                isPlaying: false,
                isLoading: false,
                currentPosition: Duration.zero,
                actualDuration: null,
                onPlayPause: togglePlayback,
                onSeek: seekToPosition,
                onSkipBackward: skipBackward,
                onSkipForward: skipForward,
                currentFolderId: widget.folder.id,
                folderNames: folderNames,
                isEditMode: isEditMode,
                isSelected: selectedRecordings.contains(recording.id),
                onSelectionToggle: () => context.read<RecordingBloc>().add(
                  ToggleRecordingSelection(recordingId: recording.id),
                ),
              );
            }
            return ValueListenableBuilder<RecordingPlaybackViewState>(
              valueListenable: _playbackCoordinator.state,
              builder: (context, playbackState, _) {
                return RecordingCard(
                  recording: recording,
                  isExpanded: isExpanded,
                  onTap: () => expandRecording(recording),
                  onShowWaveform: () {
                    final nav = Navigator.of(this.context);
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => PlaybackScreen(recording: recording),
                      ),
                    );
                  },
                  onDelete: () => deleteRecording(recording),
                  onMoveToFolder: () => moveRecordingToFolder(recording),
                  onMoreActions: () => showMoreActions(recording),
                  onRestore: () => restoreRecording(recording),
                  onToggleFavorite: () => toggleFavoriteRecording(recording),
                  isPlaying: isActiveRecording ? playbackState.isPlaying : false,
                  isLoading: isActiveRecording ? playbackState.isLoading : false,
                  currentPosition: isActiveRecording ? playbackState.position : Duration.zero,
                  actualDuration: isActiveRecording ? playbackState.duration : null,
                  onPlayPause: togglePlayback,
                  onSeek: seekToPosition,
                  onSkipBackward: skipBackward,
                  onSkipForward: skipForward,
                  currentFolderId: widget.folder.id,
                  folderNames: folderNames,
                  isEditMode: isEditMode,
                  isSelected: selectedRecordings.contains(recording.id),
                  onSelectionToggle: () => context.read<RecordingBloc>().add(
                    ToggleRecordingSelection(recordingId: recording.id),
                  ),
                );
              },
            );
          },
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
    // PerformanceLogger.logRebuild('_RecordingListHeaderWrapper'); // Commentato o rimosso se PerformanceLogger non serve più
    return RecordingListHeader(
      folderName: folder.name,
      onBack: onBack,
      onShowFormatDialog: onShowFormatDialog,
      onMoveSelected: onMoveSelected,
    );
  }
}
