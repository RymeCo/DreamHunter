import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
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
            LeaderboardList(type: 'level'),
            LeaderboardList(type: 'coins'),
            LeaderboardList(type: 'playtime'),
          ],
        ),
      ),
    );
  }
}

class LeaderboardList extends StatefulWidget {
  final String type;

  const LeaderboardList({super.key, required this.type});

  @override
  State<LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<LeaderboardList> {
  late Future<Map<String, dynamic>?> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    _leaderboardFuture = adminProvider.service.getLeaderboard(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Players by ${widget.type[0].toUpperCase()}${widget.type.substring(1)}',
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
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    );
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return const Center(
                      child: Text(
                        'Failed to load leaderboard',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  final response = snapshot.data!;
                  final List<dynamic> topPlayers = response['top'] ?? [];
                  
                  if (topPlayers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No players found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: topPlayers.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Color(0xFF2A2A4A),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final entry = topPlayers[index] as Map<String, dynamic>;
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
                          entry['displayName'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'UID: ${entry['uid']}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: Text(
                          _getDisplayValue(widget.type, entry),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
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

  String _getDisplayValue(String type, Map<String, dynamic> entry) {
    if (type == 'level') return 'LVL ${entry['level'] ?? 1}';
    if (type == 'coins') return '${entry['dreamCoins'] ?? 0} DC';
    if (type == 'playtime') return '${(entry['playtime'] ?? 0) ~/ 3600}h';
    return '0';
  }
}
