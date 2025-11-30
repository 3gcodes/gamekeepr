import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _apiTokenController;
  late TextEditingController _passwordController;
  bool _isSaving = false;
  bool _obscureToken = true;
  bool _obscurePassword = true;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Initialize controllers immediately to avoid late initialization errors
    _usernameController = TextEditingController();
    _apiTokenController = TextEditingController();
    _passwordController = TextEditingController();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('bgg_username') ?? '';
    final apiToken = prefs.getString('bgg_api_token') ?? '';
    final password = await _secureStorage.read(key: 'bgg_password') ?? '';

    _usernameController.text = username;
    _apiTokenController.text = apiToken;
    _passwordController.text = password;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiTokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _usernameController.text.trim();
      final apiToken = _apiTokenController.text.trim();
      final password = _passwordController.text.trim();

      await prefs.setString('bgg_username', username);
      await prefs.setString('bgg_api_token', apiToken);

      // Save password to secure storage
      await _secureStorage.write(
        key: 'bgg_password',
        value: password,
      );

      // Update provider
      ref.read(bggUsernameProvider.notifier).state = username;

      // Validate BGG login if both username and password are provided
      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          final bggService = ref.read(bggServiceProvider);
          await bggService.login(username, password);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings saved and BGG login successful!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (loginError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Settings saved but BGG login failed: $loginError'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete all games from your local collection? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteAllGames();
        await ref.read(gamesProvider.notifier).loadGames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportDatabase() async {
    try {
      // Export the database
      final backupPath = await DatabaseService.instance.exportDatabase();

      if (!mounted) return;

      final timestamp = DateTime.now();
      final formattedDate = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';

      // Get the screen size for share position
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Share the file using iOS share sheet
      // User can then choose to save to iCloud Drive, Files, etc.
      final result = await Share.shareXFiles(
        [XFile(backupPath, name: 'gamekeepr_backup_$formattedDate.db', mimeType: 'application/octet-stream')],
        text: 'Game Keepr database backup from $formattedDate',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup file ready! Save it to iCloud Drive or Files app.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreDatabase() async {
    // Show file picker to select backup file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final filePath = result.files.first.path;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access the selected file'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Confirm restoration
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          'Are you sure you want to restore from this backup? '
          'Your current data will be replaced. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.restoreDatabase(filePath);
        await ref.read(gamesProvider.notifier).loadGames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error restoring database: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameCount = ref.watch(gamesProvider).when(
          data: (games) => games.length,
          loading: () => 0,
          error: (_, __) => 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // BGG Username Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BoardGameGeek Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'BGG Username',
                    hintText: 'Enter your BGG username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiTokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    labelText: 'BGG API Token',
                    hintText: 'Enter your BGG API token',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'BGG Password',
                    hintText: 'Enter your BGG password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCredentials,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Collection Info Section
          ListTile(
            leading: const Icon(Icons.casino),
            title: const Text('Games in Collection'),
            trailing: Text(
              '$gameCount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Data Management Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportDatabase,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Export Database Backup'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _restoreDatabase,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore from Backup'),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearAllData,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Clear All Data',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // About Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Game Keepr helps you manage your board game collection with NFC tag support. '
                  'Sync your games from BoardGameGeek and track their physical locations.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
