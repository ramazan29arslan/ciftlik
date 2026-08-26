import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/email_otp_page.dart';
import '../../features/auth/presentation/pages/settings_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/animals/presentation/pages/animals_list_page.dart';
import '../../features/animals/presentation/pages/animal_detail_page.dart';
import '../../features/animals/presentation/pages/animal_form_page.dart';
import '../../features/vehicles/presentation/pages/vehicles_list_page.dart';
import '../../features/vehicles/presentation/pages/vehicle_detail_page.dart';
import '../../features/vehicles/presentation/pages/vehicle_form_page.dart';
import '../../features/buildings/presentation/pages/buildings_list_page.dart';
import '../../features/buildings/presentation/pages/building_detail_page.dart';
import '../../features/buildings/presentation/pages/building_form_page.dart';
import '../../features/stock/presentation/pages/stock_list_page.dart';
import '../../features/stock/presentation/pages/stock_detail_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/app_announcements_page.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/farms/presentation/pages/farm_setup_page.dart';
import '../../features/farms/presentation/pages/farm_members_page.dart';
import '../../features/farms/presentation/pages/super_admin_page.dart';
import '../../features/transfers/presentation/pages/sale_transfers_page.dart';
import '../../features/fields/presentation/pages/fields_list_page.dart';
import '../../features/fields/presentation/pages/field_detail_page.dart';
import '../../features/fields/presentation/pages/field_form_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;

      if (loc == AppRoutes.splash) {
        return user == null ? AppRoutes.login : AppRoutes.dashboard;
      }

      if (user == null) {
        const allowedUnauth = [AppRoutes.login, AppRoutes.registerOtp];
        return allowedUnauth.contains(loc) ? null : AppRoutes.login;
      }

      if (loc == AppRoutes.login ||
          loc == AppRoutes.verifyEmail ||
          loc == AppRoutes.registerOtp) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: AppRoutes.registerOtp,
        builder: (context, state) => const EmailOtpPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.farmSetup,
        builder: (context, state) => const FarmSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.farmMembers,
        builder: (context, state) => const FarmMembersPage(),
      ),
      GoRoute(
        path: AppRoutes.superAdmin,
        builder: (context, state) => const SuperAdminPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        builder: (context, state) => const AppAnnouncementsPage(),
      ),
      GoRoute(
        path: AppRoutes.saleTransfers,
        builder: (context, state) => const SaleTransfersPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.animals,
            builder: (context, state) => const AnimalsListPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => AnimalDetailPage(
                  animalId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => AnimalFormPage(
                  presetMotherId: state.uri.queryParameters['motherId'],
                  presetFatherId: state.uri.queryParameters['fatherId'],
                  presetNotes: state.uri.queryParameters['notes'],
                ),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => AnimalFormPage(
                  animalId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.vehicles,
            builder: (context, state) => const VehiclesListPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => VehicleDetailPage(
                  vehicleId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const VehicleFormPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => VehicleFormPage(
                  vehicleId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.buildings,
            builder: (context, state) => const BuildingsListPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => BuildingDetailPage(
                  buildingId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const BuildingFormPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => BuildingFormPage(
                  buildingId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.stock,
            builder: (context, state) => const StockListPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => StockDetailPage(
                  stockId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.fields,
            builder: (context, state) => const FieldsListPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => FieldDetailPage(
                  fieldId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const FieldFormPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => FieldFormPage(
                  fieldId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: AppRoutes.documents,
            builder: (context, state) => const DocumentsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Sayfa bulunamadı: ${state.error}'),
      ),
    ),
  );

  return router;
});


class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String verifyEmail = '/verify-email';
  static const String registerOtp = '/register-otp';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String dashboard = '/dashboard';
  static const String animals = '/animals';
  static const String vehicles = '/vehicles';
  static const String buildings = '/buildings';
  static const String stock = '/stock';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String announcements = '/announcements';
  static const String documents = '/documents';
  static const String fields = '/fields';
  static const String farmSetup = '/farm-setup';
  static const String farmMembers = '/farm-members';
  static const String superAdmin = '/super-admin';
  static const String saleTransfers = '/sale-transfers';
}
