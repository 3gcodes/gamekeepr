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
  late TextEditingController _s3BucketController;
  late TextEditingController _s3RegionController;
  late TextEditingController _s3AccessKeyController;
  late TextEditingController _s3SecretKeyController;
  bool _isSaving = false;
  bool _obscureToken = true;
  bool _obscurePassword = true;
  bool _obscureS3AccessKey = true;
  bool _obscureS3SecretKey = true;
  bool _s3Enabled = false;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Initialize controllers immediately to avoid late initialization errors
    _usernameController = TextEditingController();
    _apiTokenController = TextEditingController();
    _passwordController = TextEditingController();
    _s3BucketController = TextEditingController();
    _s3RegionController = TextEditingController();
    _s3AccessKeyController = TextEditingController();
    _s3SecretKeyController = TextEditingController();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('bgg_username') ?? '';
    final apiToken = prefs.getString('bgg_api_token') ?? '';
    final password = await _secureStorage.read(key: 'bgg_password') ?? '';

    // Load S3 settings
    final s3Enabled = prefs.getBool('s3_enabled') ?? false;
    final s3Bucket = prefs.getString('s3_bucket') ?? '';
    final s3Region = prefs.getString('s3_region') ?? 'us-east-1';
    final s3AccessKey = await _secureStorage.read(key: 's3_access_key') ?? '';
    final s3SecretKey = await _secureStorage.read(key: 's3_secret_key') ?? '';

    _usernameController.text = username;
    _apiTokenController.text = apiToken;
    _passwordController.text = password;
    _s3BucketController.text = s3Bucket;
    _s3RegionController.text = s3Region;
    _s3AccessKeyController.text = s3AccessKey;
    _s3SecretKeyController.text = s3SecretKey;
    _s3Enabled = s3Enabled;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiTokenController.dispose();
    _passwordController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
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

      // Save S3 settings
      final s3Bucket = _s3BucketController.text.trim();
      final s3Region = _s3RegionController.text.trim();
      final s3AccessKey = _s3AccessKeyController.text.trim();
      final s3SecretKey = _s3SecretKeyController.text.trim();

      await prefs.setBool('s3_enabled', _s3Enabled);
      await prefs.setString('s3_bucket', s3Bucket);
      await prefs.setString('s3_region', s3Region);

      // Save S3 keys to secure storage
      await _secureStorage.write(
        key: 's3_access_key',
        value: s3AccessKey,
      );
      await _secureStorage.write(
        key: 's3_secret_key',
        value: s3SecretKey,
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
        [XFile(backupPath, name: 'gamekeepr_backup_$formattedDate.zip', mimeType: 'application/zip')],
        text: 'Game Keepr backup (database + images) from $formattedDate',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created with database + images! Save it to iCloud Drive or Files app.'),
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
        title: const Text('Restore Backup'),
        content: const Text(
          'Are you sure you want to restore from this backup? '
          'Your current data and collectible images will be replaced. This cannot be undone.',
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
        await ref.read(collectiblesProvider.notifier).loadCollectibles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully! Database and images recovered.'),
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

          // S3 Storage Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'S3 Storage (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Enable S3 Storage'),
                  subtitle: const Text('Store collectible images in Amazon S3'),
                  value: _s3Enabled,
                  onChanged: (value) {
                    setState(() {
                      _s3Enabled = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (_s3Enabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _s3BucketController,
                    decoration: InputDecoration(
                      labelText: 'S3 Bucket Name',
                      hintText: 'my-bucket-name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.cloud),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _s3RegionController,
                    decoration: InputDecoration(
                      labelText: 'S3 Region',
                      hintText: 'us-east-1',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _s3AccessKeyController,
                    obscureText: _obscureS3AccessKey,
                    decoration: InputDecoration(
                      labelText: 'Access Key ID',
                      hintText: 'Enter your AWS access key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureS3AccessKey ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureS3AccessKey = !_obscureS3AccessKey;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _s3SecretKeyController,
                    obscureText: _obscureS3SecretKey,
                    decoration: InputDecoration(
                      labelText: 'Secret Access Key',
                      hintText: 'Enter your AWS secret key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureS3SecretKey ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureS3SecretKey = !_obscureS3SecretKey;
                          });
                        },
                      ),
                    ),
                  ),
                ],
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
