import 'package:flutter/foundation.dart';

class PlaygroundService {
  static final PlaygroundService _instance = PlaygroundService._internal();
  factory PlaygroundService() => _instance;
  PlaygroundService._internal();

  int anteLevel = 1;
  int winCount = 0;
  String selectedCharacter = 'char1'; // Default

  void onWin() {
    winCount++;
    anteLevel = (winCount ~/ 3) + 1; // Increase difficulty every 3 wins
  }

  void resetProgress() {
    winCount = 0;
    anteLevel = 1;
  }
}
