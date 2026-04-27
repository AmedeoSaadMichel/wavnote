// File: lib/main.dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApp();
  runApp(const WavNoteApp());
}
