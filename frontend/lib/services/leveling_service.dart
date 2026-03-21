import 'dart:math';

/// A service that handles XP to Level calculations and progress.
/// Matches the backend formula: XP_next = 100 * Level^1.5
class LevelingService {
  /// Calculates the level for a given amount of XP.
  static int getLevel(int xp) {
    if (xp <= 0) return 1;
    // Inverse formula: Level = (XP / 100)^(1/1.5) + 1
    int level = (pow(xp / 100, 1 / 1.5)).floor() + 1;
    return max(1, level);
  }

  /// Calculates the XP required for a specific level.
  static int getXPForLevel(int level) {
    if (level <= 1) return 0;
    // XP_next = 100 * (Level-1)^1.5
    return (100 * pow(level - 1, 1.5)).floor();
  }

  /// Calculates the XP required for the NEXT level.
  static int getNextLevelXP(int level) {
    return (100 * pow(level, 1.5)).floor();
  }

  /// Calculates the progress percentage within the current level (0.0 to 1.0).
  static double getLevelProgress(int xp) {
    int currentLevel = getLevel(xp);
    int currentLevelXP = getXPForLevel(currentLevel);
    int nextLevelXP = getNextLevelXP(currentLevel);

    int xpInCurrentLevel = xp - currentLevelXP;
    int totalXPForCurrentLevel = nextLevelXP - currentLevelXP;

    if (totalXPForCurrentLevel <= 0) return 0.0;
    return (xpInCurrentLevel / totalXPForCurrentLevel).clamp(0.0, 1.0);
  }

  /// Returns the amount of XP earned for a specific action.
  static int getXPReward(
    String transactionType, {
    int dreamDelta = 0,
    int hellDelta = 0,
  }) {
    switch (transactionType) {
      case 'PURCHASE':
        return (dreamDelta.abs() / 10).floor();
      case 'CONVERSION':
        return (hellDelta.abs() * 50);
      case 'ROULETTE_SPIN':
        return 25;
      case 'EARN':
        return max(1, (dreamDelta / 100).floor());
      case 'IAP_PURCHASE':
        return 500;
      case 'DAILY_LOGIN':
        return 50;
      default:
        return 0;
    }
  }
}
