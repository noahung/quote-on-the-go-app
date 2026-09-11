import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qotg_mobile/providers/auth_provider.dart';
import 'package:qotg_mobile/providers/onboarding_provider.dart';
import 'package:qotg_mobile/services/onboarding_repository.dart';
import 'package:qotg_mobile/screens/auth/onboarding_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

void main() {
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

  test(
      'personal details reach the server and repeat submits cannot create duplicate requests',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    final requests = <Map<String, dynamic>>[];
    final notifier =
        OnboardingNotifier(OnboardingRepository(post: (path, body) {
      expect(path, '/api/mobile/onboarding');
      requests.add(body);
      return pending.future;
    }));
    addTearDown(notifier.dispose);
    notifier.init(displayName: 'Alexandra', email: 'alex@example.test');
    notifier.updatePersonalDetails(
        phone: '+44 7700 900123', jobTitle: 'Electrician');
    notifier.updateCompanyName('Orange & Oak');
    final first = notifier.submit('member');
    expect(await notifier.submit('member'), isFalse);
    expect(requests.single, containsPair('userPhone', '+44 7700 900123'));
    expect(requests.single, containsPair('jobTitle', 'Electrician'));
    pending.complete({'companyId': 'company'});
    expect(await first, isTrue);
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all onboarding steps remain usable dark=$dark scale=$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => null),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const RepaintBoundary(
                  key: Key('capture'), child: OnboardingScreen()),
            )));
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/images/app_icon.png'),
            tester.element(find.byType(OnboardingScreen))));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
            tester.element(find.byType(OnboardingScreen)));
        Finder field(String label) => find.widgetWithText(TextFormField, label);
        Future<void> fill(String label, String value) async {
          await tester.ensureVisible(field(label));
          await tester.enterText(field(label), value);
        }

        Future<void> next() async {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final button = find.widgetWithText(FilledButton, 'Continue');
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> capture(int step) async {
          if (scale == 1) {
            await expectLater(
                find.byKey(const Key('capture')),
                matchesGoldenFile(
                    'goldens/onboarding_step${step}_${dark ? 'dark' : 'light'}.png'));
          }
          expect(tester.takeException(), isNull, reason: 'Step $step');
        }

        await fill('Your Full Name *', 'Alexandra Montgomery-Williams');
        await fill('Phone Number (optional)', '+44 7700 900123');
        await fill('Job Title / Role (optional)',
            'Electrical installation specialist');
        await next();
        await capture(2);
        await fill('Company Name *', 'Orange & Oak Property Services');
        await fill('Company Contact Email *', 'office@example.test');
        await next();
        await capture(3);
        await fill('Hourly Rate (£)', '45.50');
        await fill('Bank Name', 'Example Bank');
        await fill('Account Name', 'Orange & Oak Property Services');
        await fill('Sort Code', '20-45-78');
        await fill('Account Number', '12345678');
        await next();
        await capture(4);
        final template = find.widgetWithText(ChoiceChip, 'Clean Teal');
        await tester.ensureVisible(template);
        await tester.tap(template);
        await tester.pumpAndSettle();
        expect(container.read(onboardingNotifierProvider).pdfTemplate,
            'clean-teal');
        final accent = find.byTooltip('Ocean Blue');
        await tester.ensureVisible(accent);
        await tester.tap(accent);
        await tester.pumpAndSettle();
        expect(container.read(onboardingNotifierProvider).pdfThemeColor,
            '#2563EB');
        await next();
        await capture(5);
        expect(find.text('Review your details'), findsOneWidget);
        expect(find.text("You're all set!"), findsNothing);
        expect(container.read(onboardingNotifierProvider).userPhone,
            '+44 7700 900123');
        expect(container.read(onboardingNotifierProvider).jobTitle,
            'Electrical installation specialist');
        final finish = find.widgetWithText(FilledButton, 'Complete setup');
        await tester.ensureVisible(finish);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
