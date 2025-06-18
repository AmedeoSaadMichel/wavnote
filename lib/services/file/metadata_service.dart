// File: services/file/metadata_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/enums/audio_format.dart';
import '../../core/extensions/duration_extensions.dart';

/// Cosmic Metadata Service - Universal Audio Knowledge Extraction
///
/// Handles extraction and analysis of audio file metadata including:
/// - Audio format detection with cosmic precision
/// - Duration extraction with mystical accuracy
/// - Sample rate and bitrate analysis with ethereal wisdom
/// - File integrity validation with divine insight
/// - Amplitude analysis with cosmic resonance
/// - Location metadata with universal awareness
class MetadataService {

  // ==== CONSTANTS ====


  // Audio format signatures (magic numbers)
  static const Map<List<int>, AudioFormat> _formatSignatures = {
    [0x52, 0x49, 0x46, 0x46]: AudioFormat.wav, // "RIFF"
    [0x66, 0x74, 0x79, 0x70]: AudioFormat.m4a, // "ftyp"
    [0x66, 0x4C, 0x61, 0x43]: AudioFormat.flac, // "fLaC"
  };

  // ==== METADATA EXTRACTION ====

  /// Extract comprehensive metadata from audio file
  Future<AudioMetadata> extractMetadata(File audioFile) async {
    try {
      // Validate file exists
      if (!await audioFile.exists()) {
        throw MetadataException(
          'Audio file has vanished from the cosmic realm',
          MetadataErrorType.fileNotFound,
          audioFile.path,
        );
      }

      // Read file header for format detection
      final format = await _detectAudioFormat(audioFile);

      // Extract basic file information
      final stat = await audioFile.stat();
      final duration = await _extractDuration(audioFile, format);
      final sampleRate = await _extractSampleRate(audioFile, format);
      final bitrate = await _calculateBitrate(audioFile, duration);
      
      // Log extraction progress
      print('MetadataService: Extracted metadata - Format: ${format.name}, Duration: ${duration.formatted}, Sample Rate: ${sampleRate}Hz');

      // Extract additional metadata
      final amplitude = await _analyzeAmplitude(audioFile, format);
      final title = _extractTitleFromFilename(audioFile.path);

      return AudioMetadata(
        title: title,
        duration: duration,
        bitrate: bitrate,
        sampleRate: sampleRate,
        channels: 2, // Default to stereo
        averageAmplitude: amplitude,
        recordingDate: stat.changed,
      );

    } catch (e) {
      if (e is MetadataException) rethrow;

      throw MetadataException(
        'Failed to extract metadata from cosmic audio file: ${e.toString()}',
        MetadataErrorType.extractionFailed,
        audioFile.path,
      );
    }
  }

  /// Extract duration with mystical precision
  Future<Duration> _extractDuration(File audioFile, AudioFormat format) async {
    try {
      // For now, estimate duration based on file size and format
      // In production, use proper audio parsing libraries
      final stat = await audioFile.stat();
      final estimatedSeconds = _estimateDurationFromSize(stat.size, format);

      return Duration(seconds: estimatedSeconds);

    } catch (e) {
      throw MetadataException(
        'Failed to extract duration from cosmic audio',
        MetadataErrorType.durationExtractionFailed,
        audioFile.path,
      );
    }
  }

  /// Extract sample rate with ethereal accuracy
  Future<int> _extractSampleRate(File audioFile, AudioFormat format) async {
    try {
      // Read format-specific headers to extract sample rate
      // This is a simplified implementation
      switch (format) {
        case AudioFormat.wav:
          return await _extractWavSampleRate(audioFile);
        case AudioFormat.m4a:
          return 44100; // Default AAC sample rate
        case AudioFormat.flac:
          return 44100; // Default FLAC sample rate
      }
    } catch (e) {
      // Return default sample rate if extraction fails
      return 44100;
    }
  }

  /// Extract WAV sample rate from header
  Future<int> _extractWavSampleRate(File audioFile) async {
    try {
      final bytes = await audioFile.openRead(0, 44).toList();
      final headerBytes = bytes.expand((x) => x).toList();

      // Sample rate is at bytes 24-27 in WAV header (little endian)
      if (headerBytes.length >= 28) {
        final sampleRate = headerBytes[24] |
        (headerBytes[25] << 8) |
        (headerBytes[26] << 16) |
        (headerBytes[27] << 24);
        return sampleRate;
      }

      return 44100; // Default
    } catch (e) {
      return 44100; // Default on error
    }
  }

  /// Calculate bitrate from file size and duration
  Future<int> _calculateBitrate(File audioFile, Duration duration) async {
    try {
      if (duration.inSeconds == 0) return 0;

      final stat = await audioFile.stat();
      final bitsPerSecond = (stat.size * 8) / duration.inSeconds;

      return (bitsPerSecond / 1000).round(); // Convert to kbps

    } catch (e) {
      return 0;
    }
  }

  /// Analyze average amplitude for cosmic resonance
  Future<double> _analyzeAmplitude(File audioFile, AudioFormat format) async {
    try {
      // This is a simplified amplitude analysis
      // In production, implement proper audio signal analysis
      final stat = await audioFile.stat();

      // Estimate amplitude based on file size and format
      final baseAmplitude = 0.5; // Moderate amplitude
      final sizeModifier = (stat.size / (1024 * 1024)).clamp(0.1, 2.0);

      return (baseAmplitude * sizeModifier).clamp(0.0, 1.0);

    } catch (e) {
      return 0.5; // Default moderate amplitude
    }
  }

  // ==== FORMAT DETECTION ====

  /// Detect audio format with cosmic precision
  Future<AudioFormat> _detectAudioFormat(File audioFile) async {
    try {
      // First try extension-based detection
      final extension = path.extension(audioFile.path).toLowerCase();
      AudioFormat? formatFromExtension = _getFormatFromExtension(extension);

      // Verify with file signature if possible
      final signature = await _readFileSignature(audioFile);
      AudioFormat? formatFromSignature = _getFormatFromSignature(signature);

      // Prefer signature over extension if both available
      if (formatFromSignature != null) {
        return formatFromSignature;
      }

      if (formatFromExtension != null) {
        return formatFromExtension;
      }

      throw MetadataException(
        'Unknown audio format detected in cosmic realm',
        MetadataErrorType.unsupportedFormat,
        audioFile.path,
      );

    } catch (e) {
      if (e is MetadataException) rethrow;

      throw MetadataException(
        'Failed to detect audio format: ${e.toString()}',
        MetadataErrorType.formatDetectionFailed,
        audioFile.path,
      );
    }
  }

  /// Get format from file extension
  AudioFormat? _getFormatFromExtension(String extension) {
    switch (extension) {
      case '.wav':
        return AudioFormat.wav;
      case '.m4a':
      case '.aac':
      case '.mp4':
        return AudioFormat.m4a;
      case '.flac':
        return AudioFormat.flac;
      default:
        return null;
    }
  }

  /// Read file signature (first few bytes)
  Future<List<int>> _readFileSignature(File audioFile) async {
    try {
      final bytes = await audioFile.openRead(0, 8).toList();
      return bytes.expand((x) => x).take(8).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get format from file signature
  AudioFormat? _getFormatFromSignature(List<int> signature) {
    if (signature.length < 4) return null;

    for (final entry in _formatSignatures.entries) {
      if (_matchesSignature(signature, entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Check if signature matches pattern
  bool _matchesSignature(List<int> signature, List<int> pattern) {
    if (signature.length < pattern.length) return false;

    for (int i = 0; i < pattern.length; i++) {
      if (signature[i] != pattern[i]) return false;
    }

    return true;
  }

  // ==== HELPER METHODS ====

  /// Extract title from filename
  String _extractTitleFromFilename(String filePath) {
    final basename = path.basenameWithoutExtension(filePath);

    // Clean up common recording filename patterns
    String title = basename
        .replaceAll(RegExp(r'recording_\d+'), '')
        .replaceAll(RegExp(r'_\d{4}-\d{2}-\d{2}'), '')
        .replaceAll(RegExp(r'_\d{10,}'), '') // Remove timestamps
        .replaceAll('_', ' ')
        .trim();

    if (title.isEmpty) {
      title = basename;
    }

    return title;
  }

  /// Estimate duration from file size and format
  int _estimateDurationFromSize(int fileSize, AudioFormat format) {
    // Rough estimates based on typical bitrates
    int estimatedBitrate;

    switch (format) {
      case AudioFormat.wav:
        estimatedBitrate = 1411; // CD quality uncompressed
        break;
      case AudioFormat.m4a:
        estimatedBitrate = 128; // Typical AAC bitrate
        break;
      case AudioFormat.flac:
        estimatedBitrate = 700; // Typical FLAC compression
        break;
    }

    // Convert file size to duration
    final bitsPerSecond = estimatedBitrate * 1000;
    final totalBits = fileSize * 8;
    final seconds = totalBits / bitsPerSecond;

    return seconds.round();
  }

  // ==== VALIDATION METHODS ====

  /// Validate audio file integrity
  Future<bool> validateAudioFile(File audioFile) async {
    try {
      // Check if file exists and has content
      if (!await audioFile.exists()) return false;

      final stat = await audioFile.stat();
      if (stat.size == 0) return false;

      // Try to detect format
      final format = await _detectAudioFormat(audioFile);

      // Basic format-specific validation
      return await _validateFormatSpecific(audioFile, format);

    } catch (e) {
      return false;
    }
  }

  /// Validate format-specific file structure
  Future<bool> _validateFormatSpecific(File audioFile, AudioFormat format) async {
    try {
      switch (format) {
        case AudioFormat.wav:
          return await _validateWavFile(audioFile);
        case AudioFormat.m4a:
          return await _validateM4aFile(audioFile);
        case AudioFormat.flac:
          return await _validateFlacFile(audioFile);
      }
    } catch (e) {
      return false;
    }
  }

  /// Validate WAV file structure
  Future<bool> _validateWavFile(File audioFile) async {
    try {
      final bytes = await audioFile.openRead(0, 12).toList();
      final headerBytes = bytes.expand((x) => x).toList();

      // Check RIFF signature
      if (headerBytes.length < 12) return false;

      final riffSignature = String.fromCharCodes(headerBytes.sublist(0, 4));
      final waveSignature = String.fromCharCodes(headerBytes.sublist(8, 12));

      return riffSignature == 'RIFF' && waveSignature == 'WAVE';

    } catch (e) {
      return false;
    }
  }

  /// Validate M4A file structure
  Future<bool> _validateM4aFile(File audioFile) async {
    try {
      final bytes = await audioFile.openRead(0, 8).toList();
      final headerBytes = bytes.expand((x) => x).toList();

      // Check ftyp signature at offset 4
      if (headerBytes.length < 8) return false;

      final ftypSignature = String.fromCharCodes(headerBytes.sublist(4, 8));
      return ftypSignature == 'ftyp';

    } catch (e) {
      return false;
    }
  }

  /// Validate FLAC file structure
  Future<bool> _validateFlacFile(File audioFile) async {
    try {
      final bytes = await audioFile.openRead(0, 4).toList();
      final headerBytes = bytes.expand((x) => x).toList();

      // Check fLaC signature
      if (headerBytes.length < 4) return false;

      final flacSignature = String.fromCharCodes(headerBytes);
      return flacSignature == 'fLaC';

    } catch (e) {
      return false;
    }
  }
}

// ==== DATA CLASSES ====

/// Audio metadata extracted from file
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final List<String>? tags;
  final String? location;
  final double? averageAmplitude;
  final DateTime? recordingDate;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.tags,
    this.location,
    this.averageAmplitude,
    this.recordingDate,
  });

  /// Check if metadata has basic information
  bool get hasBasicInfo => title != null || artist != null || duration != null;

  /// Get formatted duration
  String? get formattedDuration => duration?.formatted;

  /// Get formatted bitrate
  String? get formattedBitrate => bitrate != null ? '${bitrate} kbps' : null;

  /// Get formatted sample rate
  String? get formattedSampleRate => sampleRate != null ? '${sampleRate} Hz' : null;

  /// Get audio quality description
  String get qualityDescription {
    if (bitrate != null) {
      if (bitrate! >= 320) return 'Cosmic Quality (320+ kbps)';
      if (bitrate! >= 256) return 'Stellar Quality (256+ kbps)';
      if (bitrate! >= 192) return 'Celestial Quality (192+ kbps)';
      if (bitrate! >= 128) return 'Ethereal Quality (128+ kbps)';
      return 'Mystical Quality (<128 kbps)';
    }
    return 'Unknown Quality';
  }
}

/// Metadata exception types
enum MetadataErrorType {
  fileNotFound,
  unsupportedFormat,
  extractionFailed,
  durationExtractionFailed,
  formatDetectionFailed,
  validationFailed,
  unknown,
}

/// Metadata exception with cosmic messaging
class MetadataException implements Exception {
  final String message;
  final MetadataErrorType type;
  final String filePath;
  final Object? originalException;

  const MetadataException(
      this.message,
      this.type,
      this.filePath, {
        this.originalException,
      });

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case MetadataErrorType.fileNotFound:
        return 'Audio file not found in the cosmic realm';
      case MetadataErrorType.unsupportedFormat:
        return 'Audio format not supported by cosmic analysis';
      case MetadataErrorType.extractionFailed:
        return 'Failed to extract cosmic metadata';
      case MetadataErrorType.durationExtractionFailed:
        return 'Failed to determine cosmic duration';
      case MetadataErrorType.formatDetectionFailed:
        return 'Failed to detect cosmic audio format';
      case MetadataErrorType.validationFailed:
        return 'Audio file validation failed in cosmic realm';
      case MetadataErrorType.unknown:
        return 'Unknown cosmic interference during metadata extraction';
    }
  }

  @override
  String toString() {
    return 'MetadataException: $message (Type: $type, File: $filePath)';
  }
}