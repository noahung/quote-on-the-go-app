import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/components/preview_status_panel.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('preview retry remains reachable in a short view, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: PreviewStatusPanel(
                  message:
                      'Your session has expired. Sign in again to download this PDF.',
                  onRetry: () => retries++))));
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
