import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/user_profile.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/screens/profile/edit_profile_screen.dart';
import 'package:qotg_mobile/screens/settings/sign_in_methods_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Safe Initials Logic', () {
    String getInitials(String? displayName, String? email) {
      final name = (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : (email ?? '').trim();
      if (name.isEmpty) return '?';
      final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }

    test('handles standard two-word name', () {
      expect(getInitials('John Doe', null), 'JD');
    });

    test('handles multiple consecutive spaces without RangeError', () {
      expect(getInitials('John   Doe', null), 'JD');
      expect(getInitials('  John   Doe  ', null), 'JD');
    });

    test('handles single name', () {
      expect(getInitials('Madonna', null), 'M');
      expect(getInitials('  Prince  ', null), 'P');
    });

    test('handles empty and whitespace-only names by falling back to email', () {
      expect(getInitials('', 'john@example.com'), 'J');
      expect(getInitials('   ', 'alice@test.com'), 'A');
    });

    test('handles empty name and empty email', () {
      expect(getInitials('', ''), '?');
      expect(getInitials(null, null), '?');
    });
  });

  group('EditProfileScreen Widget Tests', () {
    testWidgets('renders edit profile screen with safe initials and 5MB label', (tester) async {
      final mockProfile = UserProfile(
        uid: 'test-user-123',
        displayName: 'John   Builder',
        username: 'johnbuilder',
        companyId: 'company-abc',
        role: 'owner',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => mockProfile),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('JB'), findsOneWidget);
      expect(find.text('Max file size 5MB. JPG or PNG.'), findsOneWidget);
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.text('DANGER ZONE'), findsOneWidget);
    });
  });

  group('SignInMethodsScreen Widget Tests', () {
    testWidgets('renders sign-in methods screen with scrollable dialogs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            authProvidersProvider.overrideWith((ref) => ['password']),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SignInMethodsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign-in Methods'), findsOneWidget);
      expect(find.text('Email & Password'), findsOneWidget);
      expect(find.text('Google Login'), findsOneWidget);

      // Open Change Password dialog
      final changePasswordBtn = find.text('Change Password');
      expect(changePasswordBtn, findsOneWidget);
      await tester.tap(changePasswordBtn);
      await tester.pumpAndSettle();

      // Verify dialog is open and contained inside a SingleChildScrollView
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Current Password'), findsNothing);
    });
  });
}
