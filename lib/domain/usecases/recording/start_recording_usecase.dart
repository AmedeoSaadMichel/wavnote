// File: domain/usecases/recording/start_recording_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../repositories/i_audio_service_repository.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/date_formatter.dart';
import 'dart:io';

/// Use case for starting a new audio recording
///
/// Handles the complete flow of recording initialization including:
/// - Permission validation
/// - File path generation
/// - Audio service configuration
/// - Recording start
/// - State management
class StartRecordingUseCase {
  final IRecordingRepository _recordingRepository;
  final IAudioServiceRepository _audioServiceRepository;

  const StartRecordingUseCase({
    required IRecordingRepository recordingRepository,
    required IAudioServiceRepository audioServiceRepository,
  })  : _recordingRepository = recordingRepository,
        _audioServiceRepository = audioServiceRepository;

  /// Start a new recording
  Future<Either<RecordingFailure, RecordingSession>> execute(
      StartRecordingParams params,
      ) async {
    try {
      // 1. Check permissions
      final permissionResult = await _checkPermissions();
      if (permissionResult.isLeft()) {
        return Left(permissionResult.fold((l) => l, (r) => throw Exception()));
      }

      // 2. Generate file path
      final filePathResult = await _generateFilePath(params);
      if (filePathResult.isLeft()) {
        return Left(filePathResult.fold((l) => l, (r) => throw Exception()));
      }
      final filePath = filePathResult.fold((l) => throw Exception(), (r) => r);

      // 3. Initialize audio service
      final initResult = await _initializeAudioService();
      if (initResult.isLeft()) {
        return Left(initResult.fold((l) => l, (r) => throw Exception()));
      }

      // 4. Start recording
      final recordingResult = await _startRecording(filePath, params);
      if (recordingResult.isLeft()) {
        return Left(recordingResult.fold((l) => l, (r) => throw Exception()));
      }

      // 5. Create recording session
      final session = RecordingSession(
        filePath: filePath,
        folderId: params.folderId,
        format: params.format,
        sampleRate: params.sampleRate,
        bitRate: params.bitRate,
        startTime: DateTime.now(),
        customName: params.customName,
        latitude: params.latitude,
        longitude: params.longitude,
        locationName: params.locationName,
        tags: params.tags,
      );

      return Right(session);
    } catch (e) {
      return Left(RecordingFailure.unexpected(e.toString()));
    }
  }

  /// Check microphone permissions
  Future<Either<RecordingFailure, void>> _checkPermissions() async {
    try {
      final hasMicrophonePermission = await _audioServiceRepository.hasMicrophonePermission();

      if (!hasMicrophonePermission) {
        final permissionGranted = await _audioServiceRepository.requestMicrophonePermission();
        if (!permissionGranted) {
          return Left(RecordingFailure.permissionError('Microphone permission denied'));
        }
      }

      final hasMicrophone = await _audioServiceRepository.hasMicrophone();
      if (!hasMicrophone) {
        return Left(RecordingFailure.deviceError('No microphone found on device'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.permissionError('Failed to check permissions: $e'));
    }
  }

  /// Generate unique file path for recording
  Future<Either<RecordingFailure, String>> _generateFilePath(
      StartRecordingParams params,
      ) async {
    try {
      // Get recordings directory
      final recordingsDir = await FileUtils.getRecordingsDirectory();

      // Create folder-specific subdirectory if needed
      final folderDir = Directory('${recordingsDir.path}/${params.folderId}');
      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }

      // Generate filename
      final timestamp = DateFormatter.formatTimestamp(DateTime.now());
      final extension = params.format.fileExtension;
      final filename = params.customName?.isNotEmpty == true
          ? '${params.customName!}_$timestamp.$extension'
          : 'recording_$timestamp.$extension';

      final filePath = '${folderDir.path}/$filename';

      // Ensure file doesn't already exist
      final file = File(filePath);
      if (await file.exists()) {
        return Left(RecordingFailure.fileSystemError('File already exists: $filePath'));
      }

      return Right(filePath);
    } catch (e) {
      return Left(RecordingFailure.fileSystemError('Failed to generate file path: $e'));
    }
  }

  /// Initialize audio service for recording
  Future<Either<RecordingFailure, void>> _initializeAudioService() async {
    try {
      final isInitialized = await _audioServiceRepository.initialize();
      if (!isInitialized) {
        return Left(RecordingFailure.audioServiceError('Failed to initialize audio service'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError('Audio service initialization error: $e'));
    }
  }

  /// Start the actual recording
  Future<Either<RecordingFailure, void>> _startRecording(
      String filePath,
      StartRecordingParams params,
      ) async {
    try {
      final success = await _audioServiceRepository.startRecording(
        filePath: filePath,
        format: params.format,
        sampleRate: params.sampleRate,
        bitRate: params.bitRate,
      );

      if (!success) {
        return Left(RecordingFailure.audioServiceError('Failed to start recording'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.audioServiceError('Recording start error: $e'));
    }
  }
}

/// Parameters for starting a recording
class StartRecordingParams {
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final String? customName;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<String> tags;

  const StartRecordingParams({
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    this.customName,
    this.latitude,
    this.longitude,
    this.locationName,
    this.tags = const [],
  });
}

/// Active recording session data
class RecordingSession {
  final String filePath;
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final DateTime startTime;
  final String? customName;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<String> tags;

  const RecordingSession({
    required this.filePath,
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.startTime,
    this.customName,
    this.latitude,
    this.longitude,
    this.locationName,
    this.tags = const [],
  });

  /// Get current recording duration
  Duration get currentDuration => DateTime.now().difference(startTime);

  /// Get formatted duration string
  String get formattedDuration => DateFormatter.formatDuration(currentDuration);
}

/// Recording failure types for error handling
class RecordingFailure {
  final String message;
  final RecordingFailureType type;

  const RecordingFailure._(this.message, this.type);

  factory RecordingFailure.audioServiceError(String message) =>
      RecordingFailure._(message, RecordingFailureType.audioService);

  factory RecordingFailure.permissionError(String message) =>
      RecordingFailure._(message, RecordingFailureType.permission);

  factory RecordingFailure.deviceError(String message) =>
      RecordingFailure._(message, RecordingFailureType.device);

  factory RecordingFailure.fileSystemError(String message) =>
      RecordingFailure._(message, RecordingFailureType.fileSystem);

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
  permission,
  device,
  fileSystem,
  recording,
  unexpected,
}