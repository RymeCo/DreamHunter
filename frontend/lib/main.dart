import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Set Device Preferences (Wait for them to apply)
  // Only run on mobile platforms to avoid "ViewInsets" assertion errors on Web
  if (!ThemeData().platform.toString().contains('web')) {
    await Flame.device.fullScreen();
    await Flame.device.setPortrait();
  }

  runApp(
    MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.quicksandTextTheme(),
      ),
      home: GameWidget(game: DreamHunterGame(characterType: 'lady')),
      debugShowCheckedModeBanner: false,
    ),
  );
}
