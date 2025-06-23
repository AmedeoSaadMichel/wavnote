import 'package:flutter/material.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../presentation/bloc/recording/recording_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecordingActions {
  static void showWaveform(BuildContext context, RecordingEntity recording) {
    // Puoi usare un bottom sheet, una nuova schermata, ecc.
    showModalBottomSheet(
      context: context,
      builder: (_) => Center(child: Text('Waveform for: ${recording.name}')),
    );
  }

  static void deleteRecording(BuildContext context, RecordingEntity recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('Are you sure you want to delete "${recording.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      context.read<RecordingBloc>().add(DeleteRecording(recording.id));
    }
  }
}
