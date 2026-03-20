import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LEADERBOARDS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const TabBar(
                indicatorColor: Colors.amberAccent,
                labelColor: Colors.amberAccent,
                unselectedLabelColor: Colors.white38,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'Level'),
                  Tab(text: 'Coins'),
                  Tab(text: 'Time'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    LeaderboardListPlaceholder(type: 'Level'),
                    LeaderboardListPlaceholder(type: 'Coins'),
                    LeaderboardListPlaceholder(type: 'Time'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardListPlaceholder extends StatelessWidget {
  final String type;

  const LeaderboardListPlaceholder({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 10,
      separatorBuilder: (context, index) => const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        return ListTile(
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _getRankColor(index),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          title: Text(
            'Dreamer_${index + 1024}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          trailing: Text(
            _getPlaceholderValue(type, index),
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amberAccent;
    if (index == 1) return const Color(0xFFC0C0C0); // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.white24;
  }

  String _getPlaceholderValue(String type, int index) {
    if (type == 'Level') return 'LVL ${50 - index}';
    if (type == 'Coins') return '${(10 - index) * 1000} DC';
    if (type == 'Time') return '${24 - index}h';
    return '0';
  }
}
