import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backend_service.dart';
import '../services/format_utils.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';

class LeaderboardDialog extends StatelessWidget {
  final BackendService backendService;

  const LeaderboardDialog({super.key, required this.backendService});

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
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'Level'),
                  Tab(text: 'Coins'),
                  Tab(text: 'Time'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    LeaderboardList(backendService: backendService, type: 'level'),
                    LeaderboardList(backendService: backendService, type: 'coins'),
                    LeaderboardList(backendService: backendService, type: 'playtime'),
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

class LeaderboardList extends StatefulWidget {
  final BackendService backendService;
  final String type;

  const LeaderboardList({super.key, required this.backendService, required this.type});

  @override
  State<LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<LeaderboardList> {
  late Future<Map<String, dynamic>?> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = widget.backendService.getLeaderboard(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
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
        final Map<String, dynamic>? userStanding = response['user'];

        if (topPlayers.isEmpty) {
          return const Center(
            child: Text(
              'No players found',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: topPlayers.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final entry = topPlayers[index] as Map<String, dynamic>;
                  return _buildLeaderboardTile(entry, index: index);
                },
              ),
            ),
            if (userStanding != null) ...[
              const Divider(color: Colors.amberAccent, height: 1),
              Container(
                color: Colors.white.withValues(alpha: 0.05),
                child: _buildLeaderboardTile(
                  userStanding,
                  index: (userStanding['rank'] as int) - 1,
                  isCurrentUser: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> entry, {required int index, bool isCurrentUser = false}) {
    final int rank = index + 1;
    final bool showCircle = rank <= 100;
    final String formattedRank = NumberFormat('#,###').format(rank);

    return ListTile(
      leading: SizedBox(
        width: showCircle ? 28 : 50,
        height: 28,
        child: showCircle
            ? Container(
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.amberAccent : _getRankColor(index),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  formattedRank,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.amberAccent : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11, // Slightly smaller font for long numbers
                  ),
                ),
              ),
      ),
      title: Text(
        isCurrentUser ? '${entry['displayName']} (YOU)' : (entry['displayName'] ?? 'Unknown'),
        style: TextStyle(
          color: isCurrentUser ? Colors.amberAccent : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: Text(
        _getDisplayValue(widget.type, entry),
        style: const TextStyle(
          color: Colors.amberAccent,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
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
    if (type == 'playtime') {
      return FormatUtils.formatCompactPlaytime(entry['playtime'] ?? 0);
    }
    return '0';
  }
}
