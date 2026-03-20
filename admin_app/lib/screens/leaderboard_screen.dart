import 'package:flutter/material.dart';
import '../widgets/admin_ui_components.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Global Leaderboards',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'Level Rank'),
              Tab(text: 'Most Coins'),
              Tab(text: 'Most Playtime'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LeaderboardListPlaceholder(title: 'Level Rank'),
            LeaderboardListPlaceholder(title: 'Most Coins'),
            LeaderboardListPlaceholder(title: 'Most Playtime'),
          ],
        ),
      ),
    );
  }
}

class LeaderboardListPlaceholder extends StatelessWidget {
  final String title;

  const LeaderboardListPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Players by $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AdminCard(
              width: double.infinity,
              child: ListView.separated(
                itemCount: 10,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF2A2A4A),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _getRankColor(index),
                      radius: 16,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      'Player_${index + 1024}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'UID: user_id_placeholder_$index',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: Text(
                      _getPlaceholderValue(title, index),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amberAccent;
    if (index == 1) return const Color(0xFFC0C0C0); // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.white24;
  }

  String _getPlaceholderValue(String title, int index) {
    if (title == 'Level Rank') return 'LVL ${50 - index}';
    if (title == 'Most Coins') return '${(10 - index) * 1000} DC';
    if (title == 'Most Playtime') return '${24 - index}h';
    return '0';
  }
}
