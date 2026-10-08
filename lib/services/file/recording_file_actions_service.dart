// File: lib/services/file/recording_file_actions_service.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/app_file_utils.dart';

class RecordingFileActionsService {
  static const _channel = MethodChannel('wavnote/file_actions');

  Future<Either<Failure, Unit>> reveal(String path) => _invoke('reveal', path);
  Future<Either<Failure, Unit>> share(String path) => _invoke('share', path);

  Future<Either<Failure, Unit>> _invoke(String method, String path) async {
    try {
      await _channel.invokeMethod<void>(method, {
        'path': await AppFileUtils.resolve(path),
      });
      return const Right(unit);
    } on PlatformException catch (error) {
      return Left(
        RecordingActionFailure(
          message: error.message ?? 'Impossibile aprire il file.',
          code: error.code,
        ),
      );
    } catch (_) {
      return const Left(
        RecordingActionFailure(
          message: 'Questa azione non è disponibile sul dispositivo.',
        ),
      );
    }
  }
}
