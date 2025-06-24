// File: presentation/widgets/recording/recording_list_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../bloc/recording/recording_bloc.dart';

/// Header widget for recording list screen
class RecordingListHeader extends StatelessWidget {
  final String folderName;
  final VoidCallback onBack;

  const RecordingListHeader({
    Key? key,
    required this.folderName,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        final isEditMode = recordingState is RecordingLoaded ? recordingState.isEditMode : false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppConstants.accentCyan,
                  size: 24,
                ),
              ),
              Expanded(
                child: Text(
                  folderName,
                  style: const TextStyle(
                    color: AppConstants.accentYellow,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<RecordingBloc>().add(const ToggleEditMode());
                },
                child: Text(
                  isEditMode ? 'Done' : 'Edit',
                  style: const TextStyle(
                    color: AppConstants.accentCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}