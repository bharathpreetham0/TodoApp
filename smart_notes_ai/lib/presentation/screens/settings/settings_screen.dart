import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/settings/settings_cubit.dart';
import '../../../services/ai/ai_service.dart';
import 'model_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  final AIService aiService;

  const SettingsScreen({
    Key? key,
    required this.aiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              _buildSectionHeader(context, 'AI Features'),
              
              SwitchListTile(
                title: const Text('Enable AI Features'),
                subtitle: Text(
                  kIsWeb 
                    ? 'AI runs in your browser'
                    : 'Offline AI for summarization and tasks',
                ),
                value: state.aiEnabled,
                onChanged: (value) {
                  context.read<SettingsCubit>().setAIEnabled(value);
                  aiService.setEnabled(value);
                },
                secondary: const Icon(Icons.psychology),
              ),

              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Model Management'),
                  subtitle: Text(_getModelStatusText()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModelManagementScreen(
                          aiService: aiService,
                        ),
                      ),
                    );
                  },
                ),

              const Divider(),
              _buildSectionHeader(context, 'Privacy & Security'),

              SwitchListTile(
                title: const Text('Biometric Lock'),
                subtitle: const Text('Require fingerprint/face ID'),
                value: state.biometricEnabled,
                onChanged: (value) {
                  context.read<SettingsCubit>().setBiometricEnabled(value);
                },
                secondary: const Icon(Icons.fingerprint),
              ),

              SwitchListTile(
                title: const Text('Encrypt Notes'),
                subtitle: const Text('AES-256 encryption'),
                value: state.encryptionEnabled,
                onChanged: (value) {
                  context.read<SettingsCubit>().setEncryptionEnabled(value);
                },
                secondary: const Icon(Icons.lock),
              ),

              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showPrivacyPolicy(context);
                },
              ),

              const Divider(),
              _buildSectionHeader(context, 'Appearance'),

              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: Text(_getThemeText(state.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context),
              ),

              const Divider(),
              _buildSectionHeader(context, 'Notifications'),

              SwitchListTile(
                title: const Text('Reminders'),
                subtitle: const Text('Task and note reminders'),
                value: state.notificationsEnabled,
                onChanged: (value) {
                  context.read<SettingsCubit>().setNotificationsEnabled(value);
                },
                secondary: const Icon(Icons.notifications),
              ),

              SwitchListTile(
                title: const Text('Daily Digest'),
                subtitle: const Text('Morning summary of tasks'),
                value: state.dailyDigestEnabled,
                onChanged: (value) {
                  context.read<SettingsCubit>().setDailyDigestEnabled(value);
                },
                secondary: const Icon(Icons.article),
              ),

              const Divider(),
              _buildSectionHeader(context, 'Data'),

              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Export Data'),
                subtitle: const Text('Backup all notes and tasks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showExportDialog(context);
                },
              ),

              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Import Data'),
                subtitle: const Text('Restore from backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showImportDialog(context);
                },
              ),

              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Clear All Data',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('Delete all notes, tasks, and settings'),
                onTap: () => _showClearDataDialog(context),
              ),

              const Divider(),
              _buildSectionHeader(context, 'About'),

              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Version'),
                subtitle: const Text('1.0.0+1'),
              ),

              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open Source'),
                subtitle: const Text('MIT License'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // Open GitHub repo
                },
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  '🔒 100% Offline & Private',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your data never leaves your device',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getModelStatusText() {
    final currentModel = aiService.currentModel;
    if (currentModel != null) {
      return 'Using ${currentModel.displayName}';
    }
    return 'No model downloaded';
  }

  String _getThemeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: context.read<SettingsCubit>().state.themeMode,
              onChanged: (value) {
                context.read<SettingsCubit>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: context.read<SettingsCubit>().state.themeMode,
              onChanged: (value) {
                context.read<SettingsCubit>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System default'),
              value: ThemeMode.system,
              groupValue: context.read<SettingsCubit>().state.themeMode,
              onChanged: (value) {
                context.read<SettingsCubit>().setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Smart Notes AI Privacy Policy\n\n'
            '1. Data Storage\n'
            'All your data is stored locally on your device. '
            'We never send your notes, tasks, or any personal information '
            'to external servers.\n\n'
            '2. AI Processing\n'
            'AI features run completely offline on your device. '
            'Your notes are never sent to the cloud for processing.\n\n'
            '3. Encryption\n'
            'When enabled, your notes are encrypted using AES-256 '
            'encryption with keys stored securely on your device.\n\n'
            '4. No Tracking\n'
            'We do not collect analytics, usage data, or any personal '
            'information. Your privacy is our priority.\n\n'
            '5. Open Source\n'
            'This app is open source. You can review the code to verify '
            'our privacy claims.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  void _showImportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import feature coming soon!')),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your notes, tasks, reminders, '
          'and settings. This action cannot be undone.\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear all data
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Feature coming soon!'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
