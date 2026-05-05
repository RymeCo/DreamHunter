import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'api_gateway.dart';

final adminRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login';

    if (user == null) {
      return isLoggingIn ? null : '/login';
    }

    // Use Backend API (HTTP) instead of Firestore SDK to avoid gRPC/GMS issues in Waydroid.
    try {
      final api = ApiGateway();
      final response = await api.post('/auth/sync');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['role'] == 'admin') {
          return isLoggingIn ? '/dashboard' : null;
        }
      }
      
      await FirebaseAuth.instance.signOut();
      return '/login';
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return '/login';
    }
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
