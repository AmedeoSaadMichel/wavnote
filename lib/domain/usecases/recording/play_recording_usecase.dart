// File: domain/usecases/recording/play_recording_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../repositories/i_audio_service_repository.dart';
import 'dart:io';

/// Use case for playing back recorded audio
///
/// Handles the complete flow of audio playback including:
/// - File validation
/// - Audio player initialization
/// - Playback control
/// - Position tracking
/// - State management
class PlayRecordingUseCase {
  final IRecordingRepository _recordingRepository;
  final IAudioServiceRepository _audioServiceRepository;

  const PlayRecordingUseCase({
    required IRecordingRepository recordingRepository,
    required IAudioServiceRepository audioServiceRepository,
  })  : _recordingRepository = recordingRepository,
        _audioServiceRepository = audioServiceRepository;

  /// Start playing a recording
  Future<Either<RecordingFailure, PlaybackSession>> play(
      PlayRecordingParams params,
      ) async {
    try {
      // 1. Validate recording file
      final validationResult = await _validateRecordingFile(params.recording);
      if (validationResult.isLeft()) {
        return Left(validationResult.fold((l) => l, (r) => throw Exception()));
      }

      // 2. Initialize audio player
      final initResult = await _initializeAudioPlayer(params);
      if (initResult.isLeft()) {
        return Left(initResult.fold((l) => l, (r) => throw Exception()));
      }

      // 3. Start playback
      final playResult = await _startPlayback(params.recording, params.startPosition);
      if (playResult.isLeft()) {
        return Left(playResult.fold((l) => l, (r) => throw Exception()));
      }

      // 4. Update recording entity
      await _updateRecordingPlaybackState(params.recording, true);

      // 5. Create playback session
      final session = PlaybackSession(
        recording: params.recording,
        startTime: DateTime.now(),
        startPosition: params.startPosition,
        playbackRate: params.playbackRate,
        volume: params.volume,
      );

      return Right(session);
    } catch (e) {
      return Left(RecordingFailure.unexpected(e.toString()));
    }
  }

  /// Pause playback
  Future<Either<RecordingFailure, PausedPlayback>> pause(
      PausePlaybackParams params,
      ) async {
    try {
      // 1. Get current position
      final currentPosition = await _audioServiceRepository.getCurrentPlaybackPosition();

      // 2. Pause audio player
      final pauseResult = await _audioServiceRepository.pausePlaying();
      if (!pauseResult) {
        return Left(RecordingFailure.audioServiceError('Failed to pause playback'));
      }

      // 3. Create paused state
      final pausedPlayback = PausedPlayback(
        session: params.session,
        pausePosition: currentPosition,
        pauseTime: DateTime.now(),
      );

      return Right(pausedPlayback);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Resume playback
  Future<Either<RecordingFailure, PlaybackSession>> resume(
      ResumePlaybackParams params,
      ) async {
    try {
      // 1. Resume audio player
      final resumeResult = await _audioServiceRepository.resumePlaying();
      if (!resumeResult) {
        return Left(RecordingFailure.audioServiceError('Failed to resume playback'));
      }

      // 2. Create new session
      final session = PlaybackSession(
        recording: params.pausedPlayback.session.recording,
        startTime: DateTime.now(),
        startPosition: params.pausedPlayback.pausePosition,
        playbackRate: params.pausedPlayback.session.playbackRate,
        volume: params.pausedPlayback.session.volume,
      );

      return Right(session);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Stop playback
  Future<Either<RecordingFailure, PlaybackComplete>> stop(
      StopPlaybackParams params,
      ) async {
    try {
      // 1. Get final position
      final finalPosition = await _audioServiceRepository.getCurrentPlaybackPosition();

      // 2. Stop audio player
      final stopResult = await _audioServiceRepository.stopPlaying();
      if (!stopResult) {
        return Left(RecordingFailure.audioServiceError('Failed to stop playback'));
      }

      // 3. Update recording entity
      await _updateRecordingPlaybackState(params.session.recording, false, finalPosition);

      // 4. Cleanup audio player
      await _audioServiceRepository.dispose();

      // 5. Create completion result
      final completion = PlaybackComplete(
        session: params.session,
        finalPosition: finalPosition,
        totalPlayTime: DateTime.now().difference(params.session.startTime),
        wasCompleted: finalPosition >= params.session.recording.duration,
      );

      return Right(completion);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Seek to position
  Future<Either<RecordingFailure, Duration>> seek(
      SeekParams params,
      ) async {
    try {
      // 1. Validate seek position
      if (params.position > params.session.recording.duration) {
        return Left(RecordingFailure.audioServiceError('Seek position beyond recording duration'));
      }

      if (params.position.isNegative) {
        return Left(RecordingFailure.audioServiceError('Seek position cannot be negative'));
      }

      // 2. Perform seek
      final seekResult = await _audioServiceRepository.seekTo(params.position);
      if (!seekResult) {
        return Left(RecordingFailure.audioServiceError('Failed to seek to position'));
      }

      // 3. Update recording playback position
      await _updateRecordingPlaybackState(
        params.session.recording,
        true,
        params.position,
      );

      return Right(params.position);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Change playback rate
  Future<Either<RecordingFailure, double>> changePlaybackRate(
      ChangePlaybackRateParams params,
      ) async {
    try {
      // 1. Validate playback rate
      if (params.rate < 0.25 || params.rate > 3.0) {
        return Left(RecordingFailure.audioServiceError('Playback rate must be between 0.25x and 3.0x'));
      }

      // 2. Change playback rate
      final changeResult = await _audioServiceRepository.setPlaybackSpeed(params.rate);
      if (!changeResult) {
        return Left(RecordingFailure.audioServiceError('Failed to change playback rate'));
      }

      return Right(params.rate);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Validate recording file exists and is playable
  Future<Either<RecordingFailure, void>> _validateRecordingFile(
      RecordingEntity recording,
      ) async {
    try {
      final file = File(recording.filePath);

      if (!await file.exists()) {
        return Left(RecordingFailure.recordingError('Recording file not found'));
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return Left(RecordingFailure.recordingError('Recording file is empty'));
      }

      // Check if file format is supported
      final supportedFormats = await _audioServiceRepository.getSupportedFormats();
      if (!supportedFormats.contains(recording.format)) {
        return Left(RecordingFailure.audioServiceError('Audio format not supported'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.recordingError('Failed to validate recording file: $e'));
    }
  }

  /// Initialize audio player with settings
  Future<Either<RecordingFailure, void>> _initializeAudioPlayer(
      PlayRecordingParams params,
      ) async {
    try {
      final isInitialized = await _audioServiceRepository.initialize();

      if (!isInitialized) {
        return Left(RecordingFailure.audioServiceError('Failed to initialize audio player'));
      }

      // Set volume and playback rate
      await _audioServiceRepository.setVolume(params.volume);
      await _audioServiceRepository.setPlaybackSpeed(params.playbackRate);

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Start audio playback
  Future<Either<RecordingFailure, void>> _startPlayback(
      RecordingEntity recording,
      Duration startPosition,
      ) async {
    try {
      // Start playing the file
      final playResult = await _audioServiceRepository.startPlaying(recording.filePath);
      if (!playResult) {
        return Left(RecordingFailure.audioServiceError('Failed to start playback'));
      }

      // Seek to start position if not at beginning
      if (startPosition > Duration.zero) {
        await _audioServiceRepository.seekTo(startPosition);
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError(e.toString()));
    }
  }

  /// Update recording playback state in database
  Future<void> _updateRecordingPlaybackState(
      RecordingEntity recording,
      bool isPlaying, [
        Duration? position,
      ]) async {
    try {
      final updatedRecording = recording.copyWith(
        updatedAt: DateTime.now(),
      );

      await _recordingRepository.updateRecording(updatedRecording);
    } catch (e) {
      // Log error but don't fail the playback operation
      print('Warning: Failed to update recording playback state: $e');
    }
  }
}

/// Parameters for playing a recording
class PlayRecordingParams {
  final RecordingEntity recording;
  final Duration startPosition;
  final double playbackRate;
  final double volume;

  const PlayRecordingParams({
    required this.recording,
    this.startPosition = Duration.zero,
    this.playbackRate = 1.0,
    this.volume = 1.0,
  });

  /// Create params for resuming from last position
  factory PlayRecordingParams.resume(RecordingEntity recording) {
    return PlayRecordingParams(
      recording: recording,
      startPosition: Duration.zero, // No playbackPosition property exists in RecordingEntity
      playbackRate: 1.0,
      volume: 1.0,
    );
  }
}

/// Parameters for pausing playback
class PausePlaybackParams {
  final PlaybackSession session;

  const PausePlaybackParams({required this.session});
}

/// Parameters for resuming playback
class ResumePlaybackParams {
  final PausedPlayback pausedPlayback;

  const ResumePlaybackParams({required this.pausedPlayback});
}

/// Parameters for stopping playback
class StopPlaybackParams {
  final PlaybackSession session;

  const StopPlaybackParams({required this.session});
}

/// Parameters for seeking
class SeekParams {
  final PlaybackSession session;
  final Duration position;

  const SeekParams({
    required this.session,
    required this.position,
  });
}

/// Parameters for changing playback rate
class ChangePlaybackRateParams {
  final PlaybackSession session;
  final double rate;

  const ChangePlaybackRateParams({
    required this.session,
    required this.rate,
  });
}

/// Playback session data
class PlaybackSession {
  final RecordingEntity recording;
  final DateTime startTime;
  final Duration startPosition;
  final double playbackRate;
  final double volume;

  const PlaybackSession({
    required this.recording,
    required this.startTime,
    required this.startPosition,
    required this.playbackRate,
    required this.volume,
  });

  /// Get elapsed playback time
  Duration get elapsedTime => DateTime.now().difference(startTime);

  /// Get estimated current position
  Duration get estimatedPosition =>
      startPosition + Duration(milliseconds: (elapsedTime.inMilliseconds * playbackRate).round());
}

/// Paused playback state
class PausedPlayback {
  final PlaybackSession session;
  final Duration pausePosition;
  final DateTime pauseTime;

  const PausedPlayback({
    required this.session,
    required this.pausePosition,
    required this.pauseTime,
  });

  /// Get pause duration
  Duration get pauseDuration => DateTime.now().difference(pauseTime);
}

/// Playback completion result
class PlaybackComplete {
  final PlaybackSession session;
  final Duration finalPosition;
  final Duration totalPlayTime;
  final bool wasCompleted;

  const PlaybackComplete({
    required this.session,
    required this.finalPosition,
    required this.totalPlayTime,
    required this.wasCompleted,
  });

  /// Get playback statistics
  PlaybackStatistics get statistics => PlaybackStatistics(
    totalDuration: session.recording.duration,
    playedDuration: finalPosition,
    totalPlayTime: totalPlayTime,
    playbackRate: session.playbackRate,
    wasCompleted: wasCompleted,
  );
}

/// Playback statistics
class PlaybackStatistics {
  final Duration totalDuration;
  final Duration playedDuration;
  final Duration totalPlayTime;
  final double playbackRate;
  final bool wasCompleted;

  const PlaybackStatistics({
    required this.totalDuration,
    required this.playedDuration,
    required this.totalPlayTime,
    required this.playbackRate,
    required this.wasCompleted,
  });

  /// Get completion percentage
  double get completionPercentage {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (playedDuration.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Check if recording was mostly played
  bool get wasMostlyPlayed => completionPercentage >= 0.8;
}

/// Recording failure types for error handling
class RecordingFailure {
  final String message;
  final RecordingFailureType type;

  const RecordingFailure._(this.message, this.type);

  factory RecordingFailure.audioServiceError(String message) =>
      RecordingFailure._(message, RecordingFailureType.audioService);

  factory RecordingFailure.recordingError(String message) =>
      RecordingFailure._(message, RecordingFailureType.recording);

  factory RecordingFailure.unexpected(String message) =>
      RecordingFailure._(message, RecordingFailureType.unexpected);

  @override
  String toString() => 'RecordingFailure: $message (${type.name})';
}

/// Types of recording failures
enum RecordingFailureType {
  audioService,
  recording,
  unexpected,
}