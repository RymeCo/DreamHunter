import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';

class LeaderboardDialog extends StatelessWidget {
  const LeaderboardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Center(
        child: LiquidGlassDialog(
          width: 400,
          height: 550,
          child: Column(
            children: [
              const GameDialogHeader(title: 'LEADERBOARDS'),
              const TabBar(
                indicatorColor: Colors.amberAccent,
                labelColor: Colors.amberAccent,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  Tab(text: 'Level'),
                  Tab(text: 'Coins'),
                  Tab(text: 'Time'),
                ],
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Rankings coming soon',
                    style: TextStyle(color: Colors.white54),
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
