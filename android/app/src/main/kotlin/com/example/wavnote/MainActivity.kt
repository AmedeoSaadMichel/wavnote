// File: android/app/src/main/kotlin/com/example/wavnote/MainActivity.kt
package com.example.wavnote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(AudioTrimmerPlugin())
  }
}
