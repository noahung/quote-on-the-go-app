import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('system theme survives a fresh provider instance', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    first.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    await first.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
    first.dispose();
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restored.read(themeModeProvider), ThemeMode.system);
  });
}
