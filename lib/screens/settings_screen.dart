import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/theme_provider.dart';
import 'package:learning_pwa/screens/settings/audio_settings_screen.dart';
import 'package:learning_pwa/widgets/error_retry_view.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SettingsModel _settings;
  bool _loading = true;
  Object? _loadError;
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('settings');
      if (!mounted) return;
      setState(() {
        _settings = raw != null
            ? SettingsModel.fromRawJson(raw)
            : SettingsModel.defaultSettings();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', _settings.toRawJson());
  }

  void _addTime(String time) {
    if (!_settings.notificationTimes.contains(time)) {
      setState(() {
        _settings.notificationTimes.add(time);
      });
      _saveSettings();
    }
  }

  void _removeTime(String time) {
    setState(() {
      _settings.notificationTimes.remove(time);
    });
    _saveSettings();
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _settings.notificationsEnabled = value;
    });
    _saveSettings();
  }

  void _toggleTheme(bool value) {
    setState(() {
      _settings.darkMode = value;
    });
    // Update app-wide theme
    ref.read(themeModeProvider.notifier).setTheme(value ? ThemeMode.dark : ThemeMode.light);
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ErrorRetryView(
          message: 'Couldn\'t load your settings.',
          error: _loadError,
          showDetails: kDebugMode,
          onRetry: _loadSettings,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Enable Notifications'),
              value: _settings.notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            if (_settings.notificationsEnabled) ...[
              const SizedBox(height: 8),
              const Text('Notification Times:'),
              Wrap(
                spacing: 8,
                children: _settings.notificationTimes.map((t) => Chip(
                  label: Text(t),
                  onDeleted: () => _removeTime(t),
                )).toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Add Time (e.g. 10:00)',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final time = _timeController.text.trim();
                      if (RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$')
                          .hasMatch(time)) {
                        _addTime(time);
                        _timeController.clear();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid 24-hour time, e.g. 09:30'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            
            // Audio Settings Navigation
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Audio Settings'),
              subtitle: const Text('Voice and speech preferences'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AudioSettingsScreen(),
                  ),
                );
              },
            ),
            
            // Reset Center Navigation
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.orange),
              title: const Text('Reset Center'),
              subtitle: const Text('Reset progress and manage reverts'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/settings/reset'),
            ),
            
            const Divider(height: 32),
            
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: _settings.darkMode,
              onChanged: _toggleTheme,
            ),
            
            const Divider(height: 32),
            
            // Study Batch Size
            ListTile(
              title: const Text('Cards per Study Session'),
              subtitle: Text(
                _settings.studyBatchSize == 0
                    ? 'Unlimited'
                    : '${_settings.studyBatchSize} cards',
              ),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: _settings.studyBatchSize.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: _settings.studyBatchSize == 0
                      ? 'Unlimited'
                      : '${_settings.studyBatchSize}',
                  onChanged: (value) {
                    setState(() {
                      _settings.studyBatchSize = value.toInt();
                    });
                    _saveSettings();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
