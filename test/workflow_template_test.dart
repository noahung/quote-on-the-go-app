import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/screens/workflows/create_workflow_screen.dart';
import 'package:qotg_mobile/models/workflow.dart';
import 'package:qotg_mobile/models/built_in_workflows.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    for (final entry in jsonDecode(await rootBundle.loadString('FontManifest.json')) as List) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  for (final dark in [false, true]) {
    for (var index = 0; index < builtInWorkflowTemplates.length; index++) {
      testWidgets('workflow render $index dark=$dark at 320px and 200%', (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
          home: CreateWorkflowScreen(prefillTemplate: builtInWorkflowTemplates[index]),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workflow_${index}_${dark ? 'dark' : 'light'}.png'));
        for (var page = 0; page < 5; page++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -650));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }, tags: 'golden');
    }
  }
  for (final template in builtInWorkflowTemplates) {
    test('normalizes and round trips ${template['title']}', () {
      final parsed = WorkflowTemplate.fromJson(template);
      expect(parsed.triggerEvent, template['type']);
      expect(parsed.steps, isNotEmpty);
      expect(parsed.steps.every((s) => ['email', 'notification', 'wait'].contains(s.type)), isTrue);
      expect(WorkflowTemplate.fromJson(parsed.toJson()), parsed);
      if (template['type'] == 'quotation_sent') {
        expect(parsed.conditions!.single.value, '5000');
      }
    });
    testWidgets('opens built-in ${template['title']}', (tester) async {
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        home: CreateWorkflowScreen(prefillTemplate: template),
      )));
      expect(tester.takeException(), isNull);
      expect(find.text(template['title'] as String), findsOneWidget);
    });
  }
  for (final trigger in ['invoice_paid', {'event': 'invoice_paid'}, {'type': 'invoice_paid'}]) {
    test('legacy/current trigger $trigger accepts compatible numeric values', () {
      final parsed = WorkflowTemplate.fromJson({
        'trigger': trigger, 'maxRetries': '2', 'retryDelaySeconds': 30.0,
        'conditions': [{'field': 'amount', 'operator': 'greater_than', 'value': 5000}],
        'steps': [{'type': 'email', 'order': '0', 'delay': {'type': 'hours', 'value': '2'},
          'emailTemplate': {'subject': 'Subject', 'textContent': 'Body', 'includeOriginalDocument': true}}],
      });
      expect(parsed.triggerEvent, 'invoice_paid');
      expect(parsed.maxRetries, 2);
      expect(parsed.retryDelaySeconds, 30);
      expect(parsed.conditions!.single.value, '5000');
      expect(parsed.steps.single.delay!.value, 2);
      expect(parsed.steps.single.emailTemplate!['includeOriginalDocument'], true);
    });
  }
  for (final invalid in [
    {'steps': 'bad'}, {'steps': [null]}, {'steps': ['bad']},
    {'steps': [{'type': 'wait', 'delay': 'tomorrow'}]},
    {'steps': [{'type': 'wait', 'waitDays': 1.5}]},
    {'steps': [{'type': 'email', 'emailTemplate': 'bad'}]},
    {'conditions': [{}]}, {'maxRetries': 'bad'},
  ]) {
    test('rejects malformed data $invalid without dynamic type errors', () {
      expect(() => WorkflowTemplate.fromJson(invalid), throwsFormatException);
    });
  }
  testWidgets('invalid template shows recoverable explanation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CreateWorkflowScreen(
      prefillTemplate: {'steps': [{'type': 'send_sms'}]},
    ))));
    expect(tester.takeException(), isNull);
    expect(find.text('This template needs attention'), findsOneWidget);
    expect(find.text('Back to templates'), findsOneWidget);
  });
  testWidgets('display-string trigger opens without runtime error', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: CreateWorkflowScreen(prefillTemplate: {
        'title': 'High-Value Client Sequence',
        'trigger': 'QUOTE SENT > £5,000',
        'type': 'quotation_sent',
        'steps': [{'type': 'send_email', 'subject': 'Hello', 'body': 'Quote ready'}],
      }),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('High-Value Client Sequence'), findsOneWidget);
  });
}
