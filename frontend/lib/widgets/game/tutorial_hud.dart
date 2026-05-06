import 'package:flutter/material.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/services/progression/tutorial_service.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/turret_entity.dart';

class TutorialHUD extends StatefulWidget {
  final DreamHunterGame game;

  const TutorialHUD({super.key, required this.game});

  @override
  State<TutorialHUD> createState() => _TutorialHUDState();
}

class _TutorialHUDState extends State<TutorialHUD> {
  final _tutorial = TutorialService.instance;
  final _manager = MatchManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onGameStateChanged);
    _tutorial.addListener(_onTutorialChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onGameStateChanged);
    _tutorial.removeListener(_onTutorialChanged);
    super.dispose();
  }

  void _onTutorialChanged() {
    if (mounted) setState(() {});
  }

  void _onGameStateChanged() {
    if (!mounted || _tutorial.isCompleted) return;
    _checkProgress();
    // Rebuild to update quest text if sleeping state changes
    setState(() {});
  }

  void _checkProgress() {
    // Only check if game is loaded and world is ready
    if (!widget.game.isLoaded) return;

    switch (_tutorial.currentStep) {
      case TutorialStep.findBed:
        if (_manager.isHunterSleeping) {
          _tutorial.moveToNextStep();
        }
        break;
      case TutorialStep.upgradeBed:
        final roomID = _manager.currentRoomID;
        if (roomID.isNotEmpty) {
          final bed = widget.game.roomBeds[roomID];
          if (bed != null && bed.level >= 2) {
            _tutorial.moveToNextStep();
          }
        }
        break;
      case TutorialStep.upgradeDoor:
        final roomID = _manager.currentRoomID;
        if (roomID.isNotEmpty) {
          // Find the door for this room
          final door = widget.game.doorMap.values
              .where((d) => d.roomID == roomID)
              .firstOrNull;
          if (door != null && door.totalUpgrades >= 1) {
            _tutorial.moveToNextStep();
          }
        }
        break;
      case TutorialStep.buildTurret:
        final roomID = _manager.currentRoomID;
        if (roomID.isNotEmpty) {
          final hasTurret = widget.game.turrets.any((t) {
            if (t is TurretEntity) {
              return t.roomID == roomID;
            }
            return false;
          });
          if (hasTurret) {
            _tutorial.moveToNextStep();
          }
        }
        break;
      case TutorialStep.completed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tutorial.isCompleted) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          _tutorial.getQuestText(_manager.isHunterSleeping),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
