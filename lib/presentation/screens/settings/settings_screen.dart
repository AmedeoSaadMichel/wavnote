// File: presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/settings/settings_header.dart';
import '../../widgets/settings/audio_settings_section.dart';
import '../../widgets/settings/recording_settings_section.dart';
import '../../widgets/settings/app_settings_section.dart';
import '../../widgets/settings/storage_settings_section.dart';

/// Settings screen for app configuration
///
/// Allows users to configure audio format, quality settings,
/// storage options, and other app preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Settings state
  AudioFormat _selectedFormat = AppConstants.defaultAudioFormat;
  int _selectedSampleRate = AppConstants.defaultSampleRate;
  int _selectedBitRate = AppConstants.defaultBitRate;
  bool _enableLocationRecording = false;
  bool _enableAutoBackup = false;
  bool _enableHapticFeedback = true;
  bool _enableWaveformVisualization = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load current settings (placeholder - would load from storage)
  void _loadSettings() {
    setState(() {
      _selectedFormat = AudioFormat.m4a;
      _selectedSampleRate = 44100;
      _selectedBitRate = 128000;
    });
  }

  /// Save settings (placeholder - would save to storage)
  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings saved successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Update audio format
  void _updateAudioFormat(AudioFormat format) {
    setState(() {
      _selectedFormat = format;
      _selectedSampleRate = format.defaultSampleRate;
    });
    _saveSettings();
  }

  /// Update sample rate
  void _updateSampleRate(int sampleRate) {
    setState(() {
      _selectedSampleRate = sampleRate;
    });
    _saveSettings();
  }

  /// Update bit rate
  void _updateBitRate(int bitRate) {
    setState(() {
      _selectedBitRate = bitRate;
    });
    _saveSettings();
  }

  /// Update boolean settings
  void _updateBooleanSetting(String setting, bool value) {
    setState(() {
      switch (setting) {
        case 'location':
          _enableLocationRecording = value;
          break;
        case 'backup':
          _enableAutoBackup = value;
          break;
        case 'haptic':
          _enableHapticFeedback = value;
          break;
        case 'waveform':
          _enableWaveformVisualization = value;
          break;
      }
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.primaryGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                SettingsHeader(onSave: _saveSettings),

                // Settings content
                Expanded(
                  child: _buildSettingsContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build main settings content
  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio Settings Section
          AudioSettingsSection(
            selectedFormat: _selectedFormat,
            selectedSampleRate: _selectedSampleRate,
            selectedBitRate: _selectedBitRate,
            onFormatChanged: _updateAudioFormat,
            onSampleRateChanged: _updateSampleRate,
            onBitRateChanged: _updateBitRate,
          ),

          const SizedBox(height: AppConstants.largePadding),

          // Recording Settings Section
          RecordingSettingsSection(
            enableLocationRecording: _enableLocationRecording,
            enableWaveformVisualization: _enableWaveformVisualization,
            onLocationChanged: (value) => _updateBooleanSetting('location', value),
            onWaveformChanged: (value) => _updateBooleanSetting('waveform', value),
          ),

          const SizedBox(height: AppConstants.largePadding),

          // App Settings Section
          AppSettingsSection(
            enableHapticFeedback: _enableHapticFeedback,
            onHapticChanged: (value) => _updateBooleanSetting('haptic', value),
          ),

          const SizedBox(height: AppConstants.largePadding),

          // Storage Settings Section
          StorageSettingsSection(
            enableAutoBackup: _enableAutoBackup,
            onBackupChanged: (value) => _updateBooleanSetting('backup', value),
          ),

          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }
}