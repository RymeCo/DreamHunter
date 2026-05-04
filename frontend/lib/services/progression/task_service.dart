import 'package:flutter/foundation.dart';
import 'package:dreamhunter/models/task_model.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

/// Singleton service that manages daily tasks, persistence, and resets.
class TaskService extends ChangeNotifier {
  static final TaskService instance = TaskService._internal();
  factory TaskService() => instance;
  TaskService._internal();

  static const String _tasksKey = 'daily_tasks_v1';
  static const String _lastResetKey = 'tasks_last_reset_date';

  List<DailyTask> _tasks = [];
  List<DailyTask> get tasks => List.unmodifiable(_tasks);

  bool _isInitialized = false;

  /// Initializes the task list and handles daily resets.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    
    final metadata = await StorageEngine.instance.getMetadata(_lastResetKey);
    final lastResetDate = metadata?['date'] as String?;

    if (lastResetDate != today) {
      await _resetTasks(today);
    } else {
      await _loadTasks();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Increments progress for a specific task type.
  Future<void> trackAction(TaskType type, {int amount = 1}) async {
    if (!_isInitialized) await initialize();

    bool changed = false;
    for (final task in _tasks) {
      if (task.type == type && !task.claimed) {
        task.progress = (task.progress + amount).clamp(0, task.target);
        changed = true;
      }
    }

    if (changed) {
      await _saveTasks();
      notifyListeners();
    }
  }

  /// Claims the reward for a specific task.
  Future<void> claimTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.canClaim) {
      task.claimed = true;
      await _saveTasks();
      notifyListeners();
    }
  }

  Future<void> _resetTasks(String today) async {
    // Define the default daily tasks
    _tasks = [
      DailyTask(
        id: 'daily_login',
        title: 'Daily Login',
        description: 'Welcome back! Log in to the game.',
        target: 1,
        progress: 1, // Auto-complete login task on reset/init
        reward: 50,
        type: TaskType.login,
      ),
      DailyTask(
        id: 'send_messages',
        title: 'Chatterbox',
        description: 'Send 5 messages in global chat.',
        target: 5,
        progress: 0,
        reward: 100,
        type: TaskType.chat,
      ),
      DailyTask(
        id: 'spin_roulette',
        title: 'Lucky Spinner',
        description: 'Spin the Lucky Roulette twice.',
        target: 2,
        progress: 0,
        reward: 150,
        type: TaskType.spin,
      ),
      DailyTask(
        id: 'playtime_task',
        title: 'Time Traveler',
        description: 'Spend 10 minutes in matches.',
        target: 10,
        progress: 0,
        reward: 200,
        type: TaskType.playtime,
      ),
    ];

    await _saveTasks();
    await StorageEngine.instance.saveMetadata(_lastResetKey, {'date': today});
  }

  Future<void> _loadTasks() async {
    final data = await StorageEngine.instance.getMetadata(_tasksKey);
    if (data != null && data['tasks'] != null) {
      final List<dynamic> list = data['tasks'];
      _tasks = list.map((m) => DailyTask.fromMap(m)).toList();
    } else {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _resetTasks(today);
    }
  }

  Future<void> _saveTasks() async {
    final data = {
      'tasks': _tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'target': t.target,
        'progress': t.progress,
        'reward': t.reward,
        'claimed': t.claimed,
        'type': t.type.name,
      }).toList(),
    };
    await StorageEngine.instance.saveMetadata(_tasksKey, data);
  }

  /// Reloads state from cache (e.g. after logout/login).
  Future<void> reloadFromCache() async {
    _isInitialized = false;
    await initialize();
  }
}
