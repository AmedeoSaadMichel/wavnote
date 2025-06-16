// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../blocs/recording/recording_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/recording/organic_background.dart';
import '../../widgets/recording/recording_list_item.dart';
import '../../widgets/recording/organic_record_button.dart';
import '../../../services/audio/audio_recorder_service.dart';

/// Recording List Screen - Organic Cloud Style
///
/// Displays recordings in a folder with Midnight Gospel inspired design.
/// Includes integrated recording functionality with bottom sheet.
class RecordingListScreen extends StatefulWidget {
  final FolderEntity folder;

  const RecordingListScreen({
    super.key,
    required this.folder,
  });

  @override
  State<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  bool _showRecordingSheet = false;

  @override
  void initState() {
    super.initState();

    // Gentle pulse for UI elements
    _pulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Show recording bottom sheet
  void _showRecordingBottomSheet() {
    setState(() {
      _showRecordingSheet = true;
    });
  }

  /// Hide recording bottom sheet
  void _hideRecordingBottomSheet() {
    setState(() {
      _showRecordingSheet = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Organic background with clouds and stars
          const OrganicBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with folder info
                _buildHeader(),

                // Recordings list
                Expanded(
                  child: _buildRecordingsList(),
                ),
              ],
            ),
          ),

          // Organic recording button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: OrganicRecordButton(
                onTap: _showRecordingBottomSheet,
                pulseController: _pulseController,
              ),
            ),
          ),

          // Recording bottom sheet overlay
          if (_showRecordingSheet)
            BlocProvider(
              create: (context) {
                final audioService = AudioRecorderService();
                return RecordingBloc(audioService: audioService)
                  ..add(const CheckRecordingPermissions());
              },
              child: RecordingBottomSheet(
                selectedFolder: widget.folder,
                selectedFormat: AudioFormat.m4a,
                onComplete: _hideRecordingBottomSheet,
              ),
            ),
        ],
      ),
    );
  }

  /// Build header with folder information
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Navigation row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 20),

          // Folder info
          _buildFolderInfo(),
        ],
      ),
    );
  }

  /// Build folder information display
  Widget _buildFolderInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Folder icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.folder.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.folder.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              widget.folder.icon,
              color: widget.folder.color,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          // Folder name
          Text(
            widget.folder.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Recording count
          Text(
            widget.folder.recordingCountText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build recordings list
  Widget _buildRecordingsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: widget.folder.isEmpty
          ? _buildEmptyState()
          : _buildRecordingsListView(),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          Text(
            'No recordings yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tap the record button to start',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 100), // Space for record button
        ],
      ),
    );
  }

  /// Build recordings list view
  Widget _buildRecordingsListView() {
    // Mock recordings data
    final mockRecordings = _generateMockRecordings();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120), // Space for record button
      itemCount: mockRecordings.length,
      itemBuilder: (context, index) {
        return RecordingListItem(
          recording: mockRecordings[index],
          onTap: () => _handleRecordingTap(mockRecordings[index]),
        );
      },
    );
  }

  /// Generate mock recordings for demonstration
  List<Map<String, dynamic>> _generateMockRecordings() {
    return List.generate(
      math.max(2, widget.folder.recordingCount), // Show at least 2 for demo
          (index) => {
        'name': index == 0 ? '88 Bostall Lane 2' : '88 Bostall Lane',
        'date': '10 Jun 2025',
        'duration': index == 0 ? '00:14' : '01:23',
        'isPlaying': index == 0,
      },
    );
  }

  /// Handle recording item tap
  void _handleRecordingTap(Map<String, dynamic> recording) {
    // TODO: Implement recording playback logic
    print('Tapped recording: ${recording['name']}');
  }
}