// File: services/permission/permission_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PermissionService {
  static const String _tag = 'PermissionService';
  static const _engineChannel = MethodChannel('com.wavnote/audio_engine');

  static Future<bool> hasMicrophonePermission() async {
    if (Platform.isMacOS) {
      try {
        debugPrint('$_tag: 🔽 macOS — checkMicPermission via canale nativo');
        final status = await _engineChannel.invokeMethod<String>(
          'checkMicPermission',
        );
        final granted = status == 'authorized';
        debugPrint('$_tag: 🔽 macOS mic status="$status" (granted=$granted)');
        return granted;
      } catch (e) {
        debugPrint('$_tag: 🔽 macOS checkMicPermission error: $e');
        return false;
      }
    }

    try {
      final status = await Permission.microphone.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('$_tag: Error checking microphone permission: $e');
      return false;
    }
  }

  static Future<PermissionResult> requestMicrophonePermission() async {
    if (Platform.isMacOS) {
      try {
        debugPrint('$_tag: 🔽 macOS — requestMicPermission via canale nativo');
        final granted = await _engineChannel.invokeMethod<bool>(
          'requestMicPermission',
        );
        debugPrint('$_tag: 🔽 macOS requestMicPermission RESULTATO: $granted');
        if (granted == true) {
          debugPrint('$_tag: 🔽 ✅ Permesso CONCESSO da Swift');
          return PermissionResult.granted();
        }
        debugPrint('$_tag: 🔽 ❌ Permesso NEGATO da Swift');
        return PermissionResult.permanentlyDenied();
      } catch (e) {
        debugPrint('$_tag: 🔽 ❌ macOS requestMicPermission ERRORE: $e');
        return PermissionResult.error('Errore richiesta permesso macOS: $e');
      }
    }

    try {
      final currentStatus = await Permission.microphone.status;
      if (currentStatus == PermissionStatus.granted) {
        return PermissionResult.granted();
      }
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        return PermissionResult.permanentlyDenied();
      }
      final requestStatus = await Permission.microphone.request();
      switch (requestStatus) {
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
      debugPrint('$_tag: Error requesting microphone permission: $e');
      return PermissionResult.error('Failed to request permission: $e');
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final audioStatus = await Permission.audio.status;
      return audioStatus == PermissionStatus.granted;
    } catch (e) {
      return false;
    }
  }

  static Future<PermissionResult> requestStoragePermission() async {
    if (!Platform.isAndroid) return PermissionResult.granted();
    try {
      final status = await Permission.audio.request();
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
      return PermissionResult.error('Failed to request storage permission: $e');
    }
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

  static Future<PermissionRequestResult> requestRecordingPermissions() async {
    try {
      final micResult = await requestMicrophonePermission();
      final storageResult = await requestStoragePermission();
      return PermissionRequestResult(
        microphone: micResult,
        storage: storageResult,
      );
    } catch (e) {
      return PermissionRequestResult.error('Failed to request permissions: $e');
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasMicrophoneHardware() async => true;

  static Future<Map<String, dynamic>> getPermissionDebugInfo() async {
    final info = <String, dynamic>{};
    try {
      info['platform'] = Platform.operatingSystem;
      info['microphone_status'] = (await Permission.microphone.status)
          .toString();
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
  factory PermissionResult.restricted() =>
      const PermissionResult._(status: PermissionResultStatus.restricted);
  factory PermissionResult.limited() =>
      const PermissionResult._(status: PermissionResultStatus.limited);
  factory PermissionResult.provisional() =>
      const PermissionResult._(status: PermissionResultStatus.provisional);
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

class PermissionRequestResult {
  final PermissionResult microphone;
  final PermissionResult storage;
  final String? errorMessage;

  const PermissionRequestResult({
    required this.microphone,
    required this.storage,
    this.errorMessage,
  });

  factory PermissionRequestResult.error(String message) =>
      PermissionRequestResult(
        microphone: PermissionResult.error(message),
        storage: PermissionResult.error(message),
        errorMessage: message,
      );

  bool get canRecord => microphone.isGranted && storage.isGranted;
  bool get hasAnyPermission => microphone.isGranted || storage.isGranted;
  bool get needsSettings => microphone.needsSettings || storage.needsSettings;
  bool get hasError => microphone.isError || storage.isError;
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
