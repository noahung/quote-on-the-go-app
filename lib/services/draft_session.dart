import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_draft_store.dart';

/// Serialises local writes so an older save cannot resurrect a cleared draft.
class DraftSession extends ChangeNotifier {
  DraftSession(
      {required this.store,
      required this.key,
      required Map<String, dynamic> initial})
      : _initial = jsonEncode(initial),
        _current = jsonEncode(initial);
  final LocalDraftStore store;
  final String key;
  final String _initial;
  String _current;
  Map<String, dynamic>? recovery;
  bool ready = false, saving = false, saved = false;
  String? error;
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool get locked => !ready || recovery != null;
  bool get hasChanges => _current != _initial;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    error = null;
    try {
      recovery = await store.read(key);
      ready = true;
    } catch (_) {
      error = 'Could not read the draft on this device. Retry before editing.';
    }
    _notify();
  }

  void recoveryFailed() {
    error =
        'This saved draft could not be restored. Try again or discard it to start fresh.';
    _notify();
  }

  void changed(Map<String, dynamic> fields) {
    if (locked || _disposed) return;
    try {
      final value = jsonEncode(fields);
      if (value == _current) return;
      _current = value;
      saved = false;
      error = null;
      _timer?.cancel();
      _timer =
          Timer(const Duration(milliseconds: 350), () => unawaited(flush()));
      _notify();
    } catch (_) {
      error =
          'Some values could not be saved on this device. Check the form before leaving.';
      _notify();
    }
  }

  Map<String, dynamic> restore() {
    final fields = recovery!;
    _current = jsonEncode(fields);
    recovery = null;
    saved = true;
    error = null;
    _notify();
    return fields;
  }

  Future<void> discardRecovery() async {
    await _enqueue(() => store.remove(key));
    if (error == null) {
      recovery = null;
      ready = true;
      saved = false;
      _notify();
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _writes = _writes.then((_) async {
      saving = true;
      error = null;
      _notify();
      try {
        await action();
      } catch (_) {
        error =
            'Could not save changes on this device. Free up storage and try again.';
      } finally {
        saving = false;
        _notify();
      }
    });
    return _writes;
  }

  Future<bool> flush() async {
    _timer?.cancel();
    if (locked) return error == null;
    final snapshot = _current;
    await _enqueue(() => snapshot == _initial
        ? store.remove(key)
        : store.write(key, jsonDecode(snapshot) as Map<String, dynamic>));
    saved = error == null && _current == snapshot && hasChanges;
    _notify();
    return error == null;
  }

  Future<void> complete() async {
    _timer?.cancel();
    await _enqueue(() => store.remove(key));
    // Prevent dispose from saving the just-submitted data again.
    _current = _initial;
    recovery = null;
    saved = false;
    _notify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
