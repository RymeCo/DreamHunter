import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Explicitly providing options to avoid "DefaultFirebaseOptions not found" errors
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBUCYw-9PRPpx8qL2dC5-Yxm4FDXY694og',
      appId: '1:167750425566:android:983a4f86bb000e7cdedb4f',
      messagingSenderId: '167750425566',
      projectId: 'dream-hunter-c0f89',
      storageBucket: 'dream-hunter-c0f89.firebasestorage.app',
    ),
  );
  
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DD-Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: adminRouter,
    );
  }
}

final adminRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login';

    if (user == null) {
      return isLoggingIn ? null : '/login';
    }

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
      // If Firestore fails (e.g. no internet), stay on login or current page
      return null;
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings, size: 64, color: Colors.deepPurple),
            SizedBox(height: 16),
            Text('Welcome to the Admin Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final doc = await FirebaseFirestore.instance
          .collection('players')
          .doc(cred.user!.uid)
          .get();

      if (doc.data()?['role'] == 'admin') {
        if (mounted) context.go('/dashboard');
      } else {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access Denied: Not an Admin')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('DD-Admin', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 24),
              _loading 
                ? const CircularProgressIndicator() 
                : ElevatedButton(onPressed: _login, child: const Text('Login')),
            ],
          ),
        ),
      ),
    );
  }
}
