import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'scheduled_games_screen.dart';
import 'active_loans_screen.dart';
import 'move_games_screen.dart';
import 'manage_tags_screen.dart';
import 'game_recognition_screen.dart';
import 'settings_screen.dart';
import '../providers/recently_played_providers.dart';
import 'game_details_screen.dart';
import 'package:intl/intl.dart';

class MoreTabScreen extends StatelessWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.history,
            title: 'Recently Played',
            subtitle: 'View your play history',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _RecentlyPlayedScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.event,
            title: 'Scheduled Games',
            subtitle: 'Upcoming game sessions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduledGamesScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.card_giftcard,
            title: 'Loaned Games',
            subtitle: 'Games lent to others',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActiveLoansScreen()),
              );
            },
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.drive_file_move,
            title: 'Move Game(s)',
            subtitle: 'Bulk location management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoveGamesScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.label,
            title: 'Manage Tags',
            subtitle: 'Create and edit custom tags',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTagsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.camera_alt,
            title: 'Recognize Games',
            subtitle: 'Identify games using camera',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GameRecognitionScreen()),
              );
            },
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App configuration',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

// Recently Played Screen
class _RecentlyPlayedScreen extends ConsumerWidget {
  const _RecentlyPlayedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyPlayed = ref.watch(filteredRecentlyPlayedGamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played'),
      ),
      body: recentlyPlayed.when(
        data: (games) {
          if (games.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No games played yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging your plays!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final gameWithPlayInfo = games[index];
              final game = gameWithPlayInfo.game;
              final lastPlayed = gameWithPlayInfo.lastPlayed;
              final playCount = gameWithPlayInfo.playCount;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailsScreen(
                          game: game,
                          isOwned: game.owned,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail placeholder
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.casino, size: 32),
                        ),
                        const SizedBox(width: 12),
                        // Game info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.event, size: 14, color: Colors.green[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Last: ${DateFormat('MMM d, yyyy').format(lastPlayed)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$playCount ${playCount == 1 ? 'play' : 'plays'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
