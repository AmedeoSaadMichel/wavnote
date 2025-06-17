// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../domain/entities/folder_entity.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../blocs/recording/recording_bloc.dart';
import '../../widgets/recording/organic_background.dart';
import '../../widgets/recording/recording_list_item.dart';
import '../../../services/audio/audio_service_factory.dart';
// Import your fixed bottom sheet (adjust path as needed)
import '../../widgets/recording/recording_bottom_sheet.dart';

/// Recording List Screen - Organic Cloud Style
///
/// Displays recordings in a folder with Midnight Gospel inspired design.
/// Includes real recording functionality with BLoC integration and location-based naming.
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
  late RecordingBloc _recordingBloc;

  // Recording state for bottom sheet
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  String? _currentFilePath;

  // List of recordings in this folder
  List<RecordingEntity> _recordings = [];

  // Location state
  String? _currentAddress;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();

    // Initialize recording BLoC
    final audioService = AudioServiceFactory.createUnifiedService(useRealAudio: true);
    _recordingBloc = RecordingBloc(audioService: audioService);

    // Gentle pulse for UI elements
    _pulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Load existing recordings for this folder
    _loadRecordings();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingBloc.close();
    super.dispose();
  }

  /// Load existing recordings for this folder
  void _loadRecordings() {
    // TODO: Load recordings from repository based on folder ID
    // For now, use mock data
    _recordings = _generateMockRecordings();
  }

  /// Handle recording toggle with real recording
  void _toggleRecording() {
    if (!_isRecording) {
      _startRealRecording();
    } else {
      _stopRealRecording();
    }
  }

  /// Start real recording
  void _startRealRecording() {
    debugPrint('🎙️ Starting real recording in ${widget.folder.name}');

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    // Get current location first, then start recording
    _getCurrentLocationAndStartRecording();
  }

  /// Get location first, then start recording
  Future<void> _getCurrentLocationAndStartRecording() async {
    // Get location first
    await _getCurrentLocation();

    // Now check permissions and start recording
    _recordingBloc.add(const CheckRecordingPermissions());
  }

  /// Stop real recording
  void _stopRealRecording() {
    debugPrint('⏹️ Stopping real recording in ${widget.folder.name}');

    _recordingBloc.add(const StopRecording());

    setState(() {
      _isRecording = false;
    });
  }

  /// Generate recording file path
  String _generateRecordingFilePath() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final folderName = widget.folder.name.replaceAll(' ', '_');
    return 'recordings/${folderName}_$timestamp.m4a';
  }

  /// Generate recording name based on current location
  String _generateRecordingName() {
    // Debug log to check what address we have
    debugPrint('📍 Generating name with address: $_currentAddress');

    if (_currentAddress != null && _currentAddress!.isNotEmpty && _currentAddress != widget.folder.name) {
      // Count existing recordings with same address
      final sameAddressCount = _recordings
          .where((r) => r.name.startsWith(_currentAddress!))
          .length;

      if (sameAddressCount == 0) {
        debugPrint('📝 Generated name: $_currentAddress');
        return _currentAddress!;
      } else {
        final newName = '$_currentAddress ${sameAddressCount + 1}';
        debugPrint('📝 Generated name: $newName');
        return newName;
      }
    } else {
      // Fallback to folder name if location not available
      final existingCount = _recordings.length;
      final fallbackName = existingCount == 0
          ? widget.folder.name
          : '${widget.folder.name} ${existingCount + 1}';
      debugPrint('📝 Using fallback name: $fallbackName');
      return fallbackName;
    }
  }

  /// Get current location and convert to address
  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      // For now, simulate getting location and use folder name
      // TODO: Replace with real location when dependencies are added
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate getting address from GPS
      final addresses = [
        'Via Cerlini 6',
        'Piazza del Duomo 1',
        'Via Roma 25',
        'Corso Italia 10',
        'Via Garibaldi 15'
      ];

      final randomAddress = addresses[math.Random().nextInt(addresses.length)];

      setState(() {
        _currentAddress = randomAddress;
        _isGettingLocation = false;
      });

      debugPrint('📍 Simulated address: $randomAddress');

      /*
      // TODO: Replace simulation above with real location code below when dependencies are added:

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied');
          setState(() {
            _currentAddress = widget.folder.name; // Fallback
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied');
        setState(() {
          _currentAddress = widget.folder.name; // Fallback
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Create address string from components
        String address = '';

        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address = placemark.street!;
        } else if (placemark.name != null && placemark.name!.isNotEmpty) {
          address = placemark.name!;
        } else if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          address = placemark.locality!;
        } else {
          address = 'Unknown Location';
        }

        setState(() {
          _currentAddress = address;
          _isGettingLocation = false;
        });

        debugPrint('📍 Current address: $address');
      }
      */

    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      setState(() {
        _currentAddress = widget.folder.name; // Fallback
        _isGettingLocation = false;
      });
    }
  }

  /// Add new recording to list
  void _addNewRecording(RecordingEntity recording) {
    setState(() {
      _recordings.insert(0, recording); // Add to beginning of list
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _recordingBloc,
      child: BlocListener<RecordingBloc, RecordingState>(
        listener: (context, state) {
          _handleRecordingStateChange(state);
        },
        child: Scaffold(
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

              // Recording bottom sheet - show current address while recording
              RecordBottomSheet(
                title: _isRecording
                    ? (_currentAddress ?? 'Getting location...')
                    : widget.folder.name, // Show folder name when not recording
                filePath: _currentFilePath,
                isRecording: _isRecording,
                onToggle: _toggleRecording,
                elapsed: _recordingDuration,
                width: MediaQuery.of(context).size.width,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle recording state changes from BLoC
  void _handleRecordingStateChange(RecordingState state) {
    debugPrint('🎙️ Recording state changed: ${state.runtimeType}');

    if (state is RecordingPermissionStatus && state.canRecord) {
      // Permissions granted, start actual recording
      final filePath = _generateRecordingFilePath();

      setState(() {
        _currentFilePath = filePath;
      });

      // Start recording (the name will be updated when recording completes)
      _recordingBloc.add(StartRecording(
        folderId: widget.folder.id,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
      ));

    } else if (state is RecordingInProgress) {
      // Update duration from real recording
      setState(() {
        _recordingDuration = state.duration;
        _currentFilePath = state.filePath;
      });

    } else if (state is RecordingCompleted) {
      // Recording finished successfully
      debugPrint('✅ Recording completed: ${state.recording.name}');

      // Create a new recording entity with the location-based name
      final locationBasedName = _generateRecordingName();
      final updatedRecording = RecordingEntity(
        id: state.recording.id,
        name: locationBasedName, // Use location-based name here
        filePath: state.recording.filePath,
        duration: state.recording.duration,
        folderId: state.recording.folderId,
        createdAt: state.recording.createdAt,
        format: state.recording.format,
        sampleRate: state.recording.sampleRate,
        fileSize: state.recording.fileSize,
      );

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
        _currentFilePath = null;
      });

      // Add the new recording to the list with correct name
      _addNewRecording(updatedRecording);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording "${updatedRecording.name}" saved successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

    } else if (state is RecordingError) {
      // Handle recording errors
      debugPrint('❌ Recording error: ${state.message}');

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
        _currentFilePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording failed: ${state.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

    } else if (state is RecordingPermissionStatus && !state.canRecord) {
      // Permission denied
      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
      child: _recordings.isEmpty
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

          const SizedBox(height: 150), // Space for bottom sheet
        ],
      ),
    );
  }

  /// Build recordings list view
  Widget _buildRecordingsListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 200), // Space for bottom sheet
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final recording = _recordings[index];
        return RecordingListItem(
          recording: {
            'name': recording.name,
            'date': _formatDate(recording.createdAt),
            'duration': _formatDuration(recording.duration),
            'isPlaying': false, // TODO: Implement playback state
          },
          onTap: () => _handleRecordingTap(recording),
        );
      },
    );
  }

  /// Generate mock recordings for demonstration (now uses real data structure)
  List<RecordingEntity> _generateMockRecordings() {
    final now = DateTime.now();
    return List.generate(
      widget.folder.recordingCount,
          (index) => RecordingEntity(
        id: 'mock_${widget.folder.id}_$index',
        name: index == 0 ? widget.folder.name : '${widget.folder.name} ${index + 1}',
        filePath: 'recordings/${widget.folder.name}_mock_$index.m4a',
        duration: Duration(seconds: math.Random().nextInt(180) + 10), // 10-190 seconds
        folderId: widget.folder.id,
        createdAt: now.subtract(Duration(days: index)),
        format: AudioFormat.m4a,
        sampleRate: 44100,
        fileSize: math.Random().nextInt(5000000) + 500000, // 0.5-5.5 MB
      ),
    );
  }

  /// Handle recording item tap
  void _handleRecordingTap(RecordingEntity recording) {
    // TODO: Navigate to recording detail screen or start playback
    debugPrint('Tapped recording: ${recording.name}');

    // For now, just show info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: ${recording.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}