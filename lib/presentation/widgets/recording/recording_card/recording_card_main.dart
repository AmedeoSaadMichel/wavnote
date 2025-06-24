// File: presentation/widgets/recording/recording_card/recording_card_main.dart
import 'package:flutter/material.dart';
import '../../../../domain/entities/recording_entity.dart';
import 'recording_card_info.dart';
import 'recording_card_actions.dart';
import '../recording_controls.dart';

/// Recording Card with Audio Slider
///
/// This widget displays recording information with a simple audio progress slider.
/// Audio playback state is managed at the screen level.
class RecordingCard extends StatefulWidget {
  final RecordingEntity recording;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback onShowWaveform; // For fullscreen player view
  final VoidCallback onDelete;
  final VoidCallback onMoveToFolder;
  final VoidCallback onMoreActions;
  final VoidCallback? onRestore; // Callback for restore action
  final VoidCallback? onToggleFavorite; // Callback for toggle favorite
  
  // Audio state passed from parent
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration? actualDuration; // Actual duration from audio player (when expanded)
  
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
    this.actualDuration,
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
  double _sliderPosition = 0.0;
  bool _wasPlayingLastUpdate = false;
  
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
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: -240.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));
    
    _swipeAnimation.addListener(() {
      setState(() {
        _swipeOffset = _swipeAnimation.value;
      });
    });
    
    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _favoriteAnimation = Tween<double>(
      begin: 0.0,
      end: 80.0,
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
    
    if (oldWidget.recording.id != widget.recording.id) {
      _sliderPosition = 0.0;
    }
    
    // Detect when audio stops playing (end of recording)
    if (widget.isExpanded && _wasPlayingLastUpdate && !widget.isPlaying) {
      final actualDuration = widget.actualDuration ?? widget.recording.duration;
      final totalDurationMs = actualDuration.inMilliseconds;
      final currentPositionMs = widget.currentPosition.inMilliseconds;
      final isNearEnd = (totalDurationMs - currentPositionMs) <= 500; // Within 500ms of end
      
      print('🔚 Audio stopped - Position: ${currentPositionMs}ms/${totalDurationMs}ms (actual), Near end: $isNearEnd');
      
      if (isNearEnd) {
        print('🔚 Recording finished, resetting slider to beginning');
        // Reset slider to beginning when recording finishes
        setState(() {
          _sliderPosition = 0.0;
        });
        // Note: Audio player position will be reset by the audio player manager
      }
    }
    
    _wasPlayingLastUpdate = widget.isPlaying;
    _syncSliderWithAudio();
  }
  
  void _syncSliderWithAudio() {
    // Use actual audio player duration when available, fallback to recording duration
    final actualDuration = widget.actualDuration ?? widget.recording.duration;
    final totalDurationMs = actualDuration.inMilliseconds;
    final currentPositionMs = widget.currentPosition.inMilliseconds;
    
    if (totalDurationMs > 0 && widget.isExpanded) {
      // Precise millisecond-based calculation using actual audio duration
      final audioProgress = currentPositionMs / totalDurationMs;
      final clampedProgress = audioProgress.clamp(0.0, 1.0);
      
      // Always update slider position to match audio precisely
      if ((clampedProgress - _sliderPosition).abs() > 0.001) {
        setState(() {
          _sliderPosition = clampedProgress;
        });
      }
    }
  }

  void _handleSliderChanged(double position) {
    setState(() {
      _sliderPosition = position;
    });
    widget.onSeek(position);
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
          Positioned.fill(
            child: RecordingCardActions(
              isSwipeActionsVisible: _isSwipeActionsVisible,
              isFavoriteActionVisible: _isFavoriteActionVisible,
              isFavorite: widget.recording.isFavorite,
              currentFolderId: widget.currentFolderId,
              onRestore: () {
                _hideFavoriteAction();
                widget.onRestore?.call();
              },
              onDelete: () {
                _hideSwipeActions();
                widget.onDelete();
              },
              onMoreActions: () {
                _hideSwipeActions();
                widget.onMoreActions();
              },
              onMoveToFolder: () {
                _hideSwipeActions();
                widget.onMoveToFolder();
              },
              onToggleFavorite: () {
                _hideFavoriteAction();
                widget.onToggleFavorite?.call();
              },
            ),
          ),
          
          Transform.translate(
            offset: Offset(_swipeOffset + _favoriteOffset, 0),
            child: widget.isExpanded ? _buildExpandedCard() : _buildCollapsedCard(),
          ),
          
          if (widget.isEditMode) _buildSelectionOverlay(),
        ],
      ),
    );
  }

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
          Expanded(
            child: RecordingCardInfo(
              recording: widget.recording,
              currentFolderId: widget.currentFolderId,
              folderNames: widget.folderNames,
              onToggleFavorite: widget.onToggleFavorite,
            ),
          ),
          const SizedBox(width: 12),
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
          GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              height: 50,
              child: RecordingCardInfo(
                recording: widget.recording,
                currentFolderId: widget.currentFolderId,
                folderNames: widget.folderNames,
                onToggleFavorite: widget.onToggleFavorite,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Audio progress slider
          _buildAudioSlider(),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 50,
            child: RecordingControls(
              isPlaying: widget.isPlaying,
              isLoading: widget.isLoading,
              onShowWaveform: widget.onShowWaveform,
              onSkipBackward: widget.onSkipBackward,
              onPlayPause: widget.onPlayPause,
              onSkipForward: widget.onSkipForward,
              onDelete: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }






  /// Build audio progress slider
  Widget _buildAudioSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              activeTrackColor: Colors.red,
              inactiveTrackColor: Colors.grey[600],
              thumbColor: Colors.red,
              overlayColor: Colors.red.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _sliderPosition,
              min: 0.0,
              max: 1.0,
              onChanged: widget.isLoading ? null : _handleSliderChanged,
            ),
          ),
          
          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(widget.currentPosition),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatTime(widget.recording.duration),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}