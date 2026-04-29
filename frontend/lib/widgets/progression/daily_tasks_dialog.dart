import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/models/task_model.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

class DailyTasksDialog extends StatefulWidget {
  const DailyTasksDialog({super.key});

  @override
  State<DailyTasksDialog> createState() => _DailyTasksDialogState();
}

class _DailyTasksDialogState extends State<DailyTasksDialog> {
  // Logic Gap Fix: Using a structured model for type safety and progress logic.
  late final List<DailyTask> _tasks;

  @override
  void initState() {
    super.initState();
    _initializeTasks();
  }

  void _initializeTasks() {
    // In a full implementation, this would be fetched from a TaskService.
    _tasks = [
      DailyTask(
        id: 'daily_login',
        title: 'Daily Login',
        description: 'Welcome back! Log in to the game.',
        target: 1,
        progress: 1,
        reward: 50,
        type: TaskType.login,
      ),
      DailyTask(
        id: 'send_messages',
        title: 'Chatterbox',
        description: 'Send 5 messages in global chat.',
        target: 5,
        progress: 2,
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
        progress: 4,
        reward: 200,
        type: TaskType.playtime,
      ),
    ];
  }

  Future<void> _claimTask(DailyTask task) async {
    if (!task.canClaim) return;

    // Logic Gap Fix: Actually update the global economy state.
    final success = await WalletManager.instance.updateBalance(
      coinsDelta: task.reward,
    );

    if (success) {
      HapticManager.instance.light();
      setState(() {
        task.claimed = true;
      });

      if (mounted) {
        showCustomSnackBar(
          context,
          'Claimed ${task.reward} Dream Coins!',
          type: SnackBarType.success,
        );
      }
    }
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
          _buildHeader(),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildTaskItem(_tasks[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'DAILY TASKS',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            shadows: [const Shadow(color: Colors.blueAccent, blurRadius: 10)],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildTaskItem(DailyTask task) {
    final glass = Theme.of(context).extension<GlassTheme>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glass?.baseOpacity ?? 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.claimed
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : task.isCompleted
              ? Colors.amberAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _buildTaskIcon(task),
          const SizedBox(width: 16),
          _buildTaskInfo(task),
          const SizedBox(width: 16),
          _buildTaskAction(task),
        ],
      ),
    );
  }

  Widget _buildTaskIcon(DailyTask task) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (task.claimed ? Colors.greenAccent : Colors.blueAccent)
            .withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        task.claimed ? Icons.check_circle_rounded : _getIcon(task.type),
        color: task.claimed ? Colors.greenAccent : Colors.blueAccent,
        size: 24,
      ),
    );
  }

  Widget _buildTaskInfo(DailyTask task) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: task.claimed ? Colors.white38 : Colors.white,
              fontSize: 14,
              decoration: task.claimed ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(task.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (!task.claimed)
            GameProgressBar(
              percent: task.percent,
              gradientColors: task.isCompleted
                  ? [Colors.amberAccent, Colors.orange]
                  : [Colors.blueAccent, Colors.lightBlueAccent],
            ),
        ],
      ),
    );
  }

  Widget _buildTaskAction(DailyTask task) {
    if (task.canClaim) {
      return ElevatedButton(
        onPressed: () => _claimTask(task),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
        ),
        child: const Text('CLAIM', style: TextStyle(fontSize: 12)),
      );
    }

    if (task.claimed) {
      return const Text(
        'CLAIMED',
        style: TextStyle(color: Colors.greenAccent, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${task.progress}/${task.target}',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.toll_rounded, color: Colors.amberAccent, size: 14),
            const SizedBox(width: 4),
            Text(
              '${task.reward}',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getIcon(TaskType type) {
    switch (type) {
      case TaskType.chat:
        return Icons.chat_bubble_rounded;
      case TaskType.spin:
        return Icons.casino_rounded;
      case TaskType.playtime:
        return Icons.timer_rounded;
      case TaskType.login:
        return Icons.login_rounded;
      case TaskType.generic:
        return Icons.task_alt_rounded;
    }
  }
}
