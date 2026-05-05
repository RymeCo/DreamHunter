import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0E21),
      ),
      routerConfig: adminRouter,
    );
  }
}
