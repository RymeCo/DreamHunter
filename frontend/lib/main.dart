import 'package:dreamhunter/screens/splash_screen.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/core/layout_baseline.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/progression/task_service.dart';
import 'package:dreamhunter/services/progression/tutorial_service.dart';
import 'package:dreamhunter/widgets/pillarbox_wrapper.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase (Local session restoration)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Core Services (Non-blocking as much as possible)
  await StorageEngine().initialize();
  await LayoutBaseline().initialize();
  await HapticManager().initialize();
  await AudioManager().initialize();
  await TaskService().initialize();
  await TutorialService().initialize();

  if (!ThemeData().platform.toString().contains('web')) {
    await Flame.device.fullScreen();
    await Flame.device.setPortrait();
  }

  runApp(const PillarboxWrapper(child: DHApp()));
}

class DHApp extends StatelessWidget {
  const DHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamHunter',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
