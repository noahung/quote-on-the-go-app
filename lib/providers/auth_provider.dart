import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

part 'auth_provider.g.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Stream of auth state changes
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
}

// Current user provider - derives from auth stream so it reacts to sign-in/sign-out
@Riverpod(keepAlive: true)
User? currentUser(CurrentUserRef ref) {
  final asyncUser = ref.watch(authStateChangesProvider);
  final user = asyncUser.valueOrNull;
  debugPrint('[AUTH_PROVIDER] currentUser: ${user?.uid} (state: $asyncUser)');
  return user;
}

// User profile stream provider
@Riverpod(keepAlive: true)
Stream<UserProfile?> userProfileStream(UserProfileStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  final authService = ref.watch(authServiceProvider);
  return authService.streamUserProfile(user.uid);
}

// User profile provider
@Riverpod(keepAlive: true)
UserProfile? userProfile(UserProfileRef ref) {
  final asyncProfile = ref.watch(userProfileStreamProvider);
  final profile = asyncProfile.valueOrNull;
  debugPrint(
      '[AUTH_PROVIDER] userProfile: ${profile?.uid}, companyId: ${profile?.companyId} (state: ${asyncProfile.isLoading ? "loading" : asyncProfile.hasError ? "error: ${asyncProfile.error}" : "data"})');
  return profile;
}

// Company stream provider
@Riverpod(keepAlive: true)
Stream<Company?> companyStream(CompanyStreamRef ref) {
  final userProfile = ref.watch(userProfileProvider);
  if (userProfile == null) return Stream.value(null);

  final authService = ref.watch(authServiceProvider);
  return authService.streamCompany(userProfile.companyId);
}

// Company provider
@Riverpod(keepAlive: true)
Company? company(CompanyRef ref) {
  return ref.watch(companyStreamProvider).valueOrNull;
}

// Company ID provider
@Riverpod(keepAlive: true)
String? companyId(CompanyIdRef ref) {
  final id = ref.watch(userProfileProvider)?.companyId;
  debugPrint('[AUTH_PROVIDER] companyId: $id');
  return id;
}

// Is authenticated provider
@Riverpod(keepAlive: true)
bool isAuthenticated(IsAuthenticatedRef ref) {
  return ref.watch(currentUserProvider) != null;
}

// Is email verified provider
@Riverpod(keepAlive: true)
bool isEmailVerified(IsEmailVerifiedRef ref) {
  final user = ref.watch(currentUserProvider);
  final userProfile = ref.watch(userProfileProvider);

  // Check both Firebase Auth and our database
  return user?.emailVerified == true || userProfile?.emailVerified == true;
}

// User role provider
@Riverpod(keepAlive: true)
String? userRole(UserRoleRef ref) {
  return ref.watch(userProfileProvider)?.role;
}

// Auth loading state
final authLoadingProvider = StateProvider<bool>((ref) => false);

// Auth error state
final authErrorProvider = StateProvider<String?>((ref) => null);
