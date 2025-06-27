// File: presentation/screens/recording/audio_player_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../domain/entities/recording_entity.dart';

/// Manages audio player functionality for RecordingListScreen
/// Extracted to reduce screen file size while keeping identical functionality
class AudioPlayerManager {
  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Audio playback state
  String? _expandedRecordingId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasCompletedCurrentPlayback = false; // Flag to prevent multiple completion triggers
  
  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Callbacks for state updates
  VoidCallback? _onStateChanged;

  // Getters for current state
  String? get expandedRecordingId => _expandedRecordingId;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  AudioPlayer get audioPlayer => _audioPlayer;

  /// Initialize audio player with state change callback
  void initialize(VoidCallback onStateChanged) {
    _onStateChanged = onStateChanged;
    _setupAudioListeners();
  }

  /// Setup audio player listeners
  void _setupAudioListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      _position = position;
      if (_duration.inMilliseconds > 0) {
        final percentage = (position.inMilliseconds / _duration.inMilliseconds * 100);
        print('🕒 Position: ${_formatTime(position)} / ${_formatTime(_duration)} (${percentage.toStringAsFixed(1)}%)');
        
        // Trigger completion when we reach 99% to avoid overrun
        if (percentage >= 99.0 && _isPlaying && !_hasCompletedCurrentPlayback) {
          print('🔚 Audio reached 99%, triggering completion');
          _hasCompletedCurrentPlayback = true;
          _position = Duration.zero;
          _isPlaying = false;
          _onStateChanged?.call();
          
          _audioPlayer.pause().then((_) {
            print('🔚 Audio paused at 99%');
            return _audioPlayer.seek(Duration.zero);
          }).then((_) {
            print('🔚 Audio reset to beginning from 99% threshold');
          }).catchError((e) {
            print('❌ Error pausing/seeking at 99%: $e');
          });
        }
      } else {
        print('🕒 Position: ${_formatTime(position)} / ${_formatTime(_duration)} (duration not set)');
      }
      _onStateChanged?.call();
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero) {
        final oldDuration = _duration;
        _duration = duration;
        print('🕒 Duration changed: ${_formatTime(oldDuration)} → ${_formatTime(duration)}');
        _onStateChanged?.call();
      } else if (duration != null) {
        print('🕒 Audio player reported zero duration, keeping current: ${_formatTime(_duration)}');
      }
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('🎵 Player state changed: playing=${state.playing}, processingState=${state.processingState}');
      
      // Note: Completion is now handled in positionStream at 99% threshold
      
      // Debug all state changes
      print('🎵 Audio state: playing=${state.playing}, processing=${state.processingState}');
      
      _onStateChanged?.call();
    });
  }

  /// Expand/collapse recording
  Future<void> expandRecording(RecordingEntity recording) async {
    if (_expandedRecordingId == recording.id) {
      // Collapse current recording
      await _audioPlayer.stop();
      _expandedRecordingId = null;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _onStateChanged?.call();
    } else {
      // Expand new recording
      await setupAudioForRecording(recording);
    }
  }

  /// Setup audio for a recording
  Future<void> setupAudioForRecording(RecordingEntity recording) async {
    _isLoading = true;
    _onStateChanged?.call();

    try {
      // STEP 1: Check if file exists, if not try to find it in current app directory
      String workingFilePath = recording.filePath;
      File file = File(workingFilePath);
      
      if (!await file.exists()) {
        // Try to migrate path to current app container
        workingFilePath = await _tryMigrateFilePath(recording.filePath);
        file = File(workingFilePath);
        
        if (!await file.exists()) {
          throw Exception('Recording file not found: ${recording.filePath}');
        }
        
        print('📁 Migrated file path: ${recording.filePath} -> $workingFilePath');
      }
      
      // STEP 2: Validate file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Recording file is empty: $workingFilePath');
      }
      
      print('📁 Validating file: $workingFilePath');
      print('📦 File size: $fileSize bytes');
      print('🎵 Expected format: ${recording.format.name}');

      // STEP 3: Setup audio player with working file path
      print('🔧 Setting up audio player...');
      await _audioPlayer.setFilePath(workingFilePath);
      
      // STEP 4: Get actual audio properties from player
      final playerDuration = _audioPlayer.duration;
      print('🎵 Player reported duration: ${playerDuration != null ? _formatTime(playerDuration) : 'null'}');
      print('🎵 Expected duration: ${_formatTime(recording.duration)}');
      print('🎵 Sample rate: ${recording.sampleRate} Hz');
      print('🎵 Audio format: ${recording.format.name}');

      _expandedRecordingId = recording.id;
      _position = Duration.zero;
      _duration = recording.duration; // Use the recording's known duration
      _isPlaying = false;
      _isLoading = false;
      _hasCompletedCurrentPlayback = false; // Reset completion flag for new recording

      print('✅ Audio setup complete for: ${recording.name}');
      print('📁 Working file path: $workingFilePath');
      print('📦 File size: $fileSize bytes');
      print('🕒 Recording duration: ${_formatTime(recording.duration)}');
      
    } catch (e) {
      print('❌ Error setting up audio: $e');
      print('📁 Failed file path: ${recording.filePath}');
      
      _isLoading = false;
      
      // Return error message for UI to handle
      throw e;
    }
    
    _onStateChanged?.call();
  }

  /// Toggle playback
  Future<void> togglePlayback() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        // Reset completion flag when starting new playback
        _hasCompletedCurrentPlayback = false;
        
        // Handle completed state
        if (_position >= _duration && _duration > Duration.zero) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      print('❌ Error toggling playback: $e');
    }
  }

  /// Seek to position
  void seekToPosition(double percent) {
    final effectiveDuration = _duration > Duration.zero ? _duration : const Duration(seconds: 1);
    final target = Duration(milliseconds: (effectiveDuration.inMilliseconds * percent).round());
    
    print('🎯 Target position: ${_formatTime(target)} of ${_formatTime(effectiveDuration)}');
    _audioPlayer.seek(target);
  }

  /// Skip backward 10 seconds
  void skipBackward() {
    final newPosition = Duration(milliseconds: (_position.inMilliseconds - 10000).clamp(0, _duration.inMilliseconds));
    _audioPlayer.seek(newPosition);
  }

  /// Skip forward 10 seconds
  void skipForward() {
    final newPosition = Duration(milliseconds: (_position.inMilliseconds + 10000).clamp(0, _duration.inMilliseconds));
    _audioPlayer.seek(newPosition);
  }

  /// Try to migrate file path to current app container
  Future<String> _tryMigrateFilePath(String oldPath) async {
    try {
      // Get current app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final currentDocumentsPath = documentsDir.path;
      
      // Extract the relative path from old path (everything after /Documents/)
      final documentsIndex = oldPath.indexOf('/Documents/');
      if (documentsIndex == -1) {
        return oldPath; // Return original if can't parse
      }
      
      final relativePath = oldPath.substring(documentsIndex + '/Documents/'.length);
      final newPath = path.join(currentDocumentsPath, relativePath);
      
      print('🔄 Attempting path migration:');
      print('   Old: $oldPath');
      print('   New: $newPath');
      print('   Relative: $relativePath');
      
      return newPath;
    } catch (e) {
      print('❌ Error migrating path: $e');
      return oldPath; // Return original on error
    }
  }

  /// Format time helper
  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Get the currently expanded recording
  RecordingEntity? getCurrentlyExpandedRecording(List<RecordingEntity> recordings) {
    if (_expandedRecordingId == null) return null;
    
    try {
      return recordings.firstWhere((recording) => recording.id == _expandedRecordingId);
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
  }
}