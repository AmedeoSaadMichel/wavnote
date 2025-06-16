// File: domain/usecases/recording/create_recording_usecase.dart
import '../../entities/recording_entity.dart';
import '../../entities/folder_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../repositories/i_folder_repository.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/utils/file_utils.dart';

/// Use case for creating and saving a new recording
///
/// Handles the complete recording creation process including
/// file management, database storage, and folder count updates.
class CreateRecordingUseCase {
  final IRecordingRepository _recordingRepository;
  final IFolderRepository _folderRepository;

  CreateRecordingUseCase({
    required IRecordingRepository recordingRepository,
    required IFolderRepository folderRepository,
  }) : _recordingRepository = recordingRepository,
        _folderRepository = folderRepository;

  /// Create a new recording and save it to the specified folder
  Future<RecordingResult> execute({
    required String name,
    required String filePath,
    required String folderId,
    required AudioFormat format,
    required Duration duration,
    required int fileSize,
    required int sampleRate,
    double? latitude,
    double? longitude,
    String? locationName,
    List<String> tags = const [],
  }) async {
    try {
      // Validate inputs
      final validation = _validateInputs(
        name: name,
        filePath: filePath,
        folderId: folderId,
        duration: duration,
        fileSize: fileSize,
      );

      if (!validation.isValid) {
        return RecordingResult.failure(validation.error!);
      }

      // Check if folder exists
      final folder = await _folderRepository.getFolderById(folderId);
      if (folder == null) {
        return RecordingResult.failure('Folder not found: $folderId');
      }

      // Check if folder can accept more recordings
      if (!folder.canAddRecording()) {
        return RecordingResult.failure('Folder has reached maximum recording limit');
      }

      // Verify file exists
      if (!await FileUtils.fileExists(filePath)) {
        return RecordingResult.failure('Recording file not found: $filePath');
      }

      // Create recording entity
      final recording = RecordingEntity.create(
        name: name.trim(),
        filePath: await FileUtils.getRelativePath(filePath),
        folderId: folderId,
        format: format,
        duration: duration,
        fileSize: fileSize,
        sampleRate: sampleRate,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        tags: tags,
      );

      // Save recording to database
      final savedRecording = await _recordingRepository.createRecording(recording);

      // Update folder count
      await _folderRepository.incrementFolderCount(folderId);

      return RecordingResult.success(savedRecording);

    } catch (e) {
      return RecordingResult.failure('Failed to create recording: ${e.toString()}');
    }
  }

  /// Create recording from audio service result
  Future<RecordingResult> createFromAudioService({
    required String filePath,
    required String folderId,
    required AudioFormat format,
    required Duration duration,
    required int sampleRate,
    String? customName,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      // Get file size
      final fileSize = await FileUtils.getFileSize(filePath);

      // Generate name if not provided
      final name = customName?.isNotEmpty == true
          ? customName!
          : _generateDefaultName();

      return await execute(
        name: name,
        filePath: filePath,
        folderId: folderId,
        format: format,
        duration: duration,
        fileSize: fileSize,
        sampleRate: sampleRate,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

    } catch (e) {
      return RecordingResult.failure('Failed to create recording from audio service: ${e.toString()}');
    }
  }

  /// Validate recording creation inputs
  ValidationResult _validateInputs({
    required String name,
    required String filePath,
    required String folderId,
    required Duration duration,
    required int fileSize,
  }) {
    // Validate name
    if (name.trim().isEmpty) {
      return ValidationResult.invalid('Recording name cannot be empty');
    }

    if (name.trim().length > 100) {
      return ValidationResult.invalid('Recording name cannot exceed 100 characters');
    }

    // Validate file path
    if (filePath.isEmpty) {
      return ValidationResult.invalid('File path cannot be empty');
    }

    // Validate folder ID
    if (folderId.isEmpty) {
      return ValidationResult.invalid('Folder ID cannot be empty');
    }

    // Validate duration
    if (duration.inSeconds <= 0) {
      return ValidationResult.invalid('Recording duration must be greater than 0');
    }

    if (duration.inHours > 24) {
      return ValidationResult.invalid('Recording duration cannot exceed 24 hours');
    }

    // Validate file size
    if (fileSize <= 0) {
      return ValidationResult.invalid('File size must be greater than 0');
    }

    const maxFileSize = 500 * 1024 * 1024; // 500MB
    if (fileSize > maxFileSize) {
      return ValidationResult.invalid('File size cannot exceed 500MB');
    }

    return ValidationResult.valid();
  }

  /// Generate default recording name
  String _generateDefaultName() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return 'Recording ${now.year}-$month-$day $hour:$minute';
  }
}

/// Result of recording creation operation
class RecordingResult {
  final bool isSuccess;
  final RecordingEntity? recording;
  final String? error;

  const RecordingResult._({
    required this.isSuccess,
    this.recording,
    this.error,
  });

  factory RecordingResult.success(RecordingEntity recording) {
    return RecordingResult._(
      isSuccess: true,
      recording: recording,
    );
  }

  factory RecordingResult.failure(String error) {
    return RecordingResult._(
      isSuccess: false,
      error: error,
    );
  }

  bool get isFailure => !isSuccess;
}

/// Result of input validation
class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult._({
    required this.isValid,
    this.error,
  });

  factory ValidationResult.valid() {
    return const ValidationResult._(isValid: true);
  }

  factory ValidationResult.invalid(String error) {
    return ValidationResult._(
      isValid: false,
      error: error,
    );
  }

  bool get isInvalid => !isValid;
}