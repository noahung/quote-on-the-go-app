import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_draft_store.dart';
import '../../services/draft_session.dart';
import '../../components/draft_status_banner.dart';
import '../../providers/document_outbox_provider.dart';
import 'package:uuid/uuid.dart';

mixin LocalDraftMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  DraftSession? draftSession;
  bool _draftCompleted = false;
  bool _allowDraftPop = false;
  String? _saveRequestId;
  Map<String, dynamic> _captureWithRequest() => {
        ...captureDraft(),
        if (_saveRequestId != null) '__saveRequestId': _saveRequestId
      };
  ProviderSubscription<dynamic>? _profileSubscription;
  late final _lifecycle = _DraftLifecycleObserver(() {
    if (!_draftCompleted) unawaited(draftSession?.flush());
  });
  String get localDraftContext;
  String get draftExitPath;
  Map<String, dynamic> captureDraft();
  void applyDraft(Map<String, dynamic> fields);
  List<TextEditingController> get draftTextControllers;
  bool get draftLocked =>
      draftSession == null ||
      draftSession!.locked ||
      ref.read(documentOutboxProvider)?.find(_saveRequestId) != null;

  Future<void> initializeLocalDraft() async {
    if (!mounted || draftSession != null) return;
    final profile = ref.read(userProfileProvider);
    if (profile == null) {
      _profileSubscription ??= ref.listenManual(userProfileProvider, (_, next) {
        if (next != null) initializeLocalDraft();
      });
      return;
    }
    _profileSubscription?.close();
    _profileSubscription = null;
    const store = LocalDraftStore();
    draftSession = DraftSession(
        store: store,
        key: store.key(profile.uid, profile.companyId, localDraftContext),
        initial: _captureWithRequest());
    draftSession!.addListener(_refreshDraft);
    for (final controller in draftTextControllers) {
      controller.addListener(_captureChangedDraft);
    }
    WidgetsBinding.instance.addObserver(_lifecycle);
    await draftSession!.load();
  }

  void _refreshDraft() {
    if (mounted) super.setState(() {});
  }

  void _captureChangedDraft() {
    if (!_draftCompleted) draftSession?.changed(_captureWithRequest());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _captureChangedDraft();
  }

  Widget draftBanner() {
    final queue = ref.watch(documentOutboxProvider);
    final requestId =
        draftSession?.recovery?['__saveRequestId'] as String? ?? _saveRequestId;
    if (queue?.find(requestId) != null) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'This editor copy has already been queued for saving. Review its status before making further changes.'),
            TextButton(
                onPressed: () => context.go('/settings/saves'),
                child: const Text('View saved requests')),
            TextButton(
                onPressed: () async {
                  await completeLocalDraft();
                  await leaveDraftEditor();
                },
                child: const Text('Close editor copy')),
          ]));
    }
    return DraftStatusBanner(
        session: draftSession,
        onRestore: () {
          final fields = draftSession!.recovery!;
          final previous = captureDraft();
          // Apply all fields together before the next autosave.
          _draftCompleted = true;
          try {
            setState(() => applyDraft(fields));
            _saveRequestId = fields['__saveRequestId'] as String?;
            draftSession!.restore();
          } catch (_) {
            setState(() => applyDraft(previous));
            draftSession!.recoveryFailed();
          } finally {
            _draftCompleted = false;
          }
        });
  }

  Future<void> queueDocumentSave(
      {required String documentType,
      required Map<String, dynamic> fields,
      String? documentId,
      String? expectedUpdatedAt,
      required bool preview}) async {
    final queue = ref.read(documentOutboxProvider);
    if (queue == null || draftSession == null) {
      throw StateError('Your account is unavailable.');
    }
    if (draftSession!.key !=
        const LocalDraftStore()
            .key(queue.userId, queue.companyId, localDraftContext)) {
      throw StateError('Reopen this editor for your current company.');
    }
    _saveRequestId ??= const Uuid().v4();
    _captureChangedDraft();
    if (!await draftSession!.flush()) {
      throw StateError('The request identity could not be saved.');
    }
    await queue.enqueue(
        requestId: _saveRequestId!,
        documentType: documentType,
        fields: fields,
        documentId: documentId,
        expectedUpdatedAt: expectedUpdatedAt);
    await completeLocalDraft();
    if (mounted) {
      context.go(
          '/settings/saves?request=$_saveRequestId&preview=${preview ? '1' : '0'}');
    }
  }

  Widget guardDraftExit(Widget child) => PopScope(
      canPop: _allowDraftPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leaveDraftEditor();
      },
      child: child);

  Future<void> leaveDraftEditor() async {
    if (!_draftCompleted && draftSession != null) {
      final saved = await draftSession!.flush();
      if (!saved) {
        if (!mounted) return;
        final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Leave without saving on this device?'),
                  content: const Text(
                      'Your latest changes could not be saved. Stay to retry, or leave and lose those changes.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Stay and retry')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Leave anyway'))
                  ],
                ));
        if (leave != true) return;
      }
    }
    if (!mounted) return;
    super.setState(() => _allowDraftPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(draftExitPath);
    }
  }

  Future<void> completeLocalDraft() async {
    _draftCompleted = true;
    await draftSession?.complete();
    if (mounted) super.setState(() => _allowDraftPop = true);
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void dispose() {
    _profileSubscription?.close();
    WidgetsBinding.instance.removeObserver(_lifecycle);
    for (final controller in draftTextControllers) {
      controller.removeListener(_captureChangedDraft);
    }
    final session = draftSession;
    session?.removeListener(_refreshDraft);
    if (session != null) {
      final flush = _draftCompleted ? Future.value(true) : session.flush();
      unawaited(flush.whenComplete(session.dispose));
    }
    super.dispose();
  }
}

class _DraftLifecycleObserver extends WidgetsBindingObserver {
  _DraftLifecycleObserver(this.flush);
  final VoidCallback flush;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) flush();
  }
}
