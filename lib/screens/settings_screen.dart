import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Manage your application preferences and account settings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: AppConstants.largePadding),

            // Settings Content
            Expanded(
              child: ListView(
                children: [
                  _buildSettingsSection(
                    title: 'Account Settings',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.person_outline,
                        title: 'Profile Information',
                        subtitle: 'Update your personal information',
                        onTap: () {
                          _showComingSoonDialog('Profile settings');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        subtitle: 'Update your account password',
                        onTap: () {
                          _showComingSoonDialog('Password change');
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.largePadding),
                  
                  _buildSettingsSection(
                    title: 'Application Settings',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        onTap: () {
                          _showComingSoonDialog('Notification settings');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Choose your preferred theme',
                        onTap: () {
                          _showComingSoonDialog('Theme settings');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.language_outlined,
                        title: 'Language',
                        subtitle: 'Select your language preference',
                        onTap: () {
                          _showComingSoonDialog('Language settings');
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.largePadding),
                  
                  _buildSettingsSection(
                    title: 'System Settings',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.backup_outlined,
                        title: 'Data Backup',
                        subtitle: 'Backup and restore data',
                        onTap: () {
                          _showComingSoonDialog('Data backup');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.security_outlined,
                        title: 'Security',
                        subtitle: 'Manage security settings',
                        onTap: () {
                          _showComingSoonDialog('Security settings');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'App version and information',
                        onTap: () {
                          _showAboutDialog();
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.largePadding),
                  
                  // Logout Button
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Colors.red[600],
                      ),
                      title: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text('Sign out of your account'),
                      onTap: () {
                        _showSignOutConfirmation();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Godtrasco Admin Panel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: ${AppConstants.appVersion}'),
            const SizedBox(height: AppConstants.smallPadding),
            const Text('Transportation Management System'),
            const SizedBox(height: AppConstants.smallPadding),
            Text('© 2025 Godtrasco. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}