import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/services/api_client.dart';
import 'package:qotg_mobile/services/document_outbox.dart';
import 'package:qotg_mobile/services/local_draft_store.dart';

class _FailingStore extends LocalDraftStore {
  @override
  Future<void> write(String key, Map<String, dynamic> fields) async =>
      throw StateError('Full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('persists an immutable request before the first network attempt',
      () async {
    late DocumentOutbox queue;
    final input = <String, dynamic>{
      'customerName': 'Alex',
      'items': [
        {'description': 'Original'}
      ]
    };
    queue = DocumentOutbox(
        userId: 'user-a',
        companyId: 'company-a',
        autoSync: false,
        send: (request) async {
          final disk = await const LocalDraftStore().read(queue.key);
          expect((disk!['entries'] as List).single['status'], 'syncing');
          expect(request['fields']['items'][0]['description'], 'Original');
          expect(request['userId'], 'user-a');
          return {'success': true, 'documentId': request['documentId']};
        });
    addTearDown(queue.dispose);
    await queue.enqueue(
        requestId: 'request-one', documentType: 'invoice', fields: input);
    input['items'][0]['description'] = 'Mutated after saving';
    expect(queue.find('request-one')!['status'], 'pending');
    await queue.sync();
    expect(queue.find('request-one')!['status'], 'synced');
  });
  test('lost response and restart retry the same ID and body', () async {
    final server = <String, Map<String, dynamic>>{};
    final received = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>> send(Map<String, dynamic> request) async {
      received.add(request);
      server.putIfAbsent(request['documentId'], () => request);
      if (received.length == 1) throw TimeoutException('Response lost');
      return {'success': true, 'documentId': request['documentId']};
    }

    var queue = DocumentOutbox(
        userId: 'user-a', companyId: 'company-a', send: send, autoSync: false);
    await queue.enqueue(
        requestId: 'request-one',
        documentType: 'quotation',
        fields: {'customerName': 'Alex'});
    await queue.sync();
    expect(queue.find('request-one')!['status'], 'failed');
    queue.dispose();
    queue = DocumentOutbox(
        userId: 'user-a', companyId: 'company-a', send: send, autoSync: false);
    addTearDown(queue.dispose);
    await queue.sync();
    expect(server.length, 1);
    expect(received[0], received[1]);
    expect(queue.find('request-one')!['status'], 'synced');
  });
  test('a conflict retains changes and requires an explicit retry', () async {
    var attempts = 0;
    final queue = DocumentOutbox(
        userId: 'u',
        companyId: 'c',
        autoSync: false,
        send: (_) async {
          attempts++;
          throw const ApiException('Document changed on another device.', 409);
        });
    addTearDown(queue.dispose);
    await queue.enqueue(
        requestId: 'request-one',
        documentType: 'invoice',
        documentId: 'existing',
        expectedUpdatedAt: '2026-09-01T00:00:00.000Z',
        fields: {'notes': 'My edits'});
    await queue.sync();
    await queue.sync();
    expect(attempts, 1);
    expect(
        queue.find('request-one')!['request']['fields']['notes'], 'My edits');
    expect(queue.find('request-one')!['retryable'], false);
    await queue.retry('request-one');
    expect(attempts, 2);
  });
  test(
      'storage failure prevents network work and another account cannot load the queue',
      () async {
    var requests = 0;
    final failed = DocumentOutbox(
        userId: 'u',
        companyId: 'c',
        store: _FailingStore(),
        autoSync: false,
        send: (_) async {
          requests++;
          return {};
        });
    addTearDown(failed.dispose);
    await expectLater(
        failed.enqueue(
            requestId: 'request-one', documentType: 'invoice', fields: {}),
        throwsStateError);
    await failed.sync();
    expect(requests, 0);
    final queue = DocumentOutbox(userId: 'u', companyId: 'c', autoSync: false);
    await queue
        .enqueue(requestId: 'request-one', documentType: 'invoice', fields: {});
    queue.dispose();
    final other =
        DocumentOutbox(userId: 'other', companyId: 'c', autoSync: false);
    addTearDown(other.dispose);
    await other.ready;
    expect(other.entries, isEmpty);
  });
  test(
      'concurrent saves and duplicate button requests are serialized without losing work',
      () async {
    final queue = DocumentOutbox(userId: 'u', companyId: 'c', autoSync: false);
    addTearDown(queue.dispose);
    await Future.wait([
      queue.enqueue(
          requestId: 'request-one', documentType: 'invoice', fields: {}),
      queue.enqueue(
          requestId: 'request-two', documentType: 'quotation', fields: {}),
      queue.enqueue(
          requestId: 'request-one', documentType: 'invoice', fields: {}),
    ]);
    expect(queue.entries.length, 2);
    expect((await const LocalDraftStore().read(queue.key))!['entries'],
        hasLength(2));
  });
}
