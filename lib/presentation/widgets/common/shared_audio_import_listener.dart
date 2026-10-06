import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependency_injection.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../services/file/voice_memo_import_service.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../bloc/recording/recording_bloc.dart';

/// Checks the share inbox at cold launch and resume. Active recording sessions
/// defer the check until idle; a modal progress layer prevents starting one
/// while shared files are being committed.
class SharedAudioImportListener extends StatefulWidget {
  final Widget child;
  final GoRouter router;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const SharedAudioImportListener({
    super.key,
    required this.child,
    required this.router,
    required this.messengerKey,
  });

  @override
  State<SharedAudioImportListener> createState() =>
      _SharedAudioImportListenerState();
}

class _SharedAudioImportListenerState extends State<SharedAudioImportListener>
    with WidgetsBindingObserver {
  bool _requested = (defaultTargetPlatform == TargetPlatform.iOS);
  bool _busy = false;
  int _completed = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInbox());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((defaultTargetPlatform == TargetPlatform.iOS) &&
        state == AppLifecycleState.resumed) {
      _requested = true;
      _checkInbox();
    }
  }

  void _checkInbox() {
    if (!mounted || !_requested || _busy) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final state = context.read<RecordingBloc>().state;
    if (!state.canStartRecording) return;
    _requested = false;
    unawaited(_import());
  }

  Future<void> _import() async {
    final bloc = context.read<RecordingBloc>();
    final folderBloc = context.read<FolderBloc>();
    setState(() {
      _busy = true;
      _completed = 0;
      _total = 0;
    });
    try {
      final result = await VoiceMemoImportService(sl<IRecordingRepository>())
          .importPendingSharedAudio(
            folder: FolderEntity.defaultFolder(
              id: 'all_recordings',
              name: 'All Recordings',
              iconCodePoint: Icons.graphic_eq.codePoint,
              colorValue: 0xFF00FFFF,
            ),
            onProgress: (completed, total) {
              if (mounted) {
                setState(() {
                  _completed = completed;
                  _total = total;
                });
              }
            },
          );
      if (!mounted) return;
      if (result.imported > 0) {
        folderBloc.add(const LoadFolders());
        // Refresh the folder currently displayed, including empty folders.
        final segments =
            widget.router.routeInformationProvider.value.uri.pathSegments;
        if (segments.length == 2 && segments.first == 'folder') {
          bloc.add(LoadRecordings(folderId: segments.last));
        }
      }
      if (result.imported > 0 || result.failures.isNotEmpty) {
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 7),
            content: Text(
              'Memo vocali importati: ${result.imported} in Tutte le registrazioni.'
              '${result.failures.isEmpty ? '' : '\nNon importati: ${result.failures.length}. Riproveremo alla prossima apertura.'}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        widget.messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile controllare gli audio condivisi. Apri di nuovo WavNote per riprovare.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<RecordingBloc, RecordingState>(
        listener: (_, state) => _checkInbox(),
        child: Stack(
          children: [
            widget.child,
            if (_busy) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              Center(
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _total > 0
                              ? 'Importazione $_completed di $_total'
                              : 'Controllo degli audio condivisi…',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
