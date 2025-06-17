// File: services/permission/permission_service.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Enhanced permission service for handling microphone and storage permissions
///
/// Provides robust permission checking and requesting with platform-specific
/// handling and detailed error information for the voice memo app.
class PermissionService {
  static const String _tag = 'PermissionService';

  // ==== MICROPHONE PERMISSIONS ====

  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    try {
      debugPrint('$_tag: Checking microphone permission...');

      final status = await Permission.microphone.status;
      final hasPermission = status == PermissionStatus.granted;

      debugPrint('$_tag: Microphone permission status: $status (granted: $hasPermission)');
      return hasPermission;

    } catch (e) {
      debugPrint('$_tag: Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission with detailed handling
  static Future<PermissionResult> requestMicrophonePermission() async {
    try {
      debugPrint('$_tag: Requesting microphone permission...');

      // Check current status first
      final currentStatus = await Permission.microphone.status;
      debugPrint('$_tag: Current microphone status: $currentStatus');

      // If already granted, return success
      if (currentStatus == PermissionStatus.granted) {
        debugPrint('$_tag: Microphone permission already granted');
        return PermissionResult.granted();
      }

      // If permanently denied, direct user to settings
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        debugPrint('$_tag: Microphone permission permanently denied');
        return PermissionResult.permanentlyDenied();
      }

      // Request permission
      debugPrint('$_tag: Showing permission request dialog...');
      final requestStatus = await Permission.microphone.request();
      debugPrint('$_tag: Permission request result: $requestStatus');

      // Handle the result
      switch (requestStatus) {
        case PermissionStatus.granted:
          debugPrint('$_tag: ✅ Microphone permission granted!');
          return PermissionResult.granted();

        case PermissionStatus.denied:
          debugPrint('$_tag: ❌ Microphone permission denied');
          return PermissionResult.denied();

        case PermissionStatus.permanentlyDenied:
          debugPrint('$_tag: ❌ Microphone permission permanently denied');
          return PermissionResult.permanentlyDenied();

        case PermissionStatus.restricted:
          debugPrint('$_tag: ❌ Microphone permission restricted (parental controls?)');
          return PermissionResult.restricted();

        case PermissionStatus.limited:
          debugPrint('$_tag: ⚠️ Microphone permission limited');
          return PermissionResult.limited();

        case PermissionStatus.provisional:
          debugPrint('$_tag: ⚠️ Microphone permission provisional');
          return PermissionResult.provisional();
      }

    } catch (e) {
      debugPrint('$_tag: ❌ Error requesting microphone permission: $e');
      return PermissionResult.error('Failed to request permission: $e');
    }
  }

  // ==== STORAGE PERMISSIONS ====

  /// Check if storage permission is granted (Android only)
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true; // iOS handles this automatically

    try {
      debugPrint('$_tag: Checking storage permission...');

      // For Android 13+ (API 33+), use media permissions
      if (Platform.isAndroid) {
        final audioStatus = await Permission.audio.status;
        debugPrint('$_tag: Audio permission status: $audioStatus');
        return audioStatus == PermissionStatus.granted;
      }

      return true;

    } catch (e) {
      debugPrint('$_tag: Error checking storage permission: $e');
      return false;
    }
  }

  /// Request storage permission (Android only)
  static Future<PermissionResult> requestStoragePermission() async {
    if (!Platform.isAndroid) return PermissionResult.granted(); // iOS handles automatically

    try {
      debugPrint('$_tag: Requesting storage permission...');

      // For Android 13+ (API 33+), request audio permission
      final status = await Permission.audio.request();
      debugPrint('$_tag: Storage permission request result: $status');

      switch (status) {
        case PermissionStatus.granted:
          return PermissionResult.granted();
        case PermissionStatus.denied:
          return PermissionResult.denied();
        case PermissionStatus.permanentlyDenied:
          return PermissionResult.permanentlyDenied();
        case PermissionStatus.restricted:
          return PermissionResult.restricted();
        case PermissionStatus.limited:
          return PermissionResult.limited();
        case PermissionStatus.provisional:
          return PermissionResult.provisional();
      }

    } catch (e) {
      debugPrint('$_tag: Error requesting storage permission: $e');
      return PermissionResult.error('Failed to request storage permission: $e');
    }
  }

  // ==== COMBINED PERMISSIONS ====

  /// Check all required permissions for recording
  static Future<RecordingPermissionStatus> checkRecordingPermissions() async {
    debugPrint('$_tag: Checking all recording permissions...');

    try {
      final micPermission = await hasMicrophonePermission();
      final storagePermission = await hasStoragePermission();

      debugPrint('$_tag: Mic: $micPermission, Storage: $storagePermission');

      if (micPermission && storagePermission) {
        return RecordingPermissionStatus.allGranted;
      } else if (!micPermission && !storagePermission) {
        return RecordingPermissionStatus.allDenied;
      } else {
        return RecordingPermissionStatus.partiallyGranted;
      }

    } catch (e) {
      debugPrint('$_tag: Error checking recording permissions: $e');
      return RecordingPermissionStatus.error;
    }
  }

  /// Request all required permissions for recording
  static Future<PermissionRequestResult> requestRecordingPermissions() async {
    debugPrint('$_tag: Requesting all recording permissions...');

    try {
      final micResult = await requestMicrophonePermission();
      final storageResult = await requestStoragePermission();

      debugPrint('$_tag: Mic result: ${micResult.status}, Storage result: ${storageResult.status}');

      return PermissionRequestResult(
        microphone: micResult,
        storage: storageResult,
      );

    } catch (e) {
      debugPrint('$_tag: Error requesting recording permissions: $e');
      return PermissionRequestResult.error('Failed to request permissions: $e');
    }
  }

  // ==== UTILITY METHODS ====

  /// Open app settings for permission management
  static Future<bool> openAppSettings() async {
    try {
      debugPrint('$_tag: Opening app settings...');
      final opened = await openAppSettings();
      debugPrint('$_tag: App settings opened: $opened');
      return opened;
    } catch (e) {
      debugPrint('$_tag: Error opening app settings: $e');
      return false;
    }
  }

  /// Check if device has microphone hardware
  static Future<bool> hasMicrophoneHardware() async {
    try {
      // This is a basic check - in a real app you might use
      // platform-specific code to check hardware capabilities
      return true; // Most devices have microphones
    } catch (e) {
      debugPrint('$_tag: Error checking microphone hardware: $e');
      return false;
    }
  }

  /// Get detailed permission status info for debugging
  static Future<Map<String, dynamic>> getPermissionDebugInfo() async {
    final info = <String, dynamic>{};

    try {
      info['platform'] = Platform.operatingSystem;
      info['microphone_status'] = (await Permission.microphone.status).toString();
      info['microphone_granted'] = await hasMicrophonePermission();
      info['storage_granted'] = await hasStoragePermission();
      info['has_microphone_hardware'] = await hasMicrophoneHardware();
      info['timestamp'] = DateTime.now().toIso8601String();

      if (Platform.isAndroid) {
        info['audio_status'] = (await Permission.audio.status).toString();
      }

    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }
}

// ==== RESULT CLASSES ====

/// Result of a permission request
class PermissionResult {
  final PermissionResultStatus status;
  final String? errorMessage;

  const PermissionResult._({
    required this.status,
    this.errorMessage,
  });

  factory PermissionResult.granted() => const PermissionResult._(status: PermissionResultStatus.granted);
  factory PermissionResult.denied() => const PermissionResult._(status: PermissionResultStatus.denied);
  factory PermissionResult.permanentlyDenied() => const PermissionResult._(status: PermissionResultStatus.permanentlyDenied);
  factory PermissionResult.restricted() => const PermissionResult._(status: PermissionResultStatus.restricted);
  factory PermissionResult.limited() => const PermissionResult._(status: PermissionResultStatus.limited);
  factory PermissionResult.provisional() => const PermissionResult._(status: PermissionResultStatus.provisional);
  factory PermissionResult.error(String message) => PermissionResult._(
    status: PermissionResultStatus.error,
    errorMessage: message,
  );

  bool get isGranted => status == PermissionResultStatus.granted;
  bool get isDenied => status == PermissionResultStatus.denied;
  bool get isPermanentlyDenied => status == PermissionResultStatus.permanentlyDenied;
  bool get isError => status == PermissionResultStatus.error;
  bool get needsSettings => isPermanentlyDenied;
}

/// Combined result for all recording permissions
class PermissionRequestResult {
  final PermissionResult microphone;
  final PermissionResult storage;
  final String? errorMessage;

  const PermissionRequestResult({
    required this.microphone,
    required this.storage,
    this.errorMessage,
  });

  factory PermissionRequestResult.error(String message) => PermissionRequestResult(
    microphone: PermissionResult.error(message),
    storage: PermissionResult.error(message),
    errorMessage: message,
  );

  bool get canRecord => microphone.isGranted && storage.isGranted;
  bool get hasAnyPermission => microphone.isGranted || storage.isGranted;
  bool get needsSettings => microphone.needsSettings || storage.needsSettings;
  bool get hasError => microphone.isError || storage.isError;
}

/// Status of permission requests (renamed to avoid conflict)
enum PermissionResultStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
  error,
}

/// Overall recording permission status (renamed to avoid conflict)
enum RecordingPermissionStatus {
  allGranted,
  allDenied,
  partiallyGranted,
  error,
}