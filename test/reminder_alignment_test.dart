import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/user_profile.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/screens/settings/reminder_settings_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

class _FailedSaveRepository implements ReminderRepository {
  ReminderSettings? captured;
  @override
  Future<void> updateReminderSettings(
      String companyId, ReminderSettings settings) async {
    captured = settings;
    throw Exception('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final repository = _FailedSaveRepository();
  final fixture = ReminderSettings(
      enabled: true,
      triggerDays: [1],
      disabledTriggerDays: [7],
      emailTemplate: 'Hello {{customer_name}}');
  setUpAll(() async {
    for (final entry
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  Future<void> pump(WidgetTester tester,
      {bool dark = false, double scale = 1, bool failed = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          companyIdProvider.overrideWith((ref) => 'company-a'),
          reminderRepositoryProvider.overrideWith((ref) => repository),
          userProfileProvider.overrideWith((ref) => UserProfile(
              uid: 'member',
              role: 'owner',
              companyId: 'company-a',
              createdAt: DateTime(2026))),
          reminderSettingsStreamProvider.overrideWith((ref) => failed
              ? Stream.error(Exception('private backend detail'))
              : Stream.value(fixture)),
        ],
        child: MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const RepaintBoundary(
                key: Key('capture'), child: ReminderSettingsScreen()))));
    await tester.pumpAndSettle();
  }

  Future<void> scroll(WidgetTester tester, Finder target, double delta) =>
      tester.scrollUntilVisible(target, delta,
          scrollable: find.byType(Scrollable).first);
  test('preserves disabled web reminder rules and blank server-default message',
      () {
    final stored = fixture.toJson();
    final restored = ReminderSettings.fromJson(stored);
    expect(restored.triggerDays, [1]);
    expect(restored.disabledTriggerDays, [7]);
    expect(restored.toJson(), stored);
    expect(ReminderSettings.defaultSettings().emailTemplate, isEmpty);
  });
  for (final dark in [false, true]) {
    testWidgets('reminder settings ${dark ? 'dark' : 'light'} render and edit',
        (tester) async {
      await pump(tester, dark: dark);
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(const Key('capture')),
          matchesGoldenFile(
              'goldens/reminders_${dark ? 'dark' : 'light'}.png'));
      final rule = find.widgetWithText(SwitchListTile, '7 days overdue');
      expect(tester.widget<SwitchListTile>(rule).value, false);
      await tester.ensureVisible(rule);
      await tester.tap(rule);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(rule).value, true);
      await scroll(tester, find.text('Days overdue'), 250);
      await tester.enterText(find.byType(TextFormField).first, '366');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
          find.text('Enter a whole number between 1 and 365.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '14');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await scroll(tester, find.text('14 days overdue'), -200);
      expect(find.text('14 days overdue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'reminder form and placeholders fit 320px at 200% ${dark ? 'dark' : 'light'}',
        (tester) async {
      await pump(tester, dark: dark, scale: 2);
      await scroll(tester, find.text('Personalise your message'), 240);
      await tester.tap(find.text('Personalise your message'));
      await tester.pumpAndSettle();
      await scroll(tester, find.text('{{company_name}}'), 240);
      await scroll(tester, find.text('Preview sample email'), 240);
      expect(tester.takeException(), isNull);
      await scroll(tester, find.text('Save reminder settings'), 240);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('load failure has retry and cannot overwrite settings',
      (tester) async {
    await pump(tester, failed: true, scale: 2);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Save reminder settings'), findsNothing);
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'saving retains disabled rules and keeps edits after a network failure',
      (tester) async {
    await pump(tester);
    await scroll(tester, find.text('Reminder message'), 250);
    final message = find.widgetWithText(TextFormField, 'Reminder message');
    await tester.enterText(message, 'Updated message');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Save reminder settings'), 250);
    await tester.tap(find.text('Save reminder settings'));
    await tester.pumpAndSettle();
    expect(repository.captured?.triggerDays, [1]);
    expect(repository.captured?.disabledTriggerDays, [7]);
    expect(repository.captured?.emailTemplate, 'Updated message');
    expect(find.textContaining('Your changes are still here'), findsOneWidget);
    await scroll(tester, find.text('Reminder message'), -250);
    expect(find.text('Updated message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
