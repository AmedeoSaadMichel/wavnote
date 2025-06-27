// File: presentation/widgets/recording/recording_edit_toolbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../bloc/recording/recording_bloc.dart';

/// Edit mode toolbar for recording list
class RecordingEditToolbar extends StatelessWidget {
  final VoidCallback onDeleteSelected;

  const RecordingEditToolbar({
    Key? key,
    required this.onDeleteSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, state) {
        if (state is! RecordingLoaded || !state.isEditMode) {
          return const SizedBox.shrink();
        }

        final selectedCount = state.selectedRecordings.length;
        final totalCount = state.recordings.length;
        final allSelected = selectedCount == totalCount && totalCount > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              bottom: BorderSide(color: Colors.grey[700]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  if (allSelected) {
                    context.read<RecordingBloc>().add(const DeselectAllRecordings());
                  } else {
                    context.read<RecordingBloc>().add(const SelectAllRecordings());
                  }
                },
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                    color: AppConstants.accentCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$selectedCount selected',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: selectedCount > 0 ? onDeleteSelected : null,
                icon: FaIcon(
                  FontAwesomeIcons.skull,
                  color: selectedCount > 0 ? Colors.red : Colors.grey[600],
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}