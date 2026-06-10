import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../screens/shell_scaffold.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/profile/profile_menu_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/team/team_management_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/quotations/quotations_screen.dart';
import '../screens/quotations/quotation_detail_screen.dart';
import '../screens/quotations/quotation_portal_screen.dart';
import '../screens/invoices/invoices_screen.dart';
import '../screens/invoices/invoice_detail_screen.dart';
import '../screens/invoices/invoice_portal_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/customers/add_edit_customer_screen.dart';
import '../screens/quotations/create_quotation_screen.dart';
import '../screens/invoices/create_invoice_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/company_branding_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/expenses/expense_detail_screen.dart';
import '../screens/expenses/log_expense_screen.dart';
import '../screens/settings/referral_screen.dart';
import '../screens/settings/billing_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/services/create_service_screen.dart';
import '../screens/services/service_detail_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/schedule/create_job_screen.dart';
import '../screens/schedule/job_detail_screen.dart';
import '../screens/workflows/workflows_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/collaboration/collaboration_screen.dart';
import '../screens/pricing/smart_pricing_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/shared/in_app_web_view_screen.dart';

/// Converts a Firebase auth stream into a [Listenable] for GoRouter's
/// refreshListenable, so the router re-evaluates redirects without being
/// destroyed and recreated.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Router configuration provider
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.read(authServiceProvider);
  final refreshListenable = GoRouterRefreshStream(authService.authStateChanges);

  ref.onDispose(() => refreshListenable.dispose());

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      // Use FirebaseAuth directly — the Riverpod provider chain may not
      // have processed the stream event yet when refreshListenable fires.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final isAuthenticated = firebaseUser != null;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login' || location == '/register';
      final isOnboarding = location == '/onboarding';
      final isVerifyingEmail = location == '/verify-email';

      // If not authenticated, redirect to login (unless already on login/register)
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // If authenticated, check email verification and profile existence.
      if (isAuthenticated && !isLoggingIn) {
        final isEmailVerified = firebaseUser.emailVerified;
        final userProfile = await authService.getUserProfile(firebaseUser.uid);
        final hasProfile = userProfile != null;

        // Unverified email-based users must verify before proceeding
        if (!isEmailVerified && !hasProfile && !isVerifyingEmail) {
          return '/verify-email';
        }

        // Once verified, send to onboarding if no profile yet
        if ((isEmailVerified || hasProfile) && !hasProfile && !isOnboarding) {
          return '/onboarding';
        }
        if (hasProfile && (isOnboarding || isVerifyingEmail)) {
          return '/';
        }

        // Consume any pending deep-link from a terminated-app notification tap.
        final pending = NotificationService().consumePendingRoute();
        if (pending != null && pending.isNotEmpty && pending != location) {
          return pending;
        }
      }

      // If authenticated but on auth pages, redirect to home
      if (isAuthenticated && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/quotations',
            builder: (context, state) => const QuotationsScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/workflows',
            builder: (context, state) => const WorkflowsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/pricing',
            builder: (context, state) => const SmartPricingScreen(),
          ),
        ],
      ),

      // Routes outside shell (no bottom nav)
      GoRoute(
        path: '/web-preview',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final url = extra?['url'] as String? ?? state.uri.queryParameters['url'] ?? '';
          final title = extra?['title'] as String? ?? state.uri.queryParameters['title'] ?? 'Preview';
          return InAppWebViewScreen(url: url, title: title);
        },
      ),
      GoRoute(
        path: '/quotations/new',
        builder: (context, state) => const CreateQuotationScreen(),
      ),
      GoRoute(
        path: '/quotations/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuotationDetailScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/quotations/:id/portal',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuotationPortalScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/quotations/:id/edit',
        builder: (context, state) {
          final quotation = state.extra as Quotation?;
          return CreateQuotationScreen(existingQuotation: quotation);
        },
      ),

      GoRoute(
        path: '/invoices/new',
        builder: (context, state) => const CreateInvoiceScreen(),
      ),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoiceDetailScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/invoices/:id/portal',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoicePortalScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/invoices/:id/edit',
        builder: (context, state) {
          final invoice = state.extra as Invoice?;
          return CreateInvoiceScreen(existingInvoice: invoice);
        },
      ),

      GoRoute(
        path: '/customers/new',
        builder: (context, state) => const AddEditCustomerScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditCustomerScreen(customerId: id);
        },
      ),

      GoRoute(
        path: '/schedule/new',
        builder: (context, state) => const CreateJobScreen(),
      ),
      GoRoute(
        path: '/schedule/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return JobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '/schedule/:id/edit',
        builder: (context, state) {
          final event = state.extra as CalendarEvent?;
          return CreateJobScreen(event: event);
        },
      ),

      GoRoute(
        path: '/collaboration/:type/:id',
        builder: (context, state) {
          final type = state.pathParameters['type']!;
          final id = state.pathParameters['id']!;
          return CollaborationScreen(documentType: type, documentId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/expenses/new',
        builder: (context, state) => const LogExpenseScreen(),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpenseDetailScreen(expenseId: id);
        },
      ),
      GoRoute(
        path: '/referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/services/new',
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/services/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ServiceDetailScreen(serviceId: id);
        },
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileMenuScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/team',
        builder: (context, state) => const TeamManagementScreen(),
      ),
      GoRoute(
        path: '/company-branding',
        builder: (context, state) => const CompanyBrandingScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
    ],
  );
});
