import 'package:flutter/material.dart';
import 'saved_for_later_screen.dart';
import 'scheduled_games_screen.dart';
import 'active_loans_screen.dart';
import 'move_games_screen.dart';
import 'manage_tags_screen.dart';
import 'settings_screen.dart';

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
            icon: Icons.bookmark,
            title: 'Saved',
            subtitle: 'Games saved for later',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedForLaterScreen()),
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
