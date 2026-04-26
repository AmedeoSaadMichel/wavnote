// File: presentation/bloc/recording/recording_bloc.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart'; // IMPORT FONDAMENTALE
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;

// Domain imports
import '../../../core/utils/app_file_utils.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../core/enums/audio_format.dart';

// Use case imports
import '../../../domain/usecases/recording/start_recording_usecase.dart';
import '../../../domain/usecases/recording/stop_recording_usecase.dart';
import '../../../domain/usecases/recording/pause_recording_usecase.dart';
import '../../../domain/usecases/recording/overwrite_recording_usecase.dart';

// Service imports
import '../../../config/dependency_injection.dart';
import '../../../domain/repositories/i_location_repository.dart';
import '../../../domain/repositories/i_audio_trimmer_repository.dart';
import '../folder/folder_bloc.dart';

// BLoC parts
part 'recording_event.dart';
part 'recording_state.dart';
part 'recording_bloc_lifecycle.dart';
part 'recording_bloc_management.dart';

/// BLoC responsible for managing audio recording state and operations.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final ILocationRepository _locationRepository;
  final StartRecordingUseCase _startRecordingUseCase;
  final StopRecordingUseCase _stopRecordingUseCase;
  final PauseRecordingUseCase _pauseRecordingUseCase;
  final OverwriteRecordingUseCase _overwriteRecordingUseCase;
  final IAudioTrimmerRepository _trimmerService;
  final FolderBloc? _folderBloc;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  RecordingBloc({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    required ILocationRepository locationRepository,
    FolderBloc? folderBloc,
    StartRecordingUseCase? startRecordingUseCase,
    StopRecordingUseCase? stopRecordingUseCase,
    PauseRecordingUseCase? pauseRecordingUseCase,
    OverwriteRecordingUseCase? overwriteRecordingUseCase,
    IAudioTrimmerRepository? trimmerService,
  }) : _audioService = audioService,
       _recordingRepository = recordingRepository,
       _locationRepository = locationRepository,
       _folderBloc = folderBloc,
       _trimmerService = trimmerService ?? sl<IAudioTrimmerRepository>(),
       _startRecordingUseCase =
           startRecordingUseCase ??
           StartRecordingUseCase(
             audioService: audioService,
             locationRepository: locationRepository,
           ),
       _stopRecordingUseCase =
           stopRecordingUseCase ??
           StopRecordingUseCase(
             audioService: audioService,
             recordingRepository: recordingRepository,
             locationRepository: locationRepository,
           ),
       _pauseRecordingUseCase =
           pauseRecordingUseCase ??
           PauseRecordingUseCase(audioService: audioService),
       _overwriteRecordingUseCase =
           overwriteRecordingUseCase ??
           OverwriteRecordingUseCase(
             trimmerService: trimmerService ?? sl<IAudioTrimmerRepository>(),
           ),
       super(const RecordingInitial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<ResumeWithAutoStop>(_onResumeWithAutoStop);
    on<CancelRecording>(_onCancelRecording);
    on<StartOverwrite>(_onStartOverwrite);
    on<UpdateSeekBarIndex>(_onUpdateSeekBarIndex);
    on<PlayRecordingPreview>(_onPlayRecordingPreview);
    on<StopRecordingPreview>(_onStopRecordingPreview);

    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);

    on<CheckRecordingPermissions>(_onCheckRecordingPermissions);
    on<RequestRecordingPermissions>(_onRequestRecordingPermissions);

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

    if (_audioService.needsDisposal) {
      try {
        await _audioService.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing audio service coordinator: $e');
      }
    }

    return super.close();
  }

  Future<void> _initializeAudioService() async {
    try {
      final success = await _audioService.initialize();
      if (!success) debugPrint('❌ Audio service initialization failed');
    } catch (e) {
      debugPrint('❌ Error initializing audio service: $e');
    }
  }

  // ==== HANDLERS (implementati nei part file) ====
  void _onUpdateRecordingAmplitude(
    UpdateRecordingAmplitude event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingInProgress) {
      debugPrint('🔍 BLoC received amplitude: ${event.amplitude}');
      emit((state as RecordingInProgress).copyWith(amplitude: event.amplitude));
    }
  }

  void _onUpdateRecordingDuration(
    UpdateRecordingDuration event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingInProgress) {
      emit((state as RecordingInProgress).copyWith(duration: event.duration));
    }
  }

  Future<void> _onCheckRecordingPermissions(
    CheckRecordingPermissions event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      final hasPermission = await _audioService.hasMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();
      emit(
        RecordingPermissionStatus(
          hasMicrophonePermission: hasPermission,
          hasMicrophone: hasMicrophone,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      emit(
        const RecordingPermissionStatus(
          hasMicrophonePermission: false,
          hasMicrophone: false,
        ),
      );
    }
  }

  Future<void> _onRequestRecordingPermissions(
    RequestRecordingPermissions event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      emit(const RecordingPermissionRequesting());
      final granted = await _audioService.requestMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();
      emit(
        RecordingPermissionStatus(
          hasMicrophonePermission: granted,
          hasMicrophone: hasMicrophone,
        ),
      );
      if (!granted) {
        emit(
          const RecordingError(
            'Microphone permission denied',
            errorType: RecordingErrorType.permission,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      emit(
        const RecordingError(
          'Failed to request permissions',
          errorType: RecordingErrorType.permission,
        ),
      );
    }
  }

  void _onToggleEditMode(ToggleEditMode event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final s = state as RecordingLoaded;
      emit(
        s.copyWith(
          isEditMode: !s.isEditMode,
          selectedRecordings: s.isEditMode ? <String>{} : s.selectedRecordings,
        ),
      );
    }
  }

  void _onToggleRecordingSelection(
    ToggleRecordingSelection event,
    Emitter<RecordingState> emit,
  ) {
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
    ClearRecordingSelection event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingLoaded) {
      emit((state as RecordingLoaded).copyWith(selectedRecordings: <String>{}));
    }
  }

  void _onSelectAllRecordings(
    SelectAllRecordings event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingLoaded) {
      final s = state as RecordingLoaded;
      emit(
        s.copyWith(selectedRecordings: s.recordings.map((r) => r.id).toSet()),
      );
    }
  }

  void _onDeselectAllRecordings(
    DeselectAllRecordings event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingLoaded) {
      emit((state as RecordingLoaded).copyWith(selectedRecordings: <String>{}));
    }
  }

  void _onUpdateRecordingTitle(
    UpdateRecordingTitle event,
    Emitter<RecordingState> emit,
  ) {
    if (state is RecordingInProgress) {
      emit((state as RecordingInProgress).copyWith(title: event.title));
    }
  }

  Future<void> _refreshTitleInBackground() async {
    try {
      final loc = await _locationRepository.getRecordingLocationName();
      if (loc.isNotEmpty && !isClosed && state is RecordingInProgress) {
        add(UpdateRecordingTitle(title: loc));
      }
    } catch (_) {}
  }

  void _refreshFolderCounts() {
    if (_folderBloc != null && !isClosed) {
      _folderBloc.add(const RefreshFolders());
    }
  }

  void _startAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioService.getRecordingAmplitudeStream().listen(
      (amplitude) => add(UpdateRecordingAmplitude(amplitude)),
      onError: (e) => debugPrint('❌ Amplitude stream error: $e'),
    );
  }

  void _stopAmplitudeUpdates() => _amplitudeSubscription?.cancel();

  void _startDurationUpdates() {
    _durationSubscription?.cancel();
    _durationSubscription = _audioService.durationStream?.listen(
      (duration) => add(UpdateRecordingDuration(duration)),
      onError: (e) => debugPrint('❌ Duration stream error: $e'),
    );
  }

  void _stopDurationUpdates() => _durationSubscription?.cancel();
}
