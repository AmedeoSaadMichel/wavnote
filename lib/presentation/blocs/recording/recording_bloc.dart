// File: presentation/blocs/recording/recording_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../core/enums/audio_format.dart';

part 'recording_event.dart';
part 'recording_state.dart';

/// Bloc responsible for managing audio recording state and operations
///
/// Handles recording start/stop/pause, real-time updates, and error states.
/// Provides clean separation between UI and audio service logic.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final IAudioServiceRepository _audioService;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _durationTimer;

  RecordingBloc({
    required IAudioServiceRepository audioService,
  }) : _audioService = audioService,
        super(const RecordingInitial()) {

    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<CancelRecording>(_onCancelRecording);
    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);
    on<CheckRecordingPermissions>(_onCheckRecordingPermissions);
    on<RequestRecordingPermissions>(_onRequestRecordingPermissions);
  }

  /// Start recording with specified settings
  Future<void> _onStartRecording(
      StartRecording event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      emit(const RecordingStarting());

      // Check permissions first
      final hasPermission = await _audioService.hasMicrophonePermission();
      if (!hasPermission) {
        emit(const RecordingError(
          'Microphone permission required to start recording',
          errorType: RecordingErrorType.permission,
        ));
        return;
      }

      // Generate file path
      final filePath = _generateFilePath(event.format, event.folderId);

      // Start recording
      final success = await _audioService.startRecording(
        filePath: filePath,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
      );

      if (!success) {
        emit(const RecordingError(
          'Failed to start recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      // Start real-time updates
      _startAmplitudeUpdates();
      _startDurationUpdates();

      emit(RecordingInProgress(
        filePath: filePath,
        folderId: event.folderId,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
        duration: Duration.zero,
        amplitude: 0.0,
        startTime: DateTime.now(),
      ));

      print('✅ Recording started: $filePath');

    } catch (e, stackTrace) {
      print('❌ Error starting recording: $e');
      print('Stack trace: $stackTrace');
      emit(RecordingError(
        'Failed to start recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Stop recording and create RecordingEntity
  Future<void> _onStopRecording(
      StopRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress) {
      emit(const RecordingError(
        'No active recording to stop',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    final currentState = state as RecordingInProgress;

    try {
      emit(RecordingStopping(
        filePath: currentState.filePath,
        folderId: currentState.folderId,
        format: currentState.format,
        sampleRate: currentState.sampleRate,
        bitRate: currentState.bitRate,
        duration: currentState.duration,
        amplitude: currentState.amplitude,
        startTime: currentState.startTime,
      ));

      // Stop real-time updates
      _stopUpdates();

      // Stop recording service
      final recording = await _audioService.stopRecording();

      if (recording == null) {
        emit(const RecordingError(
          'Failed to stop recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      // Use provided name or generate default
      final finalRecording = recording.copyWith(
        name: event.recordingName?.isNotEmpty == true
            ? event.recordingName
            : _generateDefaultName(),
      );

      emit(RecordingCompleted(
        recording: finalRecording,
        wasSuccessful: true,
      ));

      print('✅ Recording completed: ${finalRecording.name}');

    } catch (e, stackTrace) {
      print('❌ Error stopping recording: $e');
      print('Stack trace: $stackTrace');

      _stopUpdates();

      emit(RecordingError(
        'Failed to stop recording: ${e.toString()}',
        errorType: RecordingErrorType.recording,
      ));
    }
  }

  /// Pause current recording
  Future<void> _onPauseRecording(
      PauseRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress) {
      emit(const RecordingError(
        'No active recording to pause',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    final currentState = state as RecordingInProgress;

    try {
      final success = await _audioService.pauseRecording();

      if (!success) {
        emit(const RecordingError(
          'Failed to pause recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      // Stop real-time updates but keep duration
      _stopUpdates();

      emit(RecordingPaused(
        filePath: currentState.filePath,
        folderId: currentState.folderId,
        format: currentState.format,
        sampleRate: currentState.sampleRate,
        bitRate: currentState.bitRate,
        duration: currentState.duration,
        amplitude: 0.0,
        startTime: currentState.startTime,
        pausedAt: DateTime.now(),
      ));

      print('⏸️ Recording paused');

    } catch (e) {
      print('❌ Error pausing recording: $e');
      emit(RecordingError(
        'Failed to pause recording: ${e.toString()}',
        errorType: RecordingErrorType.recording,
      ));
    }
  }

  /// Resume paused recording
  Future<void> _onResumeRecording(
      ResumeRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingPaused) {
      emit(const RecordingError(
        'No paused recording to resume',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    final currentState = state as RecordingPaused;

    try {
      final success = await _audioService.resumeRecording();

      if (!success) {
        emit(const RecordingError(
          'Failed to resume recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      // Restart real-time updates
      _startAmplitudeUpdates();
      _startDurationUpdates();

      emit(RecordingInProgress(
        filePath: currentState.filePath,
        folderId: currentState.folderId,
        format: currentState.format,
        sampleRate: currentState.sampleRate,
        bitRate: currentState.bitRate,
        duration: currentState.duration,
        amplitude: 0.0,
        startTime: currentState.startTime,
      ));

      print('▶️ Recording resumed');

    } catch (e) {
      print('❌ Error resuming recording: $e');
      emit(RecordingError(
        'Failed to resume recording: ${e.toString()}',
        errorType: RecordingErrorType.recording,
      ));
    }
  }

  /// Cancel current recording
  Future<void> _onCancelRecording(
      CancelRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress && state is! RecordingPaused) {
      emit(const RecordingError(
        'No active recording to cancel',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    try {
      // Stop real-time updates
      _stopUpdates();

      // Cancel recording service (deletes file)
      final success = await _audioService.cancelRecording();

      if (!success) {
        emit(const RecordingError(
          'Failed to cancel recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      emit(const RecordingCancelled());

      print('🚫 Recording cancelled');

    } catch (e) {
      print('❌ Error cancelling recording: $e');
      _stopUpdates();
      emit(RecordingError(
        'Failed to cancel recording: ${e.toString()}',
        errorType: RecordingErrorType.recording,
      ));
    }
  }

  /// Update recording amplitude for visualization
  Future<void> _onUpdateRecordingAmplitude(
      UpdateRecordingAmplitude event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(amplitude: event.amplitude));
    }
  }

  /// Update recording duration
  Future<void> _onUpdateRecordingDuration(
      UpdateRecordingDuration event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(duration: event.duration));
    }
  }

  /// Check recording permissions
  Future<void> _onCheckRecordingPermissions(
      CheckRecordingPermissions event,
      Emitter<RecordingState> emit,
      ) async {
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
        hasMicrophonePermission: false,
        hasMicrophone: false,
      ));
    }
  }

  /// Request recording permissions
  Future<void> _onRequestRecordingPermissions(
      RequestRecordingPermissions event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      emit(const RecordingPermissionRequesting());

      final granted = await _audioService.requestMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();

      emit(RecordingPermissionStatus(
        hasMicrophonePermission: granted,
        hasMicrophone: hasMicrophone,
      ));

      if (!granted) {
        emit(const RecordingError(
          'Microphone permission denied',
          errorType: RecordingErrorType.permission,
        ));
      }

    } catch (e) {
      print('❌ Error requesting permissions: $e');
      emit(const RecordingError(
        'Failed to request permissions',
        errorType: RecordingErrorType.permission,
      ));
    }
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Start amplitude updates for visualization
  void _startAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioService.getRecordingAmplitudeStream().listen(
          (amplitude) {
        add(UpdateRecordingAmplitude(amplitude));
      },
      onError: (error) {
        print('❌ Amplitude stream error: $error');
      },
    );
  }

  /// Start duration updates
  void _startDurationUpdates() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final duration = await _audioService.getCurrentRecordingDuration();
        add(UpdateRecordingDuration(duration));
      } catch (e) {
        print('❌ Duration update error: $e');
      }
    });
  }

  /// Stop all real-time updates
  void _stopUpdates() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Generate file path for recording
  String _generateFilePath(AudioFormat format, String folderId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'recording_${timestamp}${format.fileExtension}';
    return 'recordings/$folderId/$fileName';
  }

  /// Generate default recording name
  String _generateDefaultName() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return 'Recording $dateStr $timeStr';
  }

  @override
  Future<void> close() {
    _stopUpdates();
    return super.close();
  }
}