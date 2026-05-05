import 'package:flutter/foundation.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

enum TutorialStep {
  findBed,
  upgradeBed,
  upgradeDoor,
  buildTurret,
  completed,
}

class TutorialService extends ChangeNotifier {
  static final TutorialService instance = TutorialService._internal();
  factory TutorialService() => instance;
  TutorialService._internal();

  TutorialStep _currentStep = TutorialStep.findBed;
  bool _isInitialized = false;

  TutorialStep get currentStep => _currentStep;
  bool get isCompleted => _currentStep == TutorialStep.completed;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final data = await StorageEngine.instance.getMetadata('tutorial_status');
    if (data != null) {
      final completed = data['completed'] as bool? ?? false;
      if (completed) {
        _currentStep = TutorialStep.completed;
      } else {
        _currentStep = TutorialStep.findBed; // Rerun from start if not finished
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> moveToNextStep() async {
    if (isCompleted) return;

    final nextIndex = _currentStep.index + 1;
    if (nextIndex < TutorialStep.values.length) {
      _currentStep = TutorialStep.values[nextIndex];
      // Only persist if we reached the final "completed" state
      if (_currentStep == TutorialStep.completed) {
        await _persist();
      }
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await StorageEngine.instance.saveMetadata('tutorial_status', {
      'completed': true,
    });
  }

  void resetProgressIfNotCompleted() {
    if (!isCompleted) {
      _currentStep = TutorialStep.findBed;
      notifyListeners();
    }
  }

  String getQuestText(bool isSleeping) {
    if (!isSleeping && _currentStep != TutorialStep.findBed && _currentStep != TutorialStep.completed) {
      return 'Quest: Find a bed to sleep in.';
    }

    switch (_currentStep) {
      case TutorialStep.findBed:
        return 'Quest: Find a bed to sleep in.';
      case TutorialStep.upgradeBed:
        return 'Quest: Upgrade your bed to Lv. 2 (25 Coins).';
      case TutorialStep.upgradeDoor:
        return 'Quest: Upgrade your door to Lv. 2.';
      case TutorialStep.buildTurret:
        return 'Quest: Build a turret from the build menu.';
      case TutorialStep.completed:
        return '';
    }
  }
}
