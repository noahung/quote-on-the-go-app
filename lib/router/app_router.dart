import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
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
import '../screens/expenses/expenses_screen.dart';
import '../screens/expenses/log_expense_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/services/create_service_screen.dart';
import '../screens/services/service_detail_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/schedule/create_event_screen.dart';
import '../screens/schedule/monthly_schedule_screen.dart';
import '../screens/schedule/job_detail_screen.dart';
import '../screens/workflows/workflows_screen.dart';

/// Converts a Firebase auth stream into a [Listenable] for GoRouter's
/// refreshListenable, so the router re-evaluates redirects without being
/// destroyed and recreated.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

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
    redirect: (context, state) {
      // Use FirebaseAuth directly — the Riverpod provider chain may not
      // have processed the stream event yet when refreshListenable fires.
      final isAuthenticated = FirebaseAuth.instance.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // If not authenticated, redirect to login (unless already on login/register)
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
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
      ),

      // Main app shell with bottom navigation
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
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateQuotationScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return QuotationDetailScreen(quotationId: id);
                },
                routes: [
                  GoRoute(
                    path: 'portal',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return QuotationPortalScreen(quotationId: id);
                    },
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final quotation = state.extra as Quotation?;
                      return CreateQuotationScreen(
                          existingQuotation: quotation);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateInvoiceScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return InvoiceDetailScreen(invoiceId: id);
                },
                routes: [
                  GoRoute(
                    path: 'portal',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return InvoicePortalScreen(invoiceId: id);
                    },
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final invoice = state.extra as Invoice?;
                      return CreateInvoiceScreen(existingInvoice: invoice);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const AddEditCustomerScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerDetailScreen(customerId: id);
                },
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return AddEditCustomerScreen(customerId: id);
                },
              ),
            ],
          ),
        ],
      ),
      // Routes outside shell (no bottom nav)
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
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/schedule/new',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/schedule/monthly',
        builder: (context, state) => const MonthlyScheduleScreen(),
      ),
      GoRoute(
        path: '/schedule/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return JobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowsScreen(),
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
    ],
  );
});
