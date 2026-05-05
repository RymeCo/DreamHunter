import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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
      title: 'DreamHunter Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1B1F),
        ),
        scaffoldBackgroundColor: const Color(0xFF1C1B1F),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1C1B1F),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1C1B1F),
          indicatorColor: const Color(0xFF4F378B).withValues(alpha: 0.5),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF6750A4).withValues(alpha: 0.2),
            ),
          ),
          color: const Color(0xFF252429),
        ),
      ),
      routerConfig: adminRouter,
    );
  }
}
