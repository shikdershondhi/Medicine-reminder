import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import 'auth_service.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/alarm_ring_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/prescriptions/prescription_list_screen.dart';
import '../../features/prescriptions/prescription_form_screen.dart';
import '../../features/prescriptions/prescription_detail_screen.dart';
import '../../features/medicines/medicine_form_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/dashboard/analytics_screen.dart';

final GoRouter goRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final user = AuthService().currentUser;
    final isLoggingIn = state.matchedLocation == '/';

    // If the user is not logged in, force them to stay on the login screen
    if (user == null) {
      return '/';
    }

    // If the user is logged in and trying to access the login page, redirect to Dashboard
    if (isLoggingIn) {
      return '/dashboard';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return const DashboardScreen();
      },
    ),
    GoRoute(
      path: '/alarm-ring',
      builder: (BuildContext context, GoRouterState state) {
        final settings = state.extra as AlarmSettings;
        return AlarmRingScreen(alarmSettings: settings);
      },
    ),
    GoRoute(
      path: '/profile-edit',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen(isOnboarding: false);
      },
    ),
    GoRoute(
      path: '/profile-onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen(isOnboarding: true);
      },
    ),
    GoRoute(
      path: '/prescriptions',
      builder: (BuildContext context, GoRouterState state) {
        return const PrescriptionListScreen();
      },
    ),
    GoRoute(
      path: '/prescriptions/add',
      builder: (BuildContext context, GoRouterState state) {
        return const PrescriptionFormScreen();
      },
    ),
    GoRoute(
      path: '/prescriptions/edit/:id',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'];
        return PrescriptionFormScreen(prescriptionId: id);
      },
    ),
    GoRoute(
      path: '/prescriptions/:id',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id']!;
        return PrescriptionDetailScreen(prescriptionId: id);
      },
    ),
    GoRoute(
      path: '/prescriptions/:pid/add-medicine',
      builder: (BuildContext context, GoRouterState state) {
        final pid = state.pathParameters['pid']!;
        return MedicineFormScreen(prescriptionId: pid);
      },
    ),
    GoRoute(
      path: '/prescriptions/:pid/edit-medicine/:mid',
      builder: (BuildContext context, GoRouterState state) {
        final pid = state.pathParameters['pid']!;
        final mid = state.pathParameters['mid']!;
        return MedicineFormScreen(prescriptionId: pid, medicineId: mid);
      },
    ),
    GoRoute(
      path: '/scan',
      builder: (BuildContext context, GoRouterState state) {
        return const ScanScreen();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsScreen();
      },
    ),
    GoRoute(
      path: '/analytics',
      builder: (BuildContext context, GoRouterState state) {
        return const AnalyticsScreen();
      },
    ),
  ],
);
