// File: domain/usecases/recording/stop_recording_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../repositories/i_folder_repository.dart';
import '../../repositories/i_audio_service_repository.dart';
import '../../../core/utils/file_utils.dart';
import 'start_recording_usecase.dart';
import 'pause_recording_usecase.dart';
import 'create_recording_usecase.dart';
import 'dart:io';

/// Use case for stopping audio recording and saving it
///
/// Handles the complete flow of recording completion including:
/// - Recording finalization
/// - File validation and processing
/// - Database storage
/// - Folder count updates
/// - Cleanup operations
/// - Error recovery
class StopRecordingUseCase {
  final IRecordingRepository _recordingRepository;
  final IFolderRepository _folderRepository;
  final IAudioServiceRepository _audioServiceRepository;
  final CreateRecordingUseCase _createRecordingUseCase;

  const StopRecordingUseCase({
    required IRecordingRepository recordingRepository,
    required IFolderRepository folderRepository,
    required IAudioServiceRepository audioServiceRepository,
    required CreateRecordingUseCase createRecordingUseCase,
  })  : _recordingRepository = recordingRepository,
        _folderRepository = folderRepository,
        _audioServiceRepository = audioServiceRepository,
        _createRecordingUseCase = createRecordingUseCase;

  /// Stop active recording and save it
  Future<Either<RecordingFailure, StopRecordingResult>> execute(
      StopRecordingParams params,
      ) async {
    try {
      // 1. Validate recording session
      final validationResult = await _validateRecordingSession(params);
      if (validationResult.isLeft()) {
        return Left(validationResult.fold((l) => l, (r) => throw Exception()));
      }

      // 2. Stop audio recording service
      final recordingEntity = await _audioServiceRepository.stopRecording();
      if (recordingEntity == null) {
        return Left(RecordingFailure.audioServiceError('Failed to stop recording - no recording data returned'));
      }

      // 3. Validate recorded file
      final fileValidationResult = await _validateRecordedFile(recordingEntity);
      if (fileValidationResult.isLeft()) {
        await _cleanupFailedRecording(recordingEntity.filePath);
        return Left(fileValidationResult.fold((l) => l, (r) => throw Exception()));
      }

      // 4. Calculate effective recording duration (excluding pauses)
      final effectiveDuration = _calculateEffectiveDuration(params, recordingEntity.duration);

      // 5. Process and save recording
      final processingResult = await _processAndSaveRecording(
        params,
        recordingEntity,
        effectiveDuration,
      );
      if (processingResult.isLeft()) {
        await _cleanupFailedRecording(recordingEntity.filePath);
        return Left(processingResult.fold((l) => l, (r) => throw Exception()));
      }

      final savedRecording = processingResult.fold((l) => throw Exception(), (r) => r);

      // 6. Update folder count
      await _updateFolderCount(params.session.folderId);

      // 7. Cleanup audio service
      await _audioServiceRepository.dispose();

      // 8. Create stop result
      final result = StopRecordingResult(
        recording: savedRecording,
        session: params.session,
        stoppedAt: DateTime.now(),
        effectiveDuration: effectiveDuration,
        totalSessionDuration: recordingEntity.duration,
        totalPausedDuration: _calculateTotalPausedDuration(params),
        wasCompleted: true,
      );

      return Right(result);
    } catch (e) {
      // Cleanup on any error
      if (params.session.filePath.isNotEmpty) {
        await _cleanupFailedRecording(params.session.filePath);
      }
      return Left(RecordingFailure.unexpected('Failed to stop recording: $e'));
    }
  }

  /// Cancel active recording without saving
  Future<Either<RecordingFailure, CancelRecordingResult>> cancel(
      CancelRecordingParams params,
      ) async {
    try {
      // 1. Validate recording session
      final isRecording = await _audioServiceRepository.isRecording();
      if (!isRecording) {
        return Left(RecordingFailure.stateError('No active recording to cancel'));
      }

      // 2. Get current duration before canceling
      final currentDuration = await _audioServiceRepository.getCurrentRecordingDuration();

      // 3. Cancel recording
      final cancelResult = await _audioServiceRepository.cancelRecording();
      if (!cancelResult) {
        return Left(RecordingFailure.audioServiceError('Failed to cancel recording'));
      }

      // 4. Cleanup recording file
      await _cleanupFailedRecording(params.session.filePath);

      // 5. Cleanup audio service
      await _audioServiceRepository.dispose();

      // 6. Create cancel result
      final result = CancelRecordingResult(
        session: params.session,
        canceledAt: DateTime.now(),
        recordedDuration: currentDuration,
        totalPausedDuration: _calculateTotalPausedDuration(CancelRecordingParams(session: params.session, pausedSession: params.pausedSession)),
        reason: params.reason,
      );

      return Right(result);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to cancel recording: $e'));
    }
  }

  /// Validate recording session before stopping
  Future<Either<RecordingFailure, void>> _validateRecordingSession(
      StopRecordingParams params,
      ) async {
    try {
      final isRecording = await _audioServiceRepository.isRecording();
      if (!isRecording) {
        return Left(RecordingFailure.stateError('No active recording to stop'));
      }

      // Check minimum recording duration
      final currentDuration = await _audioServiceRepository.getCurrentRecordingDuration();
      if (currentDuration.inSeconds < 1) {
        return Left(RecordingFailure.validationError('Recording too short (minimum 1 second)'));
      }

      // Validate session data
      if (params.session.filePath.isEmpty) {
        return Left(RecordingFailure.stateError('Invalid recording session - no file path'));
      }

      if (params.session.folderId.isEmpty) {
        return Left(RecordingFailure.stateError('Invalid recording session - no folder ID'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.stateError('Failed to validate recording session: $e'));
    }
  }

  /// Validate recorded file
  Future<Either<RecordingFailure, void>> _validateRecordedFile(
      RecordingEntity recordingEntity,
      ) async {
    try {
      final file = File(recordingEntity.filePath);

      // Check file exists
      if (!await file.exists()) {
        return Left(RecordingFailure.fileSystemError('Recording file was not created'));
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        return Left(RecordingFailure.fileSystemError('Recording file is empty'));
      }

      // Check minimum file size (1KB)
      if (fileSize < 1024) {
        return Left(RecordingFailure.validationError('Recording file too small (${fileSize} bytes)'));
      }

      // Check maximum file size (500MB)
      const maxFileSize = 500 * 1024 * 1024;
      if (fileSize > maxFileSize) {
        return Left(RecordingFailure.validationError('Recording file too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB)'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.fileSystemError('Failed to validate recording file: $e'));
    }
  }

  /// Calculate total paused duration
  Duration _calculateTotalPausedDuration(dynamic params) {
    if (params.pausedSession != null) {
      final pauseDuration = DateTime.now().difference(params.pausedSession.pausedAt);
      return params.pausedSession.totalPausedDuration + pauseDuration;
    }
    return Duration.zero;
  }

  /// Calculate effective recording duration excluding pauses
  Duration _calculateEffectiveDuration(
      StopRecordingParams params,
      Duration totalDuration,
      ) {
    final totalPaused = _calculateTotalPausedDuration(params);
    final effective = totalDuration - totalPaused;

    // Ensure positive duration
    return effective.isNegative ? Duration.zero : effective;
  }

  /// Process and save recording to database
  Future<Either<RecordingFailure, RecordingEntity>> _processAndSaveRecording(
      StopRecordingParams params,
      RecordingEntity recordingEntity,
      Duration effectiveDuration,
      ) async {
    try {
      // Get actual file size
      final file = File(recordingEntity.filePath);
      final actualFileSize = await file.length();

      // Generate recording name
      final recordingName = params.customName?.isNotEmpty == true
          ? params.customName!
          : _generateDefaultRecordingName(params.session);

      // Create recording using the create use case
      final createResult = await _createRecordingUseCase.execute(
        name: recordingName,
        filePath: recordingEntity.filePath,
        folderId: params.session.folderId,
        format: params.session.format,
        duration: effectiveDuration, // Use effective duration
        fileSize: actualFileSize,
        sampleRate: params.session.sampleRate,
        latitude: params.session.latitude,
        longitude: params.session.longitude,
        locationName: params.session.locationName,
        tags: params.session.tags,
      );

      if (createResult.isFailure) {
        return Left(RecordingFailure.databaseError(createResult.error!));
      }

      return Right(createResult.recording!);
    } catch (e) {
      return Left(RecordingFailure.databaseError('Failed to save recording: $e'));
    }
  }

  /// Generate default recording name
  String _generateDefaultRecordingName(RecordingSession session) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return 'Recording ${now.year}-$month-$day $hour:$minute';
  }

  /// Update folder recording count
  Future<void> _updateFolderCount(String folderId) async {
    try {
      await _folderRepository.incrementFolderCount(folderId);
    } catch (e) {
      // Log error but don't fail the operation
      print('Warning: Failed to update folder count: $e');
    }
  }

  /// Cleanup failed recording file
  Future<void> _cleanupFailedRecording(String filePath) async {
    try {
      if (filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Warning: Failed to cleanup recording file: $e');
    }
  }
}

/// Parameters for stopping recording
class StopRecordingParams {
  final RecordingSession session;
  final PausedRecordingSession? pausedSession;
  final String? customName;

  const StopRecordingParams({
    required this.session,
    this.pausedSession,
    this.customName,
  });

  /// Create params from active session
  factory StopRecordingParams.fromActive(
      RecordingSession session, {
        String? customName,
      }) {
    return StopRecordingParams(
      session: session,
      customName: customName,
    );
  }

  /// Create params from paused session
  factory StopRecordingParams.fromPaused(
      PausedRecordingSession pausedSession, {
        String? customName,
      }) {
    return StopRecordingParams(
      session: pausedSession.originalSession,
      pausedSession: pausedSession,
      customName: customName,
    );
  }
}

/// Parameters for canceling recording
class CancelRecordingParams {
  final RecordingSession session;
  final PausedRecordingSession? pausedSession;
  final String reason;

  const CancelRecordingParams({
    required this.session,
    this.pausedSession,
    this.reason = 'User canceled',
  });

  /// Create params from active session
  factory CancelRecordingParams.fromActive(
      RecordingSession session, {
        String reason = 'User canceled',
      }) {
    return CancelRecordingParams(
      session: session,
      reason: reason,
    );
  }

  /// Create params from paused session
  factory CancelRecordingParams.fromPaused(
      PausedRecordingSession pausedSession, {
        String reason = 'User canceled',
      }) {
    return CancelRecordingParams(
      session: pausedSession.originalSession,
      pausedSession: pausedSession,
      reason: reason,
    );
  }
}

/// Result of stopping recording
class StopRecordingResult {
  final RecordingEntity recording;
  final RecordingSession session;
  final DateTime stoppedAt;
  final Duration effectiveDuration;
  final Duration totalSessionDuration;
  final Duration totalPausedDuration;
  final bool wasCompleted;

  const StopRecordingResult({
    required this.recording,
    required this.session,
    required this.stoppedAt,
    required this.effectiveDuration,
    required this.totalSessionDuration,
    required this.totalPausedDuration,
    required this.wasCompleted,
  });

  /// Get recording efficiency (effective vs total time)
  double get recordingEfficiency {
    if (totalSessionDuration.inMilliseconds == 0) return 1.0;
    return effectiveDuration.inMilliseconds / totalSessionDuration.inMilliseconds;
  }

  /// Get formatted effective duration
  String get effectiveDurationFormatted {
    final minutes = effectiveDuration.inMinutes;
    final seconds = effectiveDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted total session duration
  String get totalSessionDurationFormatted {
    final minutes = totalSessionDuration.inMinutes;
    final seconds = totalSessionDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted paused duration
  String get pausedDurationFormatted {
    final minutes = totalPausedDuration.inMinutes;
    final seconds = totalPausedDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if recording had significant pauses
  bool get hadSignificantPauses => totalPausedDuration.inSeconds > 10;

  /// Get recording summary
  String get summary {
    if (hadSignificantPauses) {
      return 'Recorded ${effectiveDurationFormatted} (${totalSessionDurationFormatted} total, ${pausedDurationFormatted} paused)';
    } else {
      return 'Recorded ${effectiveDurationFormatted}';
    }
  }

  /// Get recording statistics
  RecordingStatistics get statistics => RecordingStatistics(
    effectiveDuration: effectiveDuration,
    totalSessionDuration: totalSessionDuration,
    pausedDuration: totalPausedDuration,
    efficiency: recordingEfficiency,
    fileSize: recording.fileSize,
    sampleRate: recording.sampleRate,
  );
}

/// Result of canceling recording
class CancelRecordingResult {
  final RecordingSession session;
  final DateTime canceledAt;
  final Duration recordedDuration;
  final Duration totalPausedDuration;
  final String reason;

  const CancelRecordingResult({
    required this.session,
    required this.canceledAt,
    required this.recordedDuration,
    required this.totalPausedDuration,
    required this.reason,
  });

  /// Get formatted recorded duration
  String get recordedDurationFormatted {
    final minutes = recordedDuration.inMinutes;
    final seconds = recordedDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get session summary
  String get summary {
    return 'Canceled after ${recordedDurationFormatted} - $reason';
  }

  /// Check if significant recording was lost
  bool get significantRecordingLost => recordedDuration.inSeconds > 30;
}

/// Recording statistics
class RecordingStatistics {
  final Duration effectiveDuration;
  final Duration totalSessionDuration;
  final Duration pausedDuration;
  final double efficiency;
  final int fileSize;
  final int sampleRate;

  const RecordingStatistics({
    required this.effectiveDuration,
    required this.totalSessionDuration,
    required this.pausedDuration,
    required this.efficiency,
    required this.fileSize,
    required this.sampleRate,
  });

  /// Get file size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get efficiency percentage
  String get efficiencyPercentage => '${(efficiency * 100).toStringAsFixed(1)}%';

  /// Get quality description
  String get qualityDescription {
    if (sampleRate >= 48000) return 'High Quality';
    if (sampleRate >= 44100) return 'CD Quality';
    if (sampleRate >= 22050) return 'Good Quality';
    return 'Basic Quality';
  }

  /// Get average bitrate (approximate)
  int get approximateBitrate {
    if (effectiveDuration.inSeconds == 0) return 0;
    return ((fileSize * 8) / effectiveDuration.inSeconds).round();
  }
}

/// Recording failure types for error handling
class RecordingFailure {
  final String message;
  final RecordingFailureType type;

  const RecordingFailure._(this.message, this.type);

  factory RecordingFailure.audioServiceError(String message) =>
      RecordingFailure._(message, RecordingFailureType.audioService);

  factory RecordingFailure.stateError(String message) =>
      RecordingFailure._(message, RecordingFailureType.state);

  factory RecordingFailure.fileSystemError(String message) =>
      RecordingFailure._(message, RecordingFailureType.fileSystem);

  factory RecordingFailure.validationError(String message) =>
      RecordingFailure._(message, RecordingFailureType.validation);

  factory RecordingFailure.databaseError(String message) =>
      RecordingFailure._(message, RecordingFailureType.database);

  factory RecordingFailure.unexpected(String message) =>
      RecordingFailure._(message, RecordingFailureType.unexpected);

  @override
  String toString() => 'RecordingFailure: $message (${type.name})';
}

/// Types of recording failures
enum RecordingFailureType {
  audioService,
  state,
  fileSystem,
  validation,
  database,
  unexpected,
}