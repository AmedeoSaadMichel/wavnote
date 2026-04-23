# WavNote — Feature Map

_Aggiorna a fine sessione se hai toccato una feature._

## Core Audio
| Feature | File chiave | Stato |
|---------|------------|-------|
| Registrazione audio (start/stop/pause/resume) | `services/audio/audio_service_coordinator.dart` + `domain/usecases/recording/` | ✅ Completato |
| Motore nativo AVAudioEngine (iOS/macOS) | `services/audio/audio_engine_service.dart` | ✅ Completato (fix flusso dati ampiezza) |
| Fallback package `record` (non iOS) | `services/audio/audio_recorder_service.dart` | ✅ Presente (non attivo su iOS) |
| Overdubbing / seek-and-overwrite | `domain/usecases/recording/overwrite_recording_usecase.dart` | ✅ Completato |
| Playback preview durante pausa overdub | `audio_service_coordinator.dart` (`_nativePlaybackActive` + native engine) | ✅ Fix ripristinato 2026-04-17 |
| Playback audio (seek, rewind, forward) | `services/audio/audio_player_service.dart` + `recording_list_logic.dart` | ✅ Completato |
| Trim audio | `services/audio/audio_trimmer_service.dart` + channel `wavnote/audio_trimmer` | ✅ Presente |
| Formati WAV / M4A / FLAC | `core/enums/audio_format.dart` | ✅ Completato |
| Sample rate configurabile | `presentation/widgets/dialogs/sample_rate_dialog.dart` | ✅ Completato |

## Waveform
| Feature                                  | File chiave                                               | Stato                        |
| ---------------------------------------- | --------------------------------------------------------- | ---------------------------- |
| Waveform live durante registrazione      | `presentation/widgets/recording/custom_waveform/`         | ✅ Completato (fix flusso)   |
| Waveform playback (audio_waveforms)      | `presentation/widgets/recording/waveform_widget.dart`     | ✅ Completato                 |
| Waveform a colori per segmenti overwrite | `recorder_wave_painter.dart` (_kSegmentPalette)           | ✅ Completato                 |
| Waveform fullscreen                      | `presentation/widgets/recording/fullscreen_waveform.dart' | ✅ Completato                 |
| Seek tramite tap su waveform             | `recording_list_logic.dart`                               | ⚠️ Parziale (vedi tech-debt) |

## Organizzazione
| Feature | File chiave | Stato |
|---------|------------|-------|
| Gestione cartelle (CRUD) | `presentation/bloc/folder/` + `data/repositories/folder_repository.dart` | ✅ Completato |
| Recently Deleted (soft delete, 15 giorni) | `domain/entities/recording_entity.dart` (softDelete/restore) | ✅ Completato |
| Spostamento tra cartelle | `RecordingEntity.moveToFolder()` | ✅ Completato |
| Preferiti (isFavorite) | `RecordingEntity.markAsFavorite()` | ✅ Completato |
| Tag sulle registrazioni | `RecordingEntity.addTag/removeTag()` | ✅ Modello pronto, UI da verificare |

## Ricerca & Filtri
| Feature | File chiave | Stato |
|---------|------------|-------|
| Search bar | `presentation/widgets/inputs/search_bar.dart` | ✅ Completato |
| Pull-to-search | `presentation/widgets/recording/pull_to_search_list.dart` | ✅ Completato |
| Ordinamento registrazioni | `data/mappers/recording_sort_mapper.dart` | ✅ Completato |
| Ordinamento cartelle | `data/mappers/folder_sort_mapper.dart` | ✅ Completato |
| Repository search | `data/repositories/recording_repository_search.dart` | ✅ Completato |

## Geolocalizzazione
| Feature | File chiave | Stato |
|---------|------------|-------|
| Naming basato su posizione GPS | `services/location/geolocation_service.dart` | ✅ Completato (iOS + macOS) |
| Coordinate su RecordingEntity | `latitude`, `longitude`, `locationName` | ✅ Completato |

## UI / UX
| Feature | File chiave | Stato |
|---------|------------|-------|
| Bottom sheet compact / fullscreen | `presentation/widgets/recording/bottom_sheet/` | ✅ Completato |
| RecordPupilButton (bottone giallo animato) | `bottom_sheet/recording_compact_view.dart` + `fullscreen_view.dart` | ✅ Completato |
| Skeleton loading screen | `presentation/widgets/common/skeleton_screen.dart` | ✅ Completato |
| Recording card con azioni | `presentation/widgets/recording/recording_card/` | ✅ Completato |
| Edit toolbar | `presentation/widgets/recording/recording_edit_toolbar.dart` | ✅ Presente |
| Dialogs (cartella, formato, sample rate) | `presentation/widgets/dialogs/` | ✅ Completato |
| Settings screen | `presentation/screens/settings/` + `presentation/widgets/settings/` | ✅ Completato |

## File & Export
| Feature | File chiave | Stato |
|---------|------------|-------|
| Export registrazioni | `services/file/export_service.dart` | ✅ Presente |
| Import registrazioni | `services/file/import_service.dart` | ✅ Presente |
| Metadata service | `services/file/metadata_service.dart` | ✅ Presente |
| File manager | `services/file/file_manager_service.dart` | ✅ Presente |

## Debug / Infrastruttura
| Feature | File chiave | Stato |
|---------|------------|-------|
| SwiftLogPlugin bridge (EventChannel) | `services/logging/swift_log_channel_service.dart` | ⚠️ Solo debug, da rimuovere prima del rilascio |
| Performance logger | `core/utils/performance_logger.dart` | ✅ Presente |
| Native splash screen | flutter_native_splash (#8E2DE2) | ✅ Configurato |
