import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';

class LeaderboardDialog extends StatelessWidget {
  const LeaderboardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Center(
        child: LiquidGlassDialog(
          width: 400,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const GameDialogHeader(title: 'LEADERBOARDS'),
              TabBar(
                indicatorColor: Colors.amberAccent,
                labelColor: Colors.amberAccent,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.38),
                labelStyle: Theme.of(context).textTheme.labelLarge,
                unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
                tabs: const [
                  Tab(text: 'Level'),
                  Tab(text: 'Coins'),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Rankings coming soon',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
