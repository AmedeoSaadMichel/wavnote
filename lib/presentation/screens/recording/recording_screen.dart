// File: presentation/screens/recording/recording_screen.dart
// Minimal version for quick testing - replace with full version later

import 'package:flutter/material.dart';

class RecordingScreen extends StatelessWidget {
  final dynamic selectedFolder;
  final dynamic selectedFormat;

  const RecordingScreen({
    super.key,
    this.selectedFolder,
    this.selectedFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Screen'),
        backgroundColor: Colors.purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8E2DE2),
              Color(0xFFDA22FF),
              Color(0xFFFF4E50),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Recording Screen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Coming Soon!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}