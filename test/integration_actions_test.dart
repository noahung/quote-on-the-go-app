import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/services/integration_service.dart';
import 'package:qotg_mobile/screens/settings/integrations_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

class RecordingIntegrationService extends IntegrationService {
  final actions = <String>[];
  @override
  Future<Map<String, dynamic>> syncQuickBooks({String action = 'full'}) async {
    actions.add('quickbooks.$action');
    return {'success': true, 'imported': 3};
  }

  @override
  Future<Map<String, dynamic>> syncMonday() async {
    actions.add('monday.sync');
    return {
      'success': true,
      'synced': 2,
      'failed': 1,
      'warning': 'One record needs review.'
    };
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('native integration actions and narrow layout, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = RecordingIntegrationService();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            integrationServiceProvider.overrideWithValue(service),
            userProfileProvider.overrideWith((ref) => UserProfile(
                uid: 'owner',
                companyId: 'company',
                role: 'owner',
                createdAt: DateTime(2026))),
            companyProvider.overrideWith((ref) => Company(
                id: 'company',
                ownerId: 'owner',
                name: 'Trade company',
                address: 'London',
                tier: 'organisation',
                subscriptionStatus: 'active',
                createdAt: DateTime(2026),
                quickbooksEnabled: true,
                mondayEnabled: true)),
          ],
          child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const IntegrationsScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final imports =
          find.widgetWithText(OutlinedButton, 'Import Customers').first;
      await tester.ensureVisible(imports);
      await tester.pumpAndSettle();
      await tester.tap(imports);
      await tester.pumpAndSettle();
      expect(service.actions, ['quickbooks.customers']);
      expect(find.text('QuickBooks import finished: 3 records processed.'),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sync Now'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sync Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();
      expect(service.actions, ['quickbooks.customers', 'monday.sync']);
      expect(tester.takeException(), isNull);
    });
  }
}
