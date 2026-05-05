import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

final adminRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login';

    if (user == null) {
      return isLoggingIn ? null : '/login';
    }

    // Persistence Check: Verify admin status from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (doc.data()?['role'] == 'admin') {
        return isLoggingIn ? '/dashboard' : null;
      } else {
        await FirebaseAuth.instance.signOut();
        return '/login';
      }
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
