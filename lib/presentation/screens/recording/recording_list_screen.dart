// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/dialogs/audio_format_dialog.dart';
import '../../widgets/recording/recording_card/recording_card.dart';
import '../../widgets/recording/recording_list_header.dart';
import '../../widgets/recording/pull_to_search_list.dart';
import '../../widgets/common/skeleton_screen.dart';
// import '../../../services/audio/audio_player_service.dart'; // Rimosso o commentato
import 'recording_list_logic.dart';
import '../../../core/routing/app_router.dart';
// import '../../../core/utils/performance_logger.dart'; // Rimosso: import non utilizzato

// Nuovi import per il playback
import 'controllers/recording_playback_coordinator.dart';
import 'controllers/recording_playback_view_state.dart';
import '../playback/playback_screen.dart';

/// Recording List Screen with Single AudioPlayer Architecture
///
/// Features:
/// - Single AudioPlayer instance at screen level
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
    // Inizializza il coordinator (ora è idempotente)
    _playbackCoordinator.initialize();
    // Clean architecture: Single loading point via initializeRecordingList
    initializeRecordingList();
  }

  @override
  void dispose() {
    _playbackCoordinator
        .dispose(); // Dispone il coordinator quando la screen muore (corretto per factory)
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    print(
      '🏗️ VERBOSE: RecordingListScreen build() called for folder: ${widget.folder.name}',
    );
    // PerformanceLogger.logRebuild('RecordingListScreen'); // Commentato o rimosso se PerformanceLogger non serve più
    return MultiBlocListener(
      listeners: [
        BlocListener<RecordingBloc, RecordingState>(
          listener: (context, state) => handleRecordingStateChange(state),
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

        if (state is RecordingLoaded && state.recordings.isNotEmpty) {
          print('🚀 FAST PATH: Showing content immediately');
          final filteredRecordings = filterRecordings(state.recordings);
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

              // Utilizza ValueListenableBuilder per ricostruire solo la RecordingCard
              // quando lo stato di playback cambia, senza ricostruire l'intera lista.
              return ValueListenableBuilder<RecordingPlaybackViewState>(
                valueListenable: _playbackCoordinator.state,
                builder: (context, playbackState, child) {
                  final isExpanded =
                      playbackState.expandedRecordingId == recording.id;
                  final isActiveRecording =
                      playbackState.activeRecordingId == recording.id;

                  print(
                    '🔍 UI: Building card for ${recording.name} (ID: ${recording.id}), expandedId: ${playbackState.expandedRecordingId}, isExpanded: $isExpanded, isActive: $isActiveRecording',
                  );
                  print('🔍 UI: Card favorite status: ${recording.isFavorite}');

                  return RecordingCard(
                    recording: recording,
                    isExpanded: isExpanded,
                    onTap: () => expandRecording(recording),
                    onShowWaveform: () {
                      final nav = Navigator.of(this.context);
                      nav.push(MaterialPageRoute(
                        builder: (_) => PlaybackScreen(recording: recording),
                      ));
                    },
                    onDelete: () => deleteRecording(recording),
                    onMoveToFolder: () => moveRecordingToFolder(recording),
                    onMoreActions: () => showMoreActions(recording),
                    onRestore: () => restoreRecording(recording),
                    onToggleFavorite: () => toggleFavoriteRecording(recording),
                    // audioStateManager: isExpanded
                    //     ? audioPlayerService.audioState
                    //     : null, // AudioStateManager non è più usato qui
                    isPlaying: isActiveRecording
                        ? playbackState.isPlaying
                        : false,
                    isLoading: isActiveRecording
                        ? playbackState.isLoading
                        : false,
                    currentPosition: isActiveRecording
                        ? playbackState.position
                        : Duration.zero,
                    actualDuration: isActiveRecording
                        ? playbackState.duration
                        : null,
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
            ? (recordingState as RecordingPaused).title ?? 'New Recording'
            : 'New Recording';
        final elapsed = recordingState.currentDuration ?? Duration.zero;
        final amplitude = recordingState is RecordingInProgress
            ? recordingState.amplitude
            : 0.0;
        final truncatedWaveData = recordingState is RecordingInProgress
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
          onToggle: toggleRecording,
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
            // Finiamo la registrazione e incrementiamo il contatore per
            // segnalare a Flutter di non riciclare il widget Waveform
            // alla prossima sessione.
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
    RecordingLoaded state,
  ) {
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

        return ValueListenableBuilder<RecordingPlaybackViewState>(
          valueListenable: _playbackCoordinator.state,
          builder: (context, playbackState, child) {
            final isExpanded =
                playbackState.expandedRecordingId == recording.id;
            final isActiveRecording =
                playbackState.activeRecordingId == recording.id;

            print(
              '🔍 UI: Building card for ${recording.name} (ID: ${recording.id}), expandedId: ${playbackState.expandedRecordingId}, isExpanded: $isExpanded, isActive: $isActiveRecording',
            );
            print('🔍 UI: Card favorite status: ${recording.isFavorite}');

            return RecordingCard(
              recording: recording,
              isExpanded: isExpanded,
              onTap: () => expandRecording(recording),
              onShowWaveform: () {
                final nav = Navigator.of(this.context);
                nav.push(MaterialPageRoute(
                  builder: (_) => PlaybackScreen(recording: recording),
                ));
              },
              onDelete: () => deleteRecording(recording),
              onMoveToFolder: () => moveRecordingToFolder(recording),
              onMoreActions: () => showMoreActions(recording),
              onRestore: () => restoreRecording(recording),
              onToggleFavorite: () => toggleFavoriteRecording(recording),
              // audioStateManager: isExpanded
              //     ? audioPlayerService.audioState
              //     : null, // AudioStateManager non è più usato qui
              isPlaying: isActiveRecording ? playbackState.isPlaying : false,
              isLoading: isActiveRecording ? playbackState.isLoading : false,
              currentPosition: isActiveRecording
                  ? playbackState.position
                  : Duration.zero,
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
