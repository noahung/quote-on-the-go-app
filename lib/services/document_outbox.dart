import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'local_draft_store.dart';

typedef DocumentSyncSender = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> request);

/// Persists an immutable request before attempting the network. The server's
/// receipt makes a retry safe even when its previous response was lost.
class DocumentOutbox extends ChangeNotifier {
  DocumentOutbox(
      {required this.userId,
      required this.companyId,
      this.store = const LocalDraftStore(),
      DocumentSyncSender? send,
      this.autoSync = true})
      : _send = send ??
            ((body) => ApiClient.post('/api/mobile/document-sync', body)) {
    ready = _load();
    if (autoSync) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
      unawaited(ready.then((_) => sync()));
    }
  }
  final String userId, companyId;
  final bool autoSync;
  final LocalDraftStore store;
  final DocumentSyncSender _send;
  late final Future<void> ready;
  String get key => store.key(userId, companyId, 'document-outbox');
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> get entries =>
      List.unmodifiable(_entries.map((entry) =>
          Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)) as Map)));
  int get pendingCount =>
      _entries.where((entry) => entry['status'] != 'synced').length;
  String? storageError;
  bool loaded = false, _disposed = false;
  Future<void> _writes = Future.value();
  Future<void>? _syncing;
  Timer? _timer;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Map<String, dynamic>? find(String? requestId) {
    for (final entry in entries) {
      if (entry['requestId'] == requestId) return entry;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final stored = await store.read(key);
      final entries = stored?['entries'];
      if (entries != null && entries is! List) throw const FormatException();
      _entries = (entries as List? ?? [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      for (final entry in _entries) {
        if (entry['requestId'] is! String ||
            entry['request'] is! Map ||
            !['pending', 'syncing', 'failed', 'synced']
                .contains(entry['status'])) {
          throw const FormatException();
        }
        if (entry['status'] == 'syncing') entry['status'] = 'pending';
      }
      loaded = true;
      storageError = null;
    } catch (_) {
      loaded = false;
      storageError =
          'Could not read saved requests on this device. Try again before saving more work.';
    }
    _notify();
  }

  Future<void> reload() async {
    await _load();
    if (loaded) await sync();
  }

  Future<void> _commit(void Function(List<Map<String, dynamic>>) change) {
    final operation = _writes.then((_) async {
      final next = (jsonDecode(jsonEncode(_entries)) as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      change(next);
      try {
        await store.write(key, {'entries': next});
        _entries = next;
        storageError = null;
        _notify();
      } catch (_) {
        storageError =
            'Could not save requests on this device. Free up storage and try again. Your editor draft is kept.';
        _notify();
        rethrow;
      }
    });
    _writes = operation.catchError((_) {});
    return operation;
  }

  Future<Map<String, dynamic>> enqueue(
      {required String requestId,
      required String documentType,
      required Map<String, dynamic> fields,
      String? documentId,
      String? expectedUpdatedAt,
      String? actionKey}) async {
    await ready;
    if (!loaded || _disposed) {
      throw StateError(storageError ?? 'Sign in again before saving.');
    }
    final existing = find(requestId);
    if (existing != null) return existing;
    final entry = <String, dynamic>{
      'requestId': requestId,
      'status': 'pending',
      'retryable': true,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      if (actionKey != null) 'actionKey': actionKey,
      'request': {
        'requestId': requestId,
        'userId': userId,
        'companyId': companyId,
        'documentId': documentId ?? requestId,
        'documentType': documentType,
        'mode': documentId == null ? 'create' : 'update',
        'expectedUpdatedAt': expectedUpdatedAt,
        'fields': fields
      }
    };
    var savedRequestId = requestId;
    await _commit((entries) {
      if (entries.any((item) => item['requestId'] == requestId)) return;
      // Reopening a copy/conversion while it is waiting must retry the same
      // immutable request, including after a restart or a lost response.
      if (actionKey != null) {
        for (final item in entries.reversed) {
          if (item['actionKey'] == actionKey && item['status'] != 'synced') {
            savedRequestId = item['requestId'] as String;
            return;
          }
        }
      }
      if (entries.where((item) => item['status'] != 'synced').length >= 50) {
        throw StateError('Sync your saved requests before adding more.');
      }
      entries
          .add(Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)) as Map));
    });
    if (autoSync) unawaited(sync());
    return find(savedRequestId)!;
  }

  Future<void> retry(String requestId) async {
    await ready;
    await _commit((entries) {
      for (final entry in entries) {
        if (entry['requestId'] == requestId && entry['status'] == 'failed') {
          entry['status'] = 'pending';
          entry['retryable'] = true;
          entry.remove('error');
        }
      }
    });
    await sync();
  }

  Future<void> sync() {
    if (_disposed) return Future.value();
    return _syncing ??= _drain().whenComplete(() => _syncing = null);
  }

  Future<void> _drain() async {
    await ready;
    if (!loaded || _disposed) return;
    // One attempt per entry per pass; failures never spin in a tight loop.
    final ids = _entries
        .where((entry) =>
            ['pending', 'syncing'].contains(entry['status']) ||
            entry['status'] == 'failed' && entry['retryable'] == true)
        .map((entry) => entry['requestId'] as String)
        .toList();
    for (final id in ids) {
      if (_disposed) return;
      try {
        await _commit((entries) =>
            entries.firstWhere((entry) => entry['requestId'] == id)['status'] =
                'syncing');
        final request = Map<String, dynamic>.from(find(id)!['request'] as Map);
        try {
          final result = await _send(request);
          if (result['success'] != true ||
              result['documentId'] != request['documentId']) {
            throw const ApiException(
                'The server did not confirm this save. Try again.', 503);
          }
          if (_disposed) return;
          await _commit((entries) {
            final entry =
                entries.firstWhere((entry) => entry['requestId'] == id);
            entry['status'] = 'synced';
            entry.remove('error');
          });
        } catch (error) {
          if (_disposed) return;
          await _commit((entries) {
            final entry =
                entries.firstWhere((entry) => entry['requestId'] == id);
            entry['status'] = 'failed';
            entry['retryable'] = error is! ApiException || error.retryable;
            entry['errorCode'] =
                error is ApiException ? error.statusCode : null;
            entry['error'] = error is ApiException
                ? error.message
                : 'Waiting for a connection. Saved on this device; we will try again while the app is open.';
          });
        }
      } catch (_) {
        return;
      } // Keep the persisted request if local storage fails.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
