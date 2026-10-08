import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/enums/audio_format.dart';
import '../../core/utils/app_file_utils.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/entities/recording_session_segment.dart';
import '../../domain/repositories/i_audio_recording_repository.dart';
import '../../domain/repositories/i_audio_trimmer_repository.dart';
import '../../domain/repositories/i_recording_repository.dart';

/// Copies paused takes before native stop/overwrite can remove their source files.
/// Simple pauses update the same take; a new overwrite path creates a new take.
class RecordingSegmentArchive {
  final IAudioRecordingRepository audio;
  final IAudioTrimmerRepository trimmer;
  final IRecordingRepository repository;
  final List<RecordingSessionSegment> _segments = [];
  Directory? _directory;
  Future<void> _pending = Future.value();

  RecordingSegmentArchive({
    required this.audio,
    required this.trimmer,
    required this.repository,
  });

  List<RecordingSessionSegment> get segments => List.unmodifiable(_segments);

  Future<void> capture({
    required String sourcePath,
    required Duration duration,
    required List<double> waveform,
    required int sampleRate,
    required String folderId,
    required String title,
  }) {
    final task = _pending.then(
      (_) => _capture(
        sourcePath: sourcePath,
        duration: duration,
        waveform: waveform,
        sampleRate: sampleRate,
        folderId: folderId,
        title: title,
      ),
    );
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> _capture({
    required String sourcePath,
    required Duration duration,
    required List<double> waveform,
    required int sampleRate,
    required String folderId,
    required String title,
  }) async {
    var paths = await audio.getPausedRecordingPaths();
    if (paths.isEmpty) {
      final absolute = await AppFileUtils.resolve(sourcePath);
      if (!await File(absolute).exists()) return;
      paths = [absolute];
    }
    _directory ??= await Directory.systemTemp.createTemp('wavnote_segments_');
    final existing = _segments.indexWhere((s) => s.sourcePath == sourcePath);
    final index = existing < 0 ? _segments.length : existing;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final extension = p.extension(paths.first);
    var output = p.join(_directory!.path, 'take_${index}_$stamp$extension');
    await File(paths.first).copy(output);
    try {
      for (var i = 1; i < paths.length; i++) {
        final next = p.join(_directory!.path, 'take_${index}_${stamp}_$i.wav');
        await trimmer.concatenateAudio(
          basePath: output,
          appendPath: paths[i],
          outputPath: next,
          format: 'wav',
        );
        await File(output).delete();
        output = next;
      }
      final measured = await audio.getAudioDuration(output);
      final decodedWaveform = await audio.extractRecordingWaveform(output);
      final recording = RecordingEntity(
        id: existing < 0
            ? 'session-segment-$stamp'
            : _segments[index].recording.id,
        name: '$title · Segmento ${index + 1}',
        filePath: output,
        folderId: folderId,
        format: p.extension(output).toLowerCase() == '.wav'
            ? AudioFormat.wav
            : AudioFormat.m4a,
        duration: measured > Duration.zero ? measured : duration,
        fileSize: await File(output).length(),
        sampleRate: sampleRate,
        createdAt: DateTime.now(),
        waveformData: List.unmodifiable(
          decodedWaveform.isNotEmpty ? decodedWaveform : waveform,
        ),
      );
      final segment = RecordingSessionSegment(
        sourcePath: sourcePath,
        recording: recording,
        colorIndex: index,
      );
      if (existing < 0) {
        _segments.add(segment);
      } else {
        final oldPath = _segments[index].recording.filePath;
        _segments[index] = segment;
        if (await File(oldPath).exists()) await File(oldPath).delete();
      }
    } catch (_) {
      if (await File(output).exists()) await File(output).delete();
      rethrow;
    }
  }

  /// Persist a separate library item; never give the repository a temporary path.
  Future<RecordingEntity> save(RecordingSessionSegment segment) {
    final task = _pending.then((_) => _save(segment));
    _pending = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  Future<RecordingEntity> _save(RecordingSessionSegment segment) async {
    if (!_segments.any((s) => s.recording.id == segment.recording.id)) {
      throw StateError('Il segmento non appartiene alla sessione corrente.');
    }
    final dir = Directory(
      p.join(await AppFileUtils.getApplicationDocumentsPath(), 'recordings'),
    );
    await dir.create(recursive: true);
    final target = p.join(
      dir.path,
      'segment_${DateTime.now().microsecondsSinceEpoch}${p.extension(segment.recording.filePath)}',
    );
    await File(segment.recording.filePath).copy(target);
    try {
      final original = segment.recording;
      final item = RecordingEntity.create(
        name: original.name,
        filePath: await AppFileUtils.toRelative(target),
        folderId: original.folderId,
        format: original.format,
        duration: original.duration,
        fileSize: await File(target).length(),
        sampleRate: original.sampleRate,
      );
      return await repository.createRecording(
        item.copyWith(waveformData: original.waveformData),
      );
    } catch (_) {
      await File(target).delete();
      rethrow;
    }
  }

  Future<void> clear() async {
    await _pending;
    _segments.clear();
    final directory = _directory;
    _directory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
