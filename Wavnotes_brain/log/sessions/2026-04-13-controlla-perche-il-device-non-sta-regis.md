# Session — 2026-04-13 — controlla perche' il device non sta registrando. e' venuto f

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-13 |
| **Durata** | ~4290 min |
| **Session ID** | `f7c5cc93` |

## Task discussi
- controlla perche' il device non sta registrando. e' venuto fuori questo problema da qualche giorno.
- 4 commit fa l'audio funzionava, spiegami quali sono le differenze e il perhce'
- Launching lib/main.dart on iPhone 16e in debug mode...
Xcode build done.                            
- non registra niente. metti da parte il codice di registrazione nativo. non lo eliminare ma ripristin
- metti le modifiche in stash

## File modificati
| File | Tipo modifica |
|------|--------------|
| `lib/services/audio/audio_service_coordinator.dart` | modifica |
| `lib/presentation/widgets/recording/bottom_sheet/recording_compact_view.dart` | modifica |
| `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart` | modifica |
| `lib/presentation/widgets/recording/bottom_sheet/control_buttons.dart` | modifica |
| `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | modifica |
| `ios/Runner.xcodeproj/project.pbxproj` | modifica |
| `ios/Runner/AppDelegate.swift` | modifica |
| `ios/Runner/AudioEnginePlugin.swift` | modifica |
| `lib/services/audio/audio_engine_service.dart` | modifica |
| `lib/presentation/bloc/recording/recording_event.dart` | modifica |
| `lib/presentation/bloc/recording/recording_state.dart` | modifica |
| `lib/presentation/bloc/recording/recording_bloc.dart` | modifica |
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | modifica |
| `lib/presentation/screens/recording/recording_list_logic.dart` | modifica |
| `lib/presentation/screens/recording/recording_list_screen.dart` | modifica |
| `lib/domain/repositories/i_audio_service_repository.dart` | modifica |
| `lib/services/audio/audio_player_service.dart` | modifica |
| `lib/services/audio/audio_recorder_service.dart` | modifica |
| `lib/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart` | modifica |
| `CLAUDE.md` | modifica |
| `lib/domain/usecases/recording/seek_and_resume_usecase.dart` | modifica |
| `lib/domain/usecases/recording/stop_recording_usecase.dart` | modifica |
| `macos/Runner/AudioEnginePlugin.swift` | modifica |
| `macos/Runner/AudioTrimmerPlugin.swift` | modifica |
| `macos/Runner/AppDelegate.swift` | modifica |
| `macos/Runner/DebugProfile.entitlements` | modifica |
| `macos/Runner/Release.entitlements` | modifica |
| `macos/Runner/Info.plist` | modifica |
| `macos/Runner.xcodeproj/project.pbxproj` | modifica |
| `macos/Runner/MainFlutterWindow.swift` | modifica |
| `lib/services/permission/permission_service.dart` | modifica |
| `macos/Runner/Configs/AppInfo.xcconfig` | modifica |

## Decisioni prese
- (da compilare manualmente se necessario)

## Next
- [ ] (da compilare)

## Tech debt aggiunto
- (nessuno)
