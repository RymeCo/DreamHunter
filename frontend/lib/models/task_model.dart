enum TaskType { login, chat, spin, playtime, generic }

class DailyTask {
  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final TaskType type;

  int progress;
  bool claimed;

  DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
    this.type = TaskType.generic,
    this.progress = 0,
    this.claimed = false,
  });

  bool get isCompleted => progress >= target;
  bool get canClaim => isCompleted && !claimed;
  double get percent => (progress / target).clamp(0.0, 1.0);

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      target: map['target'] ?? 1,
      reward: map['reward'] ?? 0,
      progress: map['progress'] ?? 0,
      claimed: map['claimed'] ?? false,
      type: _parseType(map['type']),
    );
  }

  static TaskType _parseType(String? type) {
    switch (type) {
      case 'chat':
        return TaskType.chat;
      case 'spin':
        return TaskType.spin;
      case 'playtime':
        return TaskType.playtime;
      case 'login':
        return TaskType.login;
      default:
        return TaskType.generic;
    }
  }
}
