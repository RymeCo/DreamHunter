/// Master configuration for the Haunted Dorm game.
/// All costs, yields, and timers are defined here for easy balancing.
class GameConfig {
  // --- TIMERS ---
  static const double gracePeriod = 10.0;
  static const double tickRate = 0.5; // Every 0.5 seconds
  static const double doorAutoCloseDelay = 2.0;
  static const double interactionRange = 100.0; // Proximity for doors/beds

  // --- MONSTER SETTINGS ---
  static const double monsterUpgradeTime = 60.0; // Level up every 60s
  static const double hpScaleFactor = 2.0;
  static const double atkScaleFactor = 1.5;
  static const double playerTargetBias = 0.30; // 30% chance in initiation
  static const double initiationPeriod = 180.0; // First 3 minutes

  static const double baseMonsterHealth = 500.0;
  static const double baseMonsterAttack = 10.0;

  // --- ECONOMY: BED (COINS) ---
  // Lvl 1 is the starting bed. Levels 2-10 are upgrades.
  static const List<int> bedUpgradeCosts = [
    25,
    50,
    100,
    200,
    400,
    600,
    1200,
    2400,
    4800,
  ];
  static const List<int> bedIncomeLevels = [
    1,
    2,
    4,
    8,
    16,
    32,
    64,
    128,
    256,
    512,
  ];

  // --- ECONOMY: ENERGY GENERATOR ---
  static const int energyUnlockCost = 200;
  static const List<int> energyUpgradeCosts = [
    400,
    800,
    1600,
    3200,
    6400,
    12800,
    25600,
    51200,
    102400,
  ];
  static const List<int> energyYieldLevels = [1, 2, 4, 8, 16, 32, 64, 128, 256];

  // --- DEFENSE: DOORS & TURRETS ---
  // Doors have 3 Tiers (Wood, Iron, Steel) with 3 Levels each (9 total).
  static const List<int> doorUpgradeCosts = [
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
  ];
  static const List<double> doorHealthLevels = [
    100,
    200,
    400,
    800,
    1600,
    3200,
    6400,
    12800,
    25600,
  ];

  // Turrets have 9 Levels.
  static const List<int> turretUpgradeCosts = [
    10,
    20,
    40,
    80,
    160,
    320,
    640,
    1280,
    2560,
  ];
  static const List<double> turretDamageLevels = [
    5,
    10,
    20,
    40,
    80,
    160,
    320,
    640,
    1280,
  ];
}
