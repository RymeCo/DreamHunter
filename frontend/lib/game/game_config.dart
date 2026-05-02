class UpgradeCost {
  final int coins;
  final int energy;

  const UpgradeCost({this.coins = 0, this.energy = 0});

  bool get isFree => coins == 0 && energy == 0;
}

class BedUpgrade {
  final int level;
  final int income;
  final UpgradeCost cost;
  final String? requirementLabel;
  final bool Function(dynamic context)? checkRequirement;

  const BedUpgrade({
    required this.level,
    required this.income,
    this.cost = const UpgradeCost(),
    this.requirementLabel,
    this.checkRequirement,
  });
}

class GeneratorUpgrade {
  final int level;
  final int income;
  final UpgradeCost cost;
  final String? requirementLabel;
  final bool Function(dynamic context)? checkRequirement;

  const GeneratorUpgrade({
    required this.level,
    required this.income,
    this.cost = const UpgradeCost(),
    this.requirementLabel,
    this.checkRequirement,
  });
}

class OreUpgrade {
  final int level;
  final int income;
  final UpgradeCost cost;
  final String material;
  final double globalMultiplier;

  const OreUpgrade({
    required this.level,
    required this.income,
    required this.material,
    this.cost = const UpgradeCost(),
    this.globalMultiplier = 1.0,
  });
}

class DoorUpgrade {
  final int level; // Total level 1-15
  final String material; // Wood, Iron, Gold
  final String suffix; // I, II, III, IV, V
  final double hp;
  final UpgradeCost cost;

  const DoorUpgrade({
    required this.level,
    required this.material,
    required this.suffix,
    required this.hp,
    this.cost = const UpgradeCost(),
  });

  String get name => "$material Door $suffix";
}

class GameConfig {
  static const double tickInterval = 1.0;
  static const int gracePeriodSeconds = 30;
  static const double graceSpeedMultiplier = 0.8; // 20% slow
  static const double repairCooldown = 30.0; // Seconds between repairs

  static const int turretBuildCost = 100;
  static const int fridgeBuildCost = 200;
  static const int oreBuildCost = 128; // Energy cost for Lv1

  // Bed Upgrades
  static final List<BedUpgrade> bedUpgrades = [
    const BedUpgrade(level: 1, income: 1),
    const BedUpgrade(level: 2, income: 2, cost: UpgradeCost(coins: 25)),
    BedUpgrade(
      level: 3,
      income: 4,
      cost: const UpgradeCost(coins: 50),
      requirementLabel: "Wood Door II",
      checkRequirement: (door) =>
          (door?.totalUpgrades ?? 0) >= 1, // 0-indexed: 0 is I, 1 is II
    ),
    const BedUpgrade(level: 4, income: 8, cost: UpgradeCost(coins: 100)),
    BedUpgrade(
      level: 5,
      income: 16,
      cost: const UpgradeCost(coins: 200),
      requirementLabel: "Wood Door V",
      checkRequirement: (door) => (door?.totalUpgrades ?? 0) >= 4,
    ),
    const BedUpgrade(level: 6, income: 32, cost: UpgradeCost(coins: 400)),
    BedUpgrade(
      level: 7,
      income: 64,
      cost: const UpgradeCost(coins: 800, energy: 16),
      requirementLabel: "Iron Door III",
      checkRequirement: (door) =>
          (door?.totalUpgrades ?? 0) >= 7, // Iron starts at 5. 5=I, 6=II, 7=III
    ),
    BedUpgrade(
      level: 8,
      income: 128,
      cost: const UpgradeCost(coins: 1600, energy: 32),
      requirementLabel: "Iron Door V",
      checkRequirement: (door) => (door?.totalUpgrades ?? 0) >= 9,
    ),
    BedUpgrade(
      level: 9,
      income: 256,
      cost: const UpgradeCost(coins: 3200, energy: 64),
      requirementLabel: "Gold Door I",
      checkRequirement: (door) =>
          (door?.totalUpgrades ?? 0) >= 10, // Gold starts at 10
    ),
    BedUpgrade(
      level: 10,
      income: 512,
      cost: const UpgradeCost(coins: 6400, energy: 128),
      requirementLabel: "Gold Door II",
      checkRequirement: (door) => (door?.totalUpgrades ?? 0) >= 11,
    ),
  ];

  // Generator Upgrades
  static final List<GeneratorUpgrade> generatorUpgrades = [
    const GeneratorUpgrade(level: 1, income: 1, cost: UpgradeCost(coins: 200)),
    const GeneratorUpgrade(level: 2, income: 2, cost: UpgradeCost(coins: 400)),
    GeneratorUpgrade(
      level: 3,
      income: 3,
      cost: const UpgradeCost(coins: 800),
      requirementLabel: "Turret III",
      checkRequirement: (turretLv) => (turretLv as int) >= 3,
    ),
    GeneratorUpgrade(
      level: 4,
      income: 4,
      cost: const UpgradeCost(coins: 1600),
      requirementLabel: "Turret IV",
      checkRequirement: (turretLv) => (turretLv as int) >= 4,
    ),
    GeneratorUpgrade(
      level: 5,
      income: 5,
      cost: const UpgradeCost(coins: 3200),
      requirementLabel: "Turret VI",
      checkRequirement: (turretLv) => (turretLv as int) >= 6,
    ),
    GeneratorUpgrade(
      level: 6,
      income: 6,
      cost: const UpgradeCost(coins: 6400),
      requirementLabel: "Turret VII",
      checkRequirement: (turretLv) => (turretLv as int) >= 7,
    ),
  ];

  // Ore Upgrades
  static final List<OreUpgrade> oreUpgrades = [
    const OreUpgrade(
      level: 1,
      material: "Copper",
      income: 8,
      cost: UpgradeCost(energy: 128),
    ),
    const OreUpgrade(
      level: 2,
      material: "Iron",
      income: 32,
      cost: UpgradeCost(energy: 1024),
    ),
    const OreUpgrade(
      level: 3,
      material: "Gold",
      income: 128,
      cost: UpgradeCost(energy: 2028),
    ),
    const OreUpgrade(
      level: 4,
      material: "Emerald",
      income: 512,
      cost: UpgradeCost(energy: 4096),
    ),
    const OreUpgrade(
      level: 5,
      material: "Special",
      income: 512,
      cost: UpgradeCost(energy: 8192),
      globalMultiplier: 1.5,
    ),
  ];

  // Door Upgrades
  static final List<DoorUpgrade> doorUpgrades = [
    const DoorUpgrade(level: 1, material: "Wood", suffix: "I", hp: 35),
    const DoorUpgrade(
      level: 2,
      material: "Wood",
      suffix: "II",
      hp: 70,
      cost: UpgradeCost(coins: 16),
    ),
    const DoorUpgrade(
      level: 3,
      material: "Wood",
      suffix: "III",
      hp: 140,
      cost: UpgradeCost(coins: 32),
    ),
    const DoorUpgrade(
      level: 4,
      material: "Wood",
      suffix: "IV",
      hp: 200,
      cost: UpgradeCost(coins: 64),
    ),
    const DoorUpgrade(
      level: 5,
      material: "Wood",
      suffix: "V",
      hp: 250,
      cost: UpgradeCost(coins: 128),
    ),
    const DoorUpgrade(
      level: 6,
      material: "Iron",
      suffix: "I",
      hp: 320,
      cost: UpgradeCost(coins: 256),
    ),
    const DoorUpgrade(
      level: 7,
      material: "Iron",
      suffix: "II",
      hp: 640,
      cost: UpgradeCost(coins: 512, energy: 16),
    ),
    const DoorUpgrade(
      level: 8,
      material: "Iron",
      suffix: "III",
      hp: 1280,
      cost: UpgradeCost(coins: 1024, energy: 32),
    ),
    const DoorUpgrade(
      level: 9,
      material: "Iron",
      suffix: "IV",
      hp: 2560,
      cost: UpgradeCost(coins: 2048, energy: 64),
    ),
    const DoorUpgrade(
      level: 10,
      material: "Iron",
      suffix: "V",
      hp: 5120,
      cost: UpgradeCost(coins: 4096, energy: 128),
    ),
    const DoorUpgrade(
      level: 11,
      material: "Gold",
      suffix: "I",
      hp: 10240,
      cost: UpgradeCost(coins: 8192, energy: 256),
    ),
    const DoorUpgrade(
      level: 12,
      material: "Gold",
      suffix: "II",
      hp: 20480,
      cost: UpgradeCost(coins: 16384, energy: 512),
    ),
    const DoorUpgrade(
      level: 13,
      material: "Gold",
      suffix: "III",
      hp: 40960,
      cost: UpgradeCost(coins: 32768, energy: 1024),
    ),
    const DoorUpgrade(
      level: 14,
      material: "Gold",
      suffix: "IV",
      hp: 81920,
      cost: UpgradeCost(coins: 65536, energy: 2048),
    ),
    const DoorUpgrade(
      level: 15,
      material: "Gold",
      suffix: "V",
      hp: 163840,
      cost: UpgradeCost(coins: 131072, energy: 4096),
    ),
  ];
}
