import 'package:flutter/material.dart';
import '../services/offline_cache.dart';
import '../services/backend_service.dart';
import 'liquid_glass_dialog.dart';
import 'custom_snackbar.dart';

class DailyTasksDialog extends StatefulWidget {
  const DailyTasksDialog({super.key});

  @override
  State<DailyTasksDialog> createState() => _DailyTasksDialogState();
}

class _DailyTasksDialogState extends State<DailyTasksDialog> {
  Map<String, dynamic>? _dailyTasks;
  bool _isLoading = true;
  bool _isClaiming = false;
  final BackendService _backendService = BackendService();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await OfflineCache.getDailyTasks();
    if (mounted) {
      setState(() {
        _dailyTasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimTask(String taskId) async {
    setState(() => _isClaiming = true);
    final result = await _backendService.claimDailyTask(taskId);

    if (result != null && result['status'] == 'success') {
      // Update local cache
      final dailyTasks = result['dailyTasks'] as Map<String, dynamic>;
      final reward = result['rewardGranted'] as int;

      final current = await OfflineCache.getCurrency();
      await OfflineCache.saveCurrency(
        (current['dreamCoins'] ?? 0) + reward,
        current['hellStones'] ?? 0,
        current['playtime'] ?? 0,
        current['freeSpins'] ?? 0,
        current['xp'] ?? 0,
        current['level'] ?? 1,
        current['avatarId'] ?? 0,
        current['createdAt'],
        dailyTasks,
      );

      await _loadTasks();
      if (mounted) {
        showCustomSnackBar(context, 'Reward claimed: $reward Dream Coins!', type: SnackBarType.success);
      }
    } else {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to claim reward. Try again later.', type: SnackBarType.error);
      }
    }
    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 400,
      padding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
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
                      shadows: [
                        Shadow(
                          color: Colors.blueAccent,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                )
              else if (_dailyTasks == null || _dailyTasks!['tasks'] == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No tasks available today.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: (_dailyTasks!['tasks'] as List).length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = (_dailyTasks!['tasks'] as List)[index];
                      return _buildTaskItem(task);
                    },
                  ),
                ),
            ],
          ),
          if (_isClaiming)
            const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final bool isCompleted = (task['progress'] as num) >= (task['target'] as num);
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
              isClaimed ? Icons.check_circle_rounded : _getIconForType(task['type']),
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (!isClaimed)
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCompleted
                                  ? [Colors.amberAccent, Colors.orange]
                                  : [Colors.blueAccent, Colors.lightBlueAccent],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: isCompleted
                                    ? Colors.orange.withValues(alpha: 0.5)
                                    : Colors.blue.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isCompleted && !isClaimed)
            ElevatedButton(
              onPressed: () => _claimTask(task['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )
          else if (isClaimed)
            const Text(
              'CLAIMED',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
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
