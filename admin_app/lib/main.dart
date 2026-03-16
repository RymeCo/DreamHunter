import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AdminControlCenter());
}

class AdminControlCenter extends StatelessWidget {
  const AdminControlCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamHunter Superadmin',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
        textTheme: GoogleFonts.quicksandTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainLayout(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text('Dashboard (System Health & Emergency)')),
    const Center(child: Text('Player Management')),
    const Center(child: Text('Report Center')),
    const Center(child: Text('Auto-Moderation Console')),
    const Center(child: Text('Audit Logs')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFF16162F),
            selectedIconTheme: const IconThemeData(color: Colors.amberAccent),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Players'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_problem_outlined),
                selectedIcon: Icon(Icons.report_problem),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security),
                label: Text('Auto-Mod'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Audit'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
