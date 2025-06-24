// File: presentation/widgets/recording/recording_waveform_section.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../domain/entities/recording_entity.dart';
import '../../../services/audio/audio_analysis_service.dart';
import 'waveform_widget.dart';

/// Widget for handling waveform display and generation
class RecordingWaveformSection extends StatefulWidget {
  final RecordingEntity recording;
  final double waveformPosition;
  final Duration currentPosition;
  final Function(double) onPositionChanged;

  const RecordingWaveformSection({
    Key? key,
    required this.recording,
    required this.waveformPosition,
    required this.currentPosition,
    required this.onPositionChanged,
  }) : super(key: key);

  @override
  State<RecordingWaveformSection> createState() => _RecordingWaveformSectionState();
}

class _RecordingWaveformSectionState extends State<RecordingWaveformSection> {
  List<double>? _waveformData;
  bool _isGeneratingWaveform = false;
  final AudioAnalysisService _audioAnalysisService = AudioAnalysisService();
  
  static final Map<String, List<double>> _waveformCache = {};

  @override
  void initState() {
    super.initState();
    _loadWaveformData();
  }

  @override
  void didUpdateWidget(RecordingWaveformSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.recording.id != widget.recording.id) {
      _loadWaveformData();
    }
  }

  Future<void> _loadWaveformData() async {
    final recordingId = widget.recording.id;
    
    if (_waveformCache.containsKey(recordingId)) {
      setState(() {
        _waveformData = _waveformCache[recordingId];
      });
      return;
    }

    if (!_isGeneratingWaveform) {
      setState(() {
        _isGeneratingWaveform = true;
      });

      try {
        final waveform = await _generateWaveformData(widget.recording);
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

  Future<List<double>> _generateWaveformData(RecordingEntity recording) async {
    if (recording.waveformData != null && recording.waveformData!.isNotEmpty) {
      print('🎉 Using REAL waveform data from recording! ${recording.waveformData!.length} points');
      return recording.waveformData!;
    }

    try {
      final waveformData = await _audioAnalysisService.extractWaveformFromFile(
        recording.filePath,
        sampleCount: 200,
      );
      
      if (waveformData.isNotEmpty) {
        return waveformData;
      } else {
        return _generateFallbackWaveform(recording);
      }
    } catch (e) {
      return _generateFallbackWaveform(recording);
    }
  }

  List<double> _generateFallbackWaveform(RecordingEntity recording) {
    final seed = recording.id.hashCode;
    final random = Random(seed);
    final List<double> amplitudes = [];

    for (int i = 0; i < 200; i++) {
      final position = i / 200.0;
      
      final syllablePattern = sin(position * pi * 20) * 0.3;
      final wordPattern = sin(position * pi * 5) * 0.2;
      final baseAmplitude = 0.4 + syllablePattern + wordPattern;
      
      final variation = (random.nextDouble() - 0.5) * 0.2;
      double amplitude = baseAmplitude + variation;
      
      if (position < 0.1) {
        amplitude *= position / 0.1;
      } else if (position > 0.9) {
        amplitude *= (1.0 - position) / 0.1;
      }
      
      if (random.nextDouble() < 0.03) {
        amplitude *= 0.1;
      }
      
      amplitudes.add(amplitude.clamp(0.0, 1.0));
    }
    
    return amplitudes;
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
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
        Expanded(
          child: WaveformWidget(
            key: ValueKey('waveform_${widget.recording.id}'),
            amplitudes: _waveformData!,
            initialProgress: widget.waveformPosition,
            onPositionChanged: widget.onPositionChanged,
          ),
        ),
        const SizedBox(height: 8),
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
}