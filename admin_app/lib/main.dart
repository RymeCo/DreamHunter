import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'providers/admin_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/players_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/automod_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/live_chat_screen.dart';
import 'widgets/admin_ui_components.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AdminProvider())],
      child: const AdminControlCenter(),
    ),
  );
}

class AdminControlCenter extends StatelessWidget {
  const AdminControlCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamHunter Control',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
        textTheme: GoogleFonts.quicksandTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16162F),
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
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
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AdminCard(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin Access',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.amberAccent,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'DreamHunter Command Center',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 32),
              AdminTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              AdminTextField(
                controller: _passwordController,
                label: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: AdminButton(
                  onPressed: _isLoading ? null : _login,
                  label: 'AUTHORIZE',
                  isLoading: _isLoading,
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF16162F),
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'DreamHunter Control',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -1,
              color: Colors.amberAccent,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white70, size: 20),
                onPressed: () => FirebaseAuth.instance.signOut(),
                tooltip: 'Logout Session',
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: const TabBar(
                isScrollable: true,
                indicatorColor: Colors.amberAccent,
                indicatorWeight: 3,
                labelColor: Colors.amberAccent,
                unselectedLabelColor: Colors.white38,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 16),
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Dashboard'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Players'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Reports'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.forum_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Live Chat'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.security_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Auto-Mod'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 60,
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Audit'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1E),
          ),
          child: const TabBarView(
            children: [
              DashboardScreen(),
              PlayersScreen(),
              ReportsScreen(),
              LiveChatScreen(),
              AutoModScreen(),
              AuditScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
