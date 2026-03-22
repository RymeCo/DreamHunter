import 'package:flutter/material.dart';

class GameConstants {
  static const List<String> predefinedAvatars = [
    'assets/images/dashboard/profile.png',
    'assets/images/dashboard/profile_logo.png',
    'assets/images/dashboard/small_circle_figure.png',
    'assets/images/dashboard/roulette_man.png',
  ];

  static String getAvatarPath(int id) {
    if (id < 0 || id >= predefinedAvatars.length) return predefinedAvatars[0];
    return predefinedAvatars[id];
  }

  static IconData getIconForTaskType(String? type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'spin':
        return Icons.casino_rounded;
      case 'playtime':
        return Icons.timer_rounded;
      case 'login':
        return Icons.login_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }
}
