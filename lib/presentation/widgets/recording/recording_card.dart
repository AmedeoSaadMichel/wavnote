// File: presentation/widgets/recording/recording_card.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math';

import '../../../domain/entities/recording_entity.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/enums/audio_format.dart';
import '../../../services/audio/audio_analysis_service.dart';
import 'waveform_widget.dart';

/// Recording Card with Internal Waveform Management
///
/// This widget manages its own waveform generation and caching.
/// Audio playback state is still managed at the screen level.
class RecordingCard extends StatefulWidget {
  final RecordingEntity recording;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback onShowWaveform;
  final VoidCallback onDelete;
  final VoidCallback onMoveToFolder;
  final VoidCallback onMoreActions;
  final VoidCallback? onRestore; // Callback for restore action
  final VoidCallback? onToggleFavorite; // Callback for toggle favorite
  
  // Audio state passed from parent
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  
  // Audio control callbacks
  final VoidCallback onPlayPause;
  final Function(double) onSeek;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  
  // Tag display context
  final String currentFolderId; // The folder we're currently viewing
  final Map<String, String>? folderNames; // Map of folder ID to folder name
  
  // Selection state
  final bool isEditMode; // Whether edit mode is active
  final bool isSelected; // Whether this recording is selected
  final VoidCallback? onSelectionToggle; // Callback for selection toggle

  const RecordingCard({
    Key? key,
    required this.recording,
    required this.isExpanded,
    this.onTap,
    required this.onShowWaveform,
    required this.onDelete,
    required this.onMoveToFolder,
    required this.onMoreActions,
    this.onRestore,
    this.onToggleFavorite,
    required this.isPlaying,
    required this.isLoading,
    required this.currentPosition,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.currentFolderId,
    this.folderNames,
    this.isEditMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  }) : super(key: key);

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard> with TickerProviderStateMixin {
  // Waveform data managed internally
  List<double>? _waveformData;
  bool _isGeneratingWaveform = false;
  final AudioAnalysisService _audioAnalysisService = AudioAnalysisService();
  
  // Pure visual waveform position (no audio connection)
  double _waveformPosition = 0.0;
  
  // Static cache to persist across widget rebuilds
  static final Map<String, List<double>> _waveformCache = {};
  
  // Swipe animation controllers
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _swipeOffset = 0.0;
  bool _isSwipeActionsVisible = false;
  
  // Favorite action animation controller
  late AnimationController _favoriteController;
  late Animation<double> _favoriteAnimation;
  double _favoriteOffset = 0.0;
  bool _isFavoriteActionVisible = false;

  @override
  void initState() {
    super.initState();
    _loadWaveformData();
    
    // Initialize swipe animation
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: -240.0, // Width of action buttons
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));
    
    _swipeAnimation.addListener(() {
      setState(() {
        _swipeOffset = _swipeAnimation.value;
      });
    });
    
    // Initialize favorite action animation
    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _favoriteAnimation = Tween<double>(
      begin: 0.0,
      end: 80.0, // Width of favorite button
    ).animate(CurvedAnimation(
      parent: _favoriteController,
      curve: Curves.easeInOut,
    ));
    
    _favoriteAnimation.addListener(() {
      setState(() {
        _favoriteOffset = _favoriteAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Regenerate waveform if recording changed
    if (oldWidget.recording.id != widget.recording.id) {
      _loadWaveformData();
      _waveformPosition = 0.0; // Reset position for new recording
    }
    
    // Sync waveform position with audio position (only when not actively dragging)
    _syncWaveformWithAudio();
  }
  
  /// Sync waveform position with actual audio position during playback
  void _syncWaveformWithAudio() {
    final totalDuration = widget.recording.duration;
    if (totalDuration.inMilliseconds > 0 && widget.isExpanded) {
      final audioProgress = widget.currentPosition.inMilliseconds / totalDuration.inMilliseconds;
      final clampedProgress = audioProgress.clamp(0.0, 1.0);
      
      // Only update if there's a significant difference (avoid fighting with user dragging)
      if ((clampedProgress - _waveformPosition).abs() > 0.01) {
        setState(() {
          _waveformPosition = clampedProgress;
        });
      }
    }
  }

  /// Load or generate waveform data for this recording
  Future<void> _loadWaveformData() async {
    final recordingId = widget.recording.id;
    
    // Check cache first
    if (_waveformCache.containsKey(recordingId)) {
      setState(() {
        _waveformData = _waveformCache[recordingId];
      });
      return;
    }

    // Generate new waveform if not cached
    if (!_isGeneratingWaveform) {
      setState(() {
        _isGeneratingWaveform = true;
      });

      try {
        final waveform = await _generateWaveformData(widget.recording);
        
        // Cache and set the waveform
        _waveformCache[recordingId] = waveform;
        
        if (mounted) {
          setState(() {
            _waveformData = waveform;
            _isGeneratingWaveform = false;
          });
        }
      } catch (e) {
        print('❌ Error generating waveform for ${widget.recording.name}: $e');
        if (mounted) {
          setState(() {
            _isGeneratingWaveform = false;
          });
        }
      }
    }
  }

  /// Generate waveform data from real audio file
  Future<List<double>> _generateWaveformData(RecordingEntity recording) async {
    print('🎵 Generating waveform for: ${recording.name}');
    
    // First, check if recording already has waveform data
    if (recording.waveformData != null && recording.waveformData!.isNotEmpty) {
      print('✅ Using stored waveform data (${recording.waveformData!.length} samples)');
      return recording.waveformData!;
    }

    // If no stored waveform data, extract from audio file
    try {
      print('🔍 Extracting waveform from audio file: ${recording.filePath}');
      final waveformData = await _audioAnalysisService.extractWaveformFromFile(
        recording.filePath,
        sampleCount: 200,
      );
      
      if (waveformData.isNotEmpty) {
        print('✅ Successfully extracted real waveform (${waveformData.length} samples)');
        return waveformData;
      } else {
        print('⚠️ Could not extract waveform, using fallback');
        return _generateFallbackWaveform(recording);
      }
    } catch (e) {
      print('❌ Error extracting waveform: $e');
      return _generateFallbackWaveform(recording);
    }
  }

  /// Generate fallback waveform when real extraction fails
  List<double> _generateFallbackWaveform(RecordingEntity recording) {
    print('🎭 Generating realistic fallback waveform for: ${recording.name}');
    
    // Use the audio analysis service for consistent realistic waveforms
    return _audioAnalysisService.extractWaveformFromFile(
      'fallback_${recording.id}', // Fake path based on recording ID for consistency
      sampleCount: 200,
    ).then((waveform) => waveform).catchError((error) {
      // If even the fallback fails, create a simple realistic pattern
      final seed = recording.id.hashCode;
      final random = Random(seed);
      final List<double> amplitudes = [];

      for (int i = 0; i < 200; i++) {
        final position = i / 200.0;
        
        // Create speech-like patterns
        final syllablePattern = sin(position * pi * 20) * 0.3;
        final wordPattern = sin(position * pi * 5) * 0.2;
        final baseAmplitude = 0.4 + syllablePattern + wordPattern;
        
        // Add natural variation
        final variation = (random.nextDouble() - 0.5) * 0.2;
        double amplitude = baseAmplitude + variation;
        
        // Natural fade envelope
        if (position < 0.1) {
          amplitude *= position / 0.1;
        } else if (position > 0.9) {
          amplitude *= (1.0 - position) / 0.1;
        }
        
        // Occasional silence gaps
        if (random.nextDouble() < 0.03) {
          amplitude *= 0.1;
        }
        
        amplitudes.add(amplitude.clamp(0.0, 1.0));
      }
      
      return amplitudes;
    }) as List<double>;
  }

  /// Handle waveform position changes (visual + audio seeking)
  void _handleWaveformPositionChanged(double position) {
    setState(() {
      _waveformPosition = position;
    });
    
    print('📊 Waveform position: ${(position * 100).toStringAsFixed(1)}% - seeking audio');
    
    // Tell audio player to seek to this position
    widget.onSeek(position);
  }

  /// Build source folder tag (purple) - only shown in "All Recordings" folder
  Widget? _buildSourceFolderTag() {
    // Only show folder tag if we're in "All Recordings" and recording is NOT from "all_recordings"
    if (widget.currentFolderId != 'all_recordings' || widget.recording.folderId == 'all_recordings') {
      return null;
    }

    // Get folder name from map or use folder ID as fallback
    final folderName = widget.folderNames?[widget.recording.folderId] ?? widget.recording.folderId;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        folderName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build file extension tag (yellow) - always shown
  Widget _buildExtensionTag() {
    final extension = widget.recording.format.fileExtension;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        extension.toUpperCase().replaceFirst('.', ''),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build tags row
  Widget _buildTagsRow() {
    final folderTag = _buildSourceFolderTag();
    
    return Row(
      children: [
        if (folderTag != null) ...[
          folderTag,
          const SizedBox(width: 4),
        ],
        _buildExtensionTag(),
      ],
    );
  }

  /// Toggle swipe actions visibility
  void _toggleSwipeActions() {
    // Hide favorite actions first
    if (_isFavoriteActionVisible) {
      _hideFavoriteAction();
    }
    
    if (_isSwipeActionsVisible) {
      _swipeController.reverse();
    } else {
      _swipeController.forward();
    }
    _isSwipeActionsVisible = !_isSwipeActionsVisible;
  }
  
  /// Hide swipe actions
  void _hideSwipeActions() {
    if (_isSwipeActionsVisible) {
      _swipeController.reverse();
      _isSwipeActionsVisible = false;
    }
  }

  /// Toggle favorite action visibility
  void _toggleFavoriteAction() {
    // Hide other actions first
    if (_isSwipeActionsVisible) {
      _hideSwipeActions();
    }
    
    if (_isFavoriteActionVisible) {
      _favoriteController.reverse();
    } else {
      _favoriteController.forward();
    }
    _isFavoriteActionVisible = !_isFavoriteActionVisible;
  }
  
  /// Hide favorite action
  void _hideFavoriteAction() {
    if (_isFavoriteActionVisible) {
      _favoriteController.reverse();
      _isFavoriteActionVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Allow swipe on both collapsed and expanded cards
        if (details.delta.dx < -5) {
          // Swipe RIGHT to LEFT - show three action buttons
          if (!_isSwipeActionsVisible) {
            _toggleSwipeActions();
          }
        } else if (details.delta.dx > 5) {
          // Swipe LEFT to RIGHT - show favorite button (not in recently deleted)
          if (!_isFavoriteActionVisible && 
              widget.currentFolderId != 'recently_deleted') {
            _toggleFavoriteAction();
          }
        }
      },
      onTap: () {
        // Hide swipe actions when tapping
        if (_isSwipeActionsVisible) {
          _hideSwipeActions();
        } else if (_isFavoriteActionVisible) {
          _hideFavoriteAction();
        } else if (widget.isEditMode) {
          // In edit mode, toggle selection
          widget.onSelectionToggle?.call();
        } else {
          // Normal mode, expand/collapse recording
          widget.onTap?.call();
        }
      },
      child: Stack(
        children: [
          // Favorite action button background (left side)
          _buildFavoriteActionBackground(),
          
          // Swipe action buttons background (right side)
          _buildSwipeActionsBackground(),
          
          // Main card content
          Transform.translate(
            offset: Offset(_swipeOffset + _favoriteOffset, 0),
            child: widget.isExpanded ? _buildExpandedCard() : _buildCollapsedCard(),
          ),
          
          // Selection overlay and checkbox (edit mode only)
          if (widget.isEditMode) _buildSelectionOverlay(),
        ],
      ),
    );
  }

  /// Build selection overlay for edit mode
  Widget _buildSelectionOverlay() {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: widget.isSelected 
              ? Border.all(color: Colors.blue, width: 2)
              : null,
          color: widget.isSelected 
              ? Colors.blue.withValues(alpha:0.1)
              : Colors.transparent,
        ),
        child: Stack(
          children: [
            // Selection checkbox (top left, smaller)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected 
                      ? Colors.blue
                      : Colors.grey[600],
                  border: Border.all(
                    color: widget.isSelected 
                        ? Colors.blue
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build favorite action background (left side for swipe left-to-right)
  Widget _buildFavoriteActionBackground() {
    // Don't show favorite action in recently deleted folder only
    if (widget.currentFolderId == 'recently_deleted') {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      left: 16,
      top: 4,
      bottom: 4,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: widget.recording.isFavorite ? Colors.red : Colors.orange,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hideFavoriteAction();
              widget.onToggleFavorite?.call();
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.recording.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.recording.isFavorite ? 'Remove' : 'Favorite',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build swipe actions background (iOS-style)
  Widget _buildSwipeActionsBackground() {
    final isRecentlyDeleted = widget.currentFolderId == 'recently_deleted';
    
    return Positioned(
      right: 16,
      top: 4,
      bottom: 4,
      width: isRecentlyDeleted ? 160 : 240, // Width for 2 or 3 buttons (80px each)
      child: Row(
        children: isRecentlyDeleted 
            ? _buildRecentlyDeletedActions()
            : _buildNormalActions(),
      ),
    );
  }

  /// Build actions for Recently Deleted folder (Restore + Delete)
  List<Widget> _buildRecentlyDeletedActions() {
    return [
      // Restore button (green)
      Expanded(
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideSwipeActions();
                widget.onRestore?.call();
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restore,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Restore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Permanent Delete button (red)
      Expanded(
        child: Container(
          width: 80,
          decoration: const BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideSwipeActions();
                widget.onDelete();
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.skull,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Build actions for normal folders (More Actions + Move + Delete)
  List<Widget> _buildNormalActions() {
    return [
      // More Actions button (gray)
      Expanded(
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideSwipeActions();
                widget.onMoreActions();
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'More Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Move to Folder button (blue)
      Expanded(
        child: Container(
          width: 80,
          color: Colors.blue,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideSwipeActions();
                widget.onMoveToFolder();
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Move to Folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Delete button (red with skull)
      Expanded(
        child: Container(
          width: 80,
          decoration: const BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideSwipeActions();
                widget.onDelete();
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.skull,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Build favorite heart icon for collapsed card
  Widget _buildFavoriteIcon() {
    // Only show heart if recording is favorite
    if (!widget.recording.isFavorite) {
      // Return an invisible placeholder to maintain layout consistency
      return const SizedBox(width: 24, height: 24);
    }
    
    return GestureDetector(
      onTap: () {
        // Allow toggling favorite by tapping the heart (if not in recently deleted)
        if (widget.currentFolderId != 'recently_deleted') {
          widget.onToggleFavorite?.call();
        }
      },
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          Icons.favorite,
          color: Colors.red,
          size: 20,
        ),
      ),
    );
  }

  /// Build the collapsed card state - title, date, and duration
  Widget _buildCollapsedCard() {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Favorite heart icon (left side)
            _buildFavoriteIcon(),
            const SizedBox(width: 12),
            // Middle: Title and Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recording Title with Tags on the right
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.recording.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tags row
                      _buildTagsRow(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Recording Date
                  Text(
                    widget.recording.createdAt.userFriendlyFormat,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right side: Duration
            Text(
              _formatTime(widget.recording.duration),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
    );
  }

  /// Build the expanded card state - full waveform and controls
  Widget _buildExpandedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECTION 1: Recording title and date (tappable to collapse)
          GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              height: 50,
              child: _buildRecordingInfo(),
            ),
          ),
          const SizedBox(height: 12),
          
          // SECTION 2: Waveform visualization with progress (NO tap gesture - allows dragging)
          SizedBox(
            height: 60,
            child: _buildWaveformSection(),
          ),
          const SizedBox(height: 16),
          
          // SECTION 3: Player controls (each button handles its own gestures)
          SizedBox(
            height: 50,
            child: _buildControlsRow(),
          ),
        ],
      ),
    );
  }

  /// Build recording information section (TOP PART)
  Widget _buildRecordingInfo() {
    return Row(
      children: [
        // Favorite heart icon (left side)
        _buildFavoriteIcon(),
        const SizedBox(width: 12),
        // Middle: Title, Tags, and Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with Tags on the right
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.recording.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tags
                  _buildTagsRow(),
                ],
              ),
              const SizedBox(height: 4),
              // Recording Date
              Text(
                widget.recording.createdAt.userFriendlyFormat,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build waveform visualization section (MIDDLE PART)
  Widget _buildWaveformSection() {
    // Show loading indicator while generating waveform
    if (_waveformData == null || _isGeneratingWaveform) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Pure visual waveform slider (no audio connection)
        Expanded(
          child: WaveformWidget(
            key: ValueKey('waveform_${widget.recording.id}'),
            amplitudes: _waveformData!,
            initialProgress: _waveformPosition,
            onPositionChanged: _handleWaveformPositionChanged,
          ),
        ),
        const SizedBox(height: 8),
        // Time display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(widget.currentPosition),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              _formatTime(widget.recording.duration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  /// Build control buttons row (BOTTOM PART)
  Widget _buildControlsRow() {
    return Row(
      children: [
        // BUTTON 1: Waveform/visualizer button
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const Icon(Icons.graphic_eq, color: Colors.blue, size: 24),
            onPressed: widget.onShowWaveform,
          ),
        ),

        // BUTTON 2: Skip backward 10 seconds
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.fast_rewind, color: Colors.white, size: 32),
                Positioned(
                  bottom: 8,
                  child: Text(
                    '10',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: widget.onSkipBackward,
          ),
        ),

        // BUTTON 3: Play/Pause button (center, largest)
        Expanded(
          flex: 3,
          child: Center(
            child: GestureDetector(
              onTap: widget.onPlayPause,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildPlayPauseIcon(),
              ),
            ),
          ),
        ),

        // BUTTON 4: Skip forward 10 seconds
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.fast_forward, color: Colors.white, size: 32),
                Positioned(
                  bottom: 8,
                  child: Text(
                    '10',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: widget.onSkipForward,
          ),
        ),

        // BUTTON 5: Delete button
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const FaIcon(FontAwesomeIcons.skull, color: Colors.blue, size: 24),
            onPressed: widget.onDelete,
          ),
        ),
      ],
    );
  }

  /// Build the play/pause icon based on current state
  Widget _buildPlayPauseIcon() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    } else if (widget.isPlaying) {
      return const Icon(
        Icons.pause,
        color: Colors.black,
        size: 32,
      );
    } else {
      return const Icon(
        Icons.play_arrow,
        color: Colors.black,
        size: 32,
      );
    }
  }

  /// Helper method to build individual control buttons
  Widget _buildControlButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: FractionallySizedBox(
            widthFactor: 0.7,
            heightFactor: 0.7,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: FittedBox(
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formats a Duration into MM:SS string format
  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}