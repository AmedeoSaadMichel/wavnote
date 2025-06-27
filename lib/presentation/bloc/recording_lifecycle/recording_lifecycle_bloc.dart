// File: presentation/bloc/recording_lifecycle/recording_lifecycle_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../../domain/usecases/recording/recording_lifecycle_usecase.dart';

part 'recording_lifecycle_event.dart';
part 'recording_lifecycle_state.dart';

/// BLoC responsible for managing audio recording lifecycle operations
///
/// Handles recording start/stop/pause/resume, real-time updates, and recording state.
/// Uses RecordingLifecycleUseCase for clean separation of business logic.
class RecordingLifecycleBloc extends Bloc<RecordingLifecycleEvent, RecordingLifecycleState> {
  final RecordingLifecycleUseCase _useCase;

  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _durationTimer;

  RecordingLifecycleBloc({
    required RecordingLifecycleUseCase useCase,
  }) : _useCase = useCase,
        super(const RecordingLifecycleInitial()) {

    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<CancelRecording>(_onCancelRecording);
    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);
    on<UpdateRecordingTitle>(_onUpdateRecordingTitle);

    _initializeAudioService();
  }

  /// Initialize the audio service
  Future<void> _initializeAudioService() async {
    final success = await _useCase.initializeAudioService();
    if (!success) {
      emit(const RecordingLifecycleError('Failed to initialize audio service'));
    }
  }

  @override
  Future<void> close() async {
    await _amplitudeSubscription?.cancel();
    _durationTimer?.cancel();
    await _useCase.dispose();
    return super.close();
  }

  /// Start recording with geolocation-based naming
  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingLifecycleState> emit,
  ) async {
    try {
      emit(const RecordingLifecycleStarting());

      // Check permissions using use case
      final canRecord = await _useCase.canStartRecording();
      if (!canRecord) {
        emit(const RecordingLifecycleError('Microphone permission required'));
        return;
      }

      // Generate location-based title using use case
      final title = await _useCase.generateRecordingTitle();

      // Start recording using use case
      final success = await _useCase.startRecording(
        filePath: event.filePath,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
      );

      if (!success) {
        emit(const RecordingLifecycleError('Failed to start recording'));
        return;
      }

      // Setup real-time updates
      _setupRealTimeUpdates();

      emit(RecordingLifecycleInProgress(
        filePath: event.filePath,
        folderId: event.folderId,
        folderName: event.folderName,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
        duration: Duration.zero,
        amplitude: 0.0,
        startTime: DateTime.now(),
        title: title,
      ));

    } catch (e) {
      emit(RecordingLifecycleError('Failed to start recording: $e'));
    }
  }

  /// Stop recording and save using use case
  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingLifecycleState> emit,
  ) async {
    try {
      if (!state.canStopRecording) return;

      emit(const RecordingLifecycleStopping());

      // Cancel real-time updates
      await _amplitudeSubscription?.cancel();
      _durationTimer?.cancel();

      // Stop recording using use case
      final filePath = await _useCase.stopRecording();
      if (filePath == null) {
        emit(const RecordingLifecycleError('Failed to stop recording'));
        return;
      }

      // Get recording details from current state
      final currentState = state;
      String folderId = 'all_recordings';
      AudioFormat format = AudioFormat.m4a;
      int sampleRate = 44100;
      int bitRate = 128000;
      Duration duration = Duration.zero;
      DateTime startTime = DateTime.now();
      String title = 'New Recording';

      if (currentState is RecordingLifecycleInProgress) {
        folderId = currentState.folderId ?? folderId;
        format = currentState.format;
        sampleRate = currentState.sampleRate;
        bitRate = currentState.bitRate;
        duration = currentState.duration;
        startTime = currentState.startTime;
        title = currentState.title ?? title;
      } else if (currentState is RecordingLifecyclePaused) {
        folderId = currentState.folderId ?? folderId;
        format = currentState.format;
        sampleRate = currentState.sampleRate;
        bitRate = currentState.bitRate;
        duration = currentState.duration;
        startTime = currentState.startTime;
      }

      // Use the provided title if available
      final finalTitle = event.title ?? title;

      // Save recording using use case
      final recording = await _useCase.saveRecording(
        filePath: filePath,
        title: finalTitle,
        duration: duration,
        folderId: folderId,
        startTime: startTime,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );

      emit(RecordingLifecycleCompleted(recording: recording));

    } catch (e) {
      emit(RecordingLifecycleError('Failed to stop recording: $e'));
    }
  }

  /// Pause recording
  Future<void> _onPauseRecording(
    PauseRecording event,
    Emitter<RecordingLifecycleState> emit,
  ) async {
    if (!state.canPauseRecording) return;

    final success = await _useCase.pauseRecording();
    if (!success) {
      emit(const RecordingLifecycleError('Failed to pause recording'));
      return;
    }

    final currentState = state as RecordingLifecycleInProgress;
    
    // Cancel real-time updates
    await _amplitudeSubscription?.cancel();
    _durationTimer?.cancel();

    emit(RecordingLifecyclePaused(
      filePath: currentState.filePath,
      folderId: currentState.folderId,
      folderName: currentState.folderName,
      format: currentState.format,
      sampleRate: currentState.sampleRate,
      bitRate: currentState.bitRate,
      duration: currentState.duration,
      startTime: currentState.startTime,
    ));
  }

  /// Resume recording
  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingLifecycleState> emit,
  ) async {
    if (!state.canResumeRecording) return;

    final success = await _useCase.resumeRecording();
    if (!success) {
      emit(const RecordingLifecycleError('Failed to resume recording'));
      return;
    }

    final currentState = state as RecordingLifecyclePaused;
    
    // Resume real-time updates
    _setupRealTimeUpdates();

    emit(RecordingLifecycleInProgress(
      filePath: currentState.filePath,
      folderId: currentState.folderId,
      folderName: currentState.folderName,
      format: currentState.format,
      sampleRate: currentState.sampleRate,
      bitRate: currentState.bitRate,
      duration: currentState.duration,
      amplitude: 0.0,
      startTime: currentState.startTime,
      title: null,
    ));
  }

  /// Cancel recording
  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingLifecycleState> emit,
  ) async {
    // Cancel real-time updates
    await _amplitudeSubscription?.cancel();
    _durationTimer?.cancel();

    // Cancel recording using use case
    await _useCase.cancelRecording();

    emit(const RecordingLifecycleCancelled());
  }

  /// Update recording amplitude
  void _onUpdateRecordingAmplitude(
    UpdateRecordingAmplitude event,
    Emitter<RecordingLifecycleState> emit,
  ) {
    if (state is RecordingLifecycleInProgress) {
      final currentState = state as RecordingLifecycleInProgress;
      emit(currentState.copyWith(amplitude: event.amplitude));
    }
  }

  /// Update recording duration
  void _onUpdateRecordingDuration(
    UpdateRecordingDuration event,
    Emitter<RecordingLifecycleState> emit,
  ) {
    if (state is RecordingLifecycleInProgress) {
      final currentState = state as RecordingLifecycleInProgress;
      emit(currentState.copyWith(duration: event.duration));
    } else if (state is RecordingLifecyclePaused) {
      final currentState = state as RecordingLifecyclePaused;
      emit(currentState.copyWith(duration: event.duration));
    }
  }

  /// Update recording title
  void _onUpdateRecordingTitle(
    UpdateRecordingTitle event,
    Emitter<RecordingLifecycleState> emit,
  ) {
    if (state is RecordingLifecycleInProgress) {
      final currentState = state as RecordingLifecycleInProgress;
      emit(currentState.copyWith(title: event.title));
    }
  }

  /// Setup real-time amplitude and duration updates
  void _setupRealTimeUpdates() {
    // Amplitude updates using use case stream
    final amplitudeStream = _useCase.amplitudeStream;
    if (amplitudeStream != null) {
      _amplitudeSubscription = amplitudeStream.listen(
        (amplitude) => add(UpdateRecordingAmplitude(amplitude: amplitude)),
        onError: (e) => print('⚠️ Amplitude stream error: $e'),
      );
    }

    // Duration updates using timer (more reliable than stream)
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (state is RecordingLifecycleInProgress) {
        final currentState = state as RecordingLifecycleInProgress;
        final elapsed = DateTime.now().difference(currentState.startTime);
        add(UpdateRecordingDuration(duration: elapsed));
      }
    });
  }
}