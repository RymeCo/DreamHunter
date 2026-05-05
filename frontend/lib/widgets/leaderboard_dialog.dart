import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';

class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({super.key});

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  bool _isLoading = true;
  String _lastUpdated = '';
  List<dynamic> _topLevels = [];
  List<dynamic> _topCoins = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await ProfileManager.instance.getLeaderboard();
      if (mounted) {
        setState(() {
          _lastUpdated = data['lastUpdated'] ?? '';
          _topLevels = data['topLevels'] ?? [];
          _topCoins = data['topCoins'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Leaderboard Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StandardGlassPage(
        title: 'LEADERBOARDS',
        isFullScreen: true,
        footer: [
          if (_lastUpdated.isNotEmpty)
            Center(
              child: Text(
                'Daily Update: ${_formatDate(_lastUpdated)} (PHT)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
              ),
            ),
        ],
        child: Column(
          children: [
            TabBar(
              indicatorColor: Colors.amberAccent,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.38),
              labelStyle: Theme.of(context).textTheme.labelLarge,
              unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
              tabs: const [Tab(text: 'Level'), Tab(text: 'Coins')],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildList(_topLevels, 'Level'),
                        _buildList(_topCoins, 'Coins'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> entries, String unit) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No rankings yet (Min ${unit == 'Level' ? 'Lv 50' : '30k Coins'})',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.54),
              ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final rank = index + 1;
        final color = _getRankColor(rank);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: rank <= 3
                ? Border.all(color: color.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['name'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry['value']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    unit.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amberAccent;
    if (rank == 2) return const Color(0xFFE0E0E0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return Colors.white70;
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final date = DateTime.parse(iso);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return iso;
    }
  }
}
