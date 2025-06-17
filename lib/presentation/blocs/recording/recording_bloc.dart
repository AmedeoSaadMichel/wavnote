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

    // CRITICAL: Initialize the audio service when the bloc is created
    _initializeAudioService();
  }

  /// Initialize the audio service - CRITICAL FIX
  Future<void> _initializeAudioService() async {
    try {
      print('🔧 Initializing audio service...');
      final success = await _audioService.initialize();
      if (success) {
        print('✅ Audio service initialized successfully');
      } else {
        print('❌ Audio service initialization failed');
        emit(const RecordingError(
          'Failed to initialize audio service',
          errorType: RecordingErrorType.unknown,
        ));
      }
    } catch (e) {
      print('❌ Error initializing audio service: $e');
      emit(RecordingError(
        'Audio service initialization error: $e',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _amplitudeSubscription?.cancel();
    await _durationSubscription?.cancel();
    _durationTimer?.cancel();

    // Dispose audio service
    try {
      await _audioService.dispose();
    } catch (e) {
      print('⚠️ Error disposing audio service: $e');
    }

    return super.close();
  }

  /// Start recording with specified settings
  Future<void> _onStartRecording(
      StartRecording event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      print('🎤 Starting recording...');
      emit(const RecordingStarting());

      // Check permissions first
      final hasPermission = await _audioService.hasMicrophonePermission();
      if (!hasPermission) {
        print('❌ No microphone permission');
        emit(const RecordingError(
          'Microphone permission required to start recording',
          errorType: RecordingErrorType.permission,
        ));
        return;
      }

      // Generate file path
      final filePath = _generateFilePath(event.format, event.folderId);
      print('📁 Recording file path: $filePath');

      // Start recording
      final success = await _audioService.startRecording(
        filePath: filePath,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
      );

      if (!success) {
        print('❌ Failed to start recording');
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

      print('✅ Recording started successfully: $filePath');

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
    if (state is! RecordingInProgress && state is! RecordingPaused) {
      emit(const RecordingError(
        'No active recording to stop',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    try {
      emit(const RecordingStopping());

      // Stop real-time updates
      _stopAmplitudeUpdates();
      _stopDurationUpdates();

      // Stop recording and get the recording entity
      final recording = await _audioService.stopRecording();

      if (recording != null) {
        emit(RecordingCompleted(recording: recording));
        print('✅ Recording completed: ${recording.name}');
      } else {
        emit(const RecordingError(
          'Failed to complete recording',
          errorType: RecordingErrorType.recording,
        ));
      }

    } catch (e) {
      print('❌ Error stopping recording: $e');
      emit(RecordingError(
        'Failed to stop recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Pause recording
  Future<void> _onPauseRecording(
      PauseRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress) return;

    try {
      final success = await _audioService.pauseRecording();
      if (success) {
        final currentState = state as RecordingInProgress;
        emit(RecordingPaused(
          filePath: currentState.filePath,
          folderId: currentState.folderId,
          format: currentState.format,
          sampleRate: currentState.sampleRate,
          bitRate: currentState.bitRate,
          duration: currentState.duration,
          startTime: currentState.startTime,
        ));
        print('⏸️ Recording paused');
      }
    } catch (e) {
      print('❌ Error pausing recording: $e');
    }
  }

  /// Resume recording
  Future<void> _onResumeRecording(
      ResumeRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingPaused) return;

    try {
      final success = await _audioService.resumeRecording();
      if (success) {
        final currentState = state as RecordingPaused;
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

        // Restart updates
        _startAmplitudeUpdates();
        _startDurationUpdates();

        print('▶️ Recording resumed');
      }
    } catch (e) {
      print('❌ Error resuming recording: $e');
    }
  }

  /// Cancel recording
  Future<void> _onCancelRecording(
      CancelRecording event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      // Stop updates
      _stopAmplitudeUpdates();
      _stopDurationUpdates();

      // Cancel recording
      await _audioService.cancelRecording();

      emit(const RecordingCancelled());
      print('🚫 Recording cancelled');

    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
  }

  /// Update recording amplitude
  void _onUpdateRecordingAmplitude(
      UpdateRecordingAmplitude event,
      Emitter<RecordingState> emit,
      ) {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(amplitude: event.amplitude));
    }
  }

  /// Update recording duration
  void _onUpdateRecordingDuration(
      UpdateRecordingDuration event,
      Emitter<RecordingState> emit,
      ) {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(duration: event.duration));
    } else if (state is RecordingPaused) {
      final currentState = state as RecordingPaused;
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

  /// Stop amplitude updates
  void _stopAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
  }

  /// Start duration updates
  void _startDurationUpdates() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        final duration = await _audioService.getCurrentRecordingDuration();
        add(UpdateRecordingDuration(duration));
      } catch (e) {
        print('❌ Duration update error: $e');
      }
    });
  }

  /// Stop duration updates
  void _stopDurationUpdates() {
    _durationTimer?.cancel();
  }

  /// Generate file path for recording
  String _generateFilePath(AudioFormat format, String? folderId) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final folderPath = folderId ?? 'all_recordings';
    final extension = format.fileExtension;
    return '$folderPath/recording_$timestamp$extension';
  }
}