// File: presentation/bloc/recording/recording_bloc.dart
//
// Recording BLoC - Presentation Layer
// ====================================
//
// Central state management for audio recording in WavNote.
// Implements BLoC pattern for clean separation between UI and business logic.
//
// This file contains: class declaration, constructor, close(), lifecycle helpers,
// and trivial event handlers. Heavy handlers are split into part files to respect
// the 500-line limit (CLAUDE.md):
//
//   recording_bloc_lifecycle.dart  — start/stop/pause/resume/cancel handlers
//   recording_bloc_management.dart — load, delete, move, favorite, debug handlers

import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// Domain imports
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../services/audio/audio_service_coordinator.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../core/enums/audio_format.dart';

// Use case imports
import '../../../domain/usecases/recording/start_recording_usecase.dart';
import '../../../domain/usecases/recording/stop_recording_usecase.dart';
import '../../../domain/usecases/recording/pause_recording_usecase.dart';
import '../../../domain/usecases/recording/seek_and_resume_usecase.dart';

// Service imports
import '../../../services/location/geolocation_service.dart';
import '../../../services/audio/audio_trimmer_service.dart';
import '../folder/folder_bloc.dart';

// BLoC parts
part 'recording_event.dart';
part 'recording_state.dart';
part 'recording_bloc_lifecycle.dart';
part 'recording_bloc_management.dart';

/// BLoC responsible for managing audio recording state and operations.
///
/// Handles recording lifecycle, real-time updates, list management, and errors.
/// Split across part files to stay within the 500-line limit.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final StartRecordingUseCase _startRecordingUseCase;
  final StopRecordingUseCase _stopRecordingUseCase;
  final PauseRecordingUseCase _pauseRecordingUseCase;
  final SeekAndResumeUseCase _seekAndResumeUseCase;
  final AudioTrimmerService _trimmerService;
  final FolderBloc? _folderBloc;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _durationTimer;

  RecordingBloc({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    required GeolocationService geolocationService,
    FolderBloc? folderBloc,
    StartRecordingUseCase? startRecordingUseCase,
    StopRecordingUseCase? stopRecordingUseCase,
    PauseRecordingUseCase? pauseRecordingUseCase,
    SeekAndResumeUseCase? seekAndResumeUseCase,
    AudioTrimmerService? trimmerService,
  })  : _audioService = audioService,
        _recordingRepository = recordingRepository,
        _folderBloc = folderBloc,
        _trimmerService = trimmerService ?? AudioTrimmerService(),
        _startRecordingUseCase = startRecordingUseCase ??
            StartRecordingUseCase(
              audioService: audioService,
              geolocationService: geolocationService,
            ),
        _stopRecordingUseCase = stopRecordingUseCase ??
            StopRecordingUseCase(
              audioService: audioService,
              recordingRepository: recordingRepository,
              geolocationService: geolocationService,
            ),
        _pauseRecordingUseCase = pauseRecordingUseCase ??
            PauseRecordingUseCase(audioService: audioService),
        _seekAndResumeUseCase = seekAndResumeUseCase ??
            SeekAndResumeUseCase(
              audioService: audioService,
              trimmerService: trimmerService ?? AudioTrimmerService(),
            ),
        super(const RecordingInitial()) {
    // Lifecycle handlers (recording_bloc_lifecycle.dart)
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<CancelRecording>(_onCancelRecording);
    on<SeekAndResumeRecording>(_onSeekAndResumeRecording);

    // Real-time update handlers
    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);

    // Permission handlers
    on<CheckRecordingPermissions>(_onCheckRecordingPermissions);
    on<RequestRecordingPermissions>(_onRequestRecordingPermissions);

    // Management handlers (recording_bloc_management.dart)
    on<LoadRecordings>(_onLoadRecordings);
    on<ToggleEditMode>(_onToggleEditMode);
    on<ToggleRecordingSelection>(_onToggleRecordingSelection);
    on<ClearRecordingSelection>(_onClearRecordingSelection);
    on<UpdateRecordingTitle>(_onUpdateRecordingTitle);
    on<DeleteRecording>(_onDeleteRecording);
    on<SoftDeleteRecording>(_onSoftDeleteRecording);
    on<PermanentDeleteRecording>(_onPermanentDeleteRecording);
    on<RestoreRecording>(_onRestoreRecording);
    on<CleanupExpiredRecordings>(_onCleanupExpiredRecordings);
    on<SelectAllRecordings>(_onSelectAllRecordings);
    on<DeselectAllRecordings>(_onDeselectAllRecordings);
    on<DeleteSelectedRecordings>(_onDeleteSelectedRecordings);
    on<ToggleFavoriteRecording>(_onToggleFavoriteRecording);
    on<MoveRecordingToFolder>(_onMoveRecordingToFolder);
    on<MoveSelectedRecordingsToFolder>(_onMoveSelectedRecordingsToFolder);
    on<DebugLoadAllRecordings>(_onDebugLoadAllRecordings);
    on<DebugCreateTestRecording>(_onDebugCreateTestRecording);

    _initializeAudioService();
  }

  @override
  Future<void> close() async {
    await _amplitudeSubscription?.cancel();
    await _durationSubscription?.cancel();
    _durationTimer?.cancel();

    if (_audioService is AudioServiceCoordinator) {
      try {
        await _audioService.dispose();
      } catch (e) {
        print('⚠️ Error disposing audio service coordinator: $e');
      }
    }

    return super.close();
  }

  // ==== INITIALIZATION ====

  Future<void> _initializeAudioService() async {
    try {
      final success = await _audioService.initialize();
      if (!success) print('❌ Audio service initialization failed');
    } catch (e) {
      print('❌ Error initializing audio service: $e');
    }
  }

  // ==== REAL-TIME UPDATE HANDLERS ====

  void _onUpdateRecordingAmplitude(
      UpdateRecordingAmplitude event, Emitter<RecordingState> emit) {
    if (state is RecordingInProgress) {
      emit((state as RecordingInProgress).copyWith(amplitude: event.amplitude));
    }
  }

  void _onUpdateRecordingDuration(
      UpdateRecordingDuration event, Emitter<RecordingState> emit) {
    if (state is RecordingInProgress) {
      emit((state as RecordingInProgress).copyWith(duration: event.duration));
    } else if (state is RecordingPaused) {
      emit((state as RecordingPaused).copyWith(duration: event.duration));
    }
  }

  // ==== PERMISSION HANDLERS ====

  Future<void> _onCheckRecordingPermissions(
      CheckRecordingPermissions event, Emitter<RecordingState> emit) async {
    try {
      final hasPermission = await _audioService.hasMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();
      emit(RecordingPermissionStatus(
        hasMicrophonePermission: hasPermission,
        hasMicrophone: hasMicrophone,
      ));
    } catch (e) {
      print('❌ Error checking permissions: $e');
      emit(const RecordingPermissionStatus(
          hasMicrophonePermission: false, hasMicrophone: false));
    }
  }

  Future<void> _onRequestRecordingPermissions(
      RequestRecordingPermissions event, Emitter<RecordingState> emit) async {
    try {
      emit(const RecordingPermissionRequesting());
      final granted = await _audioService.requestMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();
      emit(RecordingPermissionStatus(
          hasMicrophonePermission: granted, hasMicrophone: hasMicrophone));
      if (!granted) {
        emit(const RecordingError('Microphone permission denied',
            errorType: RecordingErrorType.permission));
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      emit(const RecordingError('Failed to request permissions',
          errorType: RecordingErrorType.permission));
    }
  }

  // ==== UI STATE HANDLERS ====

  void _onToggleEditMode(
      ToggleEditMode event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final s = state as RecordingLoaded;
      emit(s.copyWith(
        isEditMode: !s.isEditMode,
        selectedRecordings: s.isEditMode ? <String>{} : s.selectedRecordings,
      ));
    }
  }

  void _onToggleRecordingSelection(
      ToggleRecordingSelection event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final s = state as RecordingLoaded;
      final selected = Set<String>.from(s.selectedRecordings);
      if (selected.contains(event.recordingId)) {
        selected.remove(event.recordingId);
      } else {
        selected.add(event.recordingId);
      }
      emit(s.copyWith(selectedRecordings: selected));
    }
  }

  void _onClearRecordingSelection(
      ClearRecordingSelection event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      emit((state as RecordingLoaded).copyWith(selectedRecordings: <String>{}));
    }
  }

  void _onSelectAllRecordings(
      SelectAllRecordings event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final s = state as RecordingLoaded;
      emit(s.copyWith(
          selectedRecordings: s.recordings.map((r) => r.id).toSet()));
    }
  }

  void _onDeselectAllRecordings(
      DeselectAllRecordings event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      emit((state as RecordingLoaded).copyWith(selectedRecordings: <String>{}));
    }
  }

  void _onUpdateRecordingTitle(
      UpdateRecordingTitle event, Emitter<RecordingState> emit) {
    if (state is RecordingInProgress) {
      emit((state as RecordingInProgress).copyWith(title: event.title));
    }
  }

  // ==== PRIVATE HELPERS ====

  void _refreshFolderCounts() {
    if (_folderBloc != null && !isClosed) {
      _folderBloc!.add(const RefreshFolders());
    }
  }

  void _startAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription =
        _audioService.getRecordingAmplitudeStream().listen(
      (amplitude) => add(UpdateRecordingAmplitude(amplitude)),
      onError: (e) => print('❌ Amplitude stream error: $e'),
    );
  }

  void _stopAmplitudeUpdates() => _amplitudeSubscription?.cancel();

  void _startDurationUpdates() {
    _durationTimer?.cancel();
    _durationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        final duration = await _audioService.getCurrentRecordingDuration();
        add(UpdateRecordingDuration(duration));
      } catch (e) {
        print('❌ Duration update error: $e');
      }
    });
  }

  void _stopDurationUpdates() => _durationTimer?.cancel();

  bool _needsReloadAfterFavoriteToggle(List<RecordingEntity> recordings) {
    if (recordings.isEmpty) return false;
    return recordings.map((r) => r.folderId).toSet().length > 1;
  }
}
