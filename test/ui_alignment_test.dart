import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:qotg_mobile/components/analytics_metric.dart';
import 'package:qotg_mobile/components/custom_date_time_picker.dart';
import 'package:qotg_mobile/components/custom_email_send_bottom_sheet.dart';
import 'package:qotg_mobile/providers/custom_email_template_provider.dart';
import 'package:qotg_mobile/screens/auth/login_screen.dart';
import 'package:qotg_mobile/screens/auth/register_screen.dart';
import 'package:qotg_mobile/screens/auth/reset_password_screen.dart';
import 'package:qotg_mobile/screens/profile/profile_menu_screen.dart';
import 'package:qotg_mobile/screens/settings/settings_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';
import 'package:qotg_mobile/screens/auth/onboarding_screen.dart';
import 'package:qotg_mobile/screens/auth/account_pending_deletion_screen.dart';
import 'package:qotg_mobile/providers/auth_provider.dart';
import 'package:qotg_mobile/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final entries =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in entries) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {bool dark = false, double scale = 1, double width = 390}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          companyProvider.overrideWith((ref) => null),
          userProfileProvider.overrideWith((ref) => UserProfile(
              uid: 'test-user',
              role: 'owner',
              companyId: 'test-company',
              createdAt: DateTime(2026),
              deletionScheduledAt: '2026-09-30',
              deletionReason: 'Taking a break from contracting')),
          customEmailTemplatesProvider('invoice')
              .overrideWith((ref) async => [])
        ],
        child: MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(key: const Key('capture'), child: child))));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/app_icon.png'),
        tester.element(find.byKey(const Key('capture')))));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final screen in [
      'settings',
      'settings-preferences',
      'login',
      'register',
      'reset',
      'onboarding',
      'account-recovery'
    ]) {
      testWidgets('$screen ${dark ? 'dark' : 'light'} aligned render',
          (tester) async {
        final destinations = <String>[];
        final child = switch (screen) {
          'settings' => SettingsHubContent(
              name: 'Dante Karatos',
              email: 'dante@example.test',
              companyName: 'Karatos Services',
              tier: 'organisation',
              isOwner: true,
              canManageTeam: true,
              onOpen: destinations.add,
              onSignOut: () {}),
          'settings-preferences' => const SettingsScreen(),
          'login' => const LoginScreen(),
          'register' => const RegisterScreen(),
          'onboarding' => const OnboardingScreen(),
          'account-recovery' => const AccountPendingDeletionScreen(),
          _ => const ResetPasswordScreen(),
        };
        await pump(tester, child, dark: dark);
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byKey(const Key('capture')),
            matchesGoldenFile(
                'goldens/${screen}_${dark ? 'dark' : 'light'}.png'));
        if (screen == 'settings') {
          await tester.tap(find.text('Account & app settings'));
          expect(destinations, ['/settings/preferences']);
        }
      });
    }
  }
  for (final screen in [
    const SettingsScreen(),
    const OnboardingScreen(),
    const AccountPendingDeletionScreen()
  ]) {
    testWidgets('${screen.runtimeType} supports large text', (tester) async {
      await pump(tester, screen, width: 320, scale: 2);
      expect(tester.takeException(), isNull);
      if (screen is SettingsScreen) {
        await tester.scrollUntilVisible(find.text('Colour theme'), 350,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Colour theme'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Use device setting'));
        await tester.pumpAndSettle();
        expect(find.text('Use device setting'), findsOneWidget);
        expect((await SharedPreferences.getInstance()).getString('theme_mode'),
            'system');
      }
    });
  }
  testWidgets('settings long identity and rows wrap at 320px and 200% text',
      (tester) async {
    final destinations = <String>[];
    await pump(
        tester,
        SettingsHubContent(
            name: '  Alexandra   Montgomery-Williams ',
            email: 'alexandra.long.name@example.test',
            companyName: 'Montgomery Property Maintenance',
            tier: 'organisation',
            isOwner: true,
            canManageTeam: true,
            onOpen: destinations.add,
            onSignOut: () {}),
        width: 320,
        scale: 2);
    await tester.scrollUntilVisible(find.text('Account & app settings'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account & app settings'));
    expect(destinations, ['/settings/preferences']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'signup rejects malformed email and mismatching passwords without a request',
      (tester) async {
    await pump(tester, const RegisterScreen(), width: 320, scale: 2);
    await tester.enterText(find.byType(TextFormField).at(0), 'Dante');
    await tester.enterText(find.byType(TextFormField).at(1), 'broken@');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'password with spaces ');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'password with spaces');
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Passwords need to match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('calendar last week is selectable and time is preserved exactly',
      (tester) async {
    DateTime? result;
    await pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    child: const Text('Schedule'),
                    onPressed: () async {
                      result = await showModalBottomSheet<DateTime>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CustomDateTimePickerSheet(
                              initialDateTime: DateTime(2026, 9, 9, 23, 53),
                              title: 'Schedule delivery'));
                    }))),
        width: 320,
        scale: 2);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    final day = find.bySemanticsLabel(
        DateFormat.yMMMMEEEEd().format(DateTime(2026, 9, 30)));
    await tester.ensureVisible(day);
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 30, 23, 53));
    expect(tester.takeException(), isNull);
  });
  testWidgets('analytics explanation expands without a fixed card height',
      (tester) async {
    await pump(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: AnalyticsMetric(
                        title: 'Estimated margin',
                        value: '30.0%',
                        subtitle: 'Assumes costs are 70% of revenue')))),
        width: 320,
        scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Assumes costs are 70% of revenue'), findsOneWidget);
  });

  testWidgets('email schedule returns for review before committing delivery',
      (tester) async {
    final scheduled = <DateTime>[];
    await pump(
        tester,
        ProviderScope(
            overrides: [
              customEmailTemplatesProvider('invoice')
                  .overrideWith((ref) async => []),
            ],
            child: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        child: const Text('Compose'),
                        onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CustomEmailSendBottomSheet(
                                  documentId: 'test-document',
                                  docType: 'invoice',
                                  docNumber: 'INV-1788954593322',
                                  customerName: 'Alexandra Montgomery',
                                  customerEmail:
                                      'alexandra.long.name@example.test',
                                  totalAmount: '£3,000.00',
                                  companyId: 'demo',
                                  companyName: 'Karatos Services',
                                  dueDateOrExpiry: '23 Sep 2026',
                                  portalLink:
                                      'https://example.test/portal/invoices/demo',
                                  isPremiumUser: true,
                                  onSendNow: (_) =>
                                      fail('Must not send immediately'),
                                  onScheduleSend: (date, _) =>
                                      scheduled.add(date)),
                            ))))),
        width: 320,
        scale: 2);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Schedule for Later'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(scheduled, isEmpty);
    await tester.tap(find.text('Confirm Schedule'));
    await tester.pumpAndSettle();
    expect(scheduled, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
