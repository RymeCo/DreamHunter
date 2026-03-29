import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

class DailyTasksDialog extends StatefulWidget {
  const DailyTasksDialog({super.key});

  @override
  State<DailyTasksDialog> createState() => _DailyTasksDialogState();
}

class _DailyTasksDialogState extends State<DailyTasksDialog> {
  final List<Map<String, dynamic>> _tasks = [
    {
      "id": "daily_login",
      "title": "Daily Login",
      "description": "Log in to the game today.",
      "progress": 1,
      "target": 1,
      "reward": 50,
      "completed": true,
      "claimed": false,
      "type": "login",
    },
    {
      "id": "send_messages",
      "title": "Chatterbox",
      "description": "Send 5 messages in global chat.",
      "progress": 2,
      "target": 5,
      "reward": 100,
      "completed": false,
      "claimed": false,
      "type": "chat",
    },
    {
      "id": "spin_roulette",
      "title": "Lucky Spinner",
      "description": "Spin the Lucky Roulette twice.",
      "progress": 0,
      "target": 2,
      "reward": 150,
      "completed": false,
      "claimed": false,
      "type": "spin",
    },
    {
      "id": "playtime_task",
      "title": "Time Traveler",
      "description": "Play for 10 minutes.",
      "progress": 4,
      "target": 10,
      "reward": 200,
      "completed": false,
      "claimed": false,
      "type": "playtime",
    },
  ];

  void _claimTask(int index) {
    setState(() {
      _tasks[index]['claimed'] = true;
    });
    // UI feedback only, no backend call
    showCustomSnackBar(
      context,
      'Reward claimed: ${_tasks[index]['reward']} Dream Coins!',
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 450,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Tasks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.blueAccent, blurRadius: 10)],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildTaskItem(_tasks[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, int index) {
    final bool isCompleted =
        (task['progress'] as num) >= (task['target'] as num);
    final bool isClaimed = task['claimed'] ?? false;
    final double progress = (task['progress'] as num).toDouble();
    final double target = (task['target'] as num).toDouble();
    final double percent = (progress / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : isCompleted
              ? Colors.amberAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isClaimed
                  ? Colors.greenAccent.withValues(alpha: 0.2)
                  : Colors.blueAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaimed
                  ? Icons.check_circle_rounded
                  : _getIconForType(task['type']),
              color: isClaimed ? Colors.greenAccent : Colors.blueAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? 'Task',
                  style: TextStyle(
                    color: isClaimed ? Colors.white70 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  task['description'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (!isClaimed)
                  GameProgressBar(
                    percent: percent,
                    gradientColors: isCompleted
                        ? [Colors.amberAccent, Colors.orange]
                        : [Colors.blueAccent, Colors.lightBlueAccent],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isCompleted && !isClaimed)
            ElevatedButton(
              onPressed: () => _claimTask(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CLAIM',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          else if (isClaimed)
            const Text(
              'CLAIMED',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${progress.toInt()}/${target.toInt()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.toll_rounded,
                      color: Colors.amberAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task['reward']}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? type) {
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
