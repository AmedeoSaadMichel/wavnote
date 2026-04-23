// File: services/permission/permission_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph; // Alias
import 'package:flutter/foundation.dart';
import '../../core/errors/exceptions.dart';

class PermissionService {
  static const String _tag = 'PermissionService';
  static const _engineChannel = MethodChannel('com.wavnote/audio_engine');

  static Future<bool> hasMicrophonePermission() async {
    if (Platform.isMacOS) {
      try {
        final status = await _engineChannel.invokeMethod<String>(
          'checkMicPermission',
        );
        return status == 'authorized';
      } catch (e) {
        debugPrint('$_tag: macOS checkMicPermission error: $e');
        return false;
      }
    }

    try {
      final status = await ph.Permission.microphone.status;
      return status == ph.PermissionStatus.granted;
    } catch (e) {
      debugPrint('$_tag: Error checking microphone permission: $e');
      return false;
    }
  }

  static Future<PermissionResult> requestMicrophonePermission() async {
    if (Platform.isMacOS) {
      try {
        final granted = await _engineChannel.invokeMethod<bool>(
          'requestMicPermission',
        );
        return granted == true
            ? PermissionResult.granted()
            : PermissionResult.permanentlyDenied();
      } catch (e) {
        throw PermissionException(
          message: 'Failed to request microphone permission',
          errorType: PermissionErrorType.permissionRequestFailed,
          originalError: e,
        );
      }
    }

    try {
      final requestStatus = await ph.Permission.microphone.request();
      switch (requestStatus) {
        case ph.PermissionStatus.granted:
          return PermissionResult.granted();
        case ph.PermissionStatus.denied:
          return PermissionResult.denied();
        case ph.PermissionStatus.permanentlyDenied:
          return PermissionResult.permanentlyDenied();
        default:
          return PermissionResult.denied();
      }
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request microphone permission',
        errorType: PermissionErrorType.permissionRequestFailed,
        originalError: e,
      );
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final audioStatus = await ph.Permission.audio.status;
      return audioStatus == ph.PermissionStatus.granted;
    } catch (e) {
      return false;
    }
  }

  static Future<PermissionResult> requestStoragePermission() async {
    if (!Platform.isAndroid) return PermissionResult.granted();
    try {
      final status = await ph.Permission.audio.request();
      switch (status) {
        case ph.PermissionStatus.granted:
          return PermissionResult.granted();
        case ph.PermissionStatus.denied:
          return PermissionResult.denied();
        case ph.PermissionStatus.permanentlyDenied:
          return PermissionResult.permanentlyDenied();
        default:
          return PermissionResult.denied();
      }
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request storage permission',
        errorType: PermissionErrorType.permissionRequestFailed,
        originalError: e,
      );
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (e) {
      debugPrint('$_tag: Error opening app settings: $e');
      return false;
    }
  }

  static Future<bool> hasMicrophoneHardware() async => true;

  static Future<Map<String, dynamic>> getPermissionDebugInfo() async {
    final info = <String, dynamic>{};
    try {
      info['platform'] = Platform.operatingSystem;
      info['microphone_status'] = (await ph.Permission.microphone.status)
          .toString();
      info['microphone_granted'] = await hasMicrophonePermission();
      info['storage_granted'] = await hasStoragePermission();
      info['has_microphone_hardware'] = await hasMicrophoneHardware();
      info['timestamp'] = DateTime.now().toIso8601String();
    } catch (e) {
      info['error'] = e.toString();
    }
    return info;
  }

  static Future<RecordingPermissionStatus> checkRecordingPermissions() async {
    try {
      final micPermission = await hasMicrophonePermission();
      final storagePermission = await hasStoragePermission();
      if (micPermission && storagePermission) {
        return RecordingPermissionStatus.allGranted;
      } else if (!micPermission && !storagePermission) {
        return RecordingPermissionStatus.allDenied;
      } else {
        return RecordingPermissionStatus.partiallyGranted;
      }
    } catch (e) {
      return RecordingPermissionStatus.error;
    }
  }
}

class PermissionResult {
  final PermissionResultStatus status;
  final String? errorMessage;
  const PermissionResult._({required this.status, this.errorMessage});
  factory PermissionResult.granted() =>
      const PermissionResult._(status: PermissionResultStatus.granted);
  factory PermissionResult.denied() =>
      const PermissionResult._(status: PermissionResultStatus.denied);
  factory PermissionResult.permanentlyDenied() => const PermissionResult._(
    status: PermissionResultStatus.permanentlyDenied,
  );
  factory PermissionResult.error(String message) => PermissionResult._(
    status: PermissionResultStatus.error,
    errorMessage: message,
  );
  bool get isGranted => status == PermissionResultStatus.granted;
  bool get isDenied => status == PermissionResultStatus.denied;
  bool get isPermanentlyDenied =>
      status == PermissionResultStatus.permanentlyDenied;
  bool get isError => status == PermissionResultStatus.error;
  bool get needsSettings => isPermanentlyDenied;
}

enum PermissionResultStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
  error,
}

enum RecordingPermissionStatus {
  allGranted,
  allDenied,
  partiallyGranted,
  error,
}
