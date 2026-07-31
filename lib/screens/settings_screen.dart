import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/api_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/focus_effect_wrapper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final apiConfig = ref.watch(apiConfigProvider);
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: theme.theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                FocusEffectWrapper(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Settings content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Appearance Section
                _buildSectionCard(
                  icon: Icons.palette,
                  title: 'Appearance',
                  children: [
                    _buildThemeGrid(theme),
                  ],
                ),

                const SizedBox(height: 16),

                // API Keys Section
                _buildSectionCard(
                  icon: Icons.key,
                  title: 'API Keys',
                  children: [
                    _apiKeyTile(
                      title: 'SteamGridDB',
                      subtitle: 'Grid art and covers',
                      enabled: apiConfig.steamGridDbEnabled,
                      hasKey: apiConfig.steamGridDbKey != null,
                      onAdd: () => _showSteamGridDbDialog(context),
                      onRemove: () {
                        ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(null);
                      },
                    ),
                    _apiKeyTile(
                      title: 'IGDB',
                      subtitle: 'Game info and metadata',
                      enabled: apiConfig.igdbEnabled,
                      hasKey: apiConfig.igdbClientId != null,
                      onAdd: () => _showIgdbDialog(context),
                      onRemove: () {
                        ref.read(apiConfigProvider.notifier).updateIgdbCredentials(null, null);
                      },
                    ),
                    _apiKeyTile(
                      title: 'ScreenScraper',
                      subtitle: 'Box art and screenshots',
                      enabled: apiConfig.screenScraperEnabled,
                      hasKey: apiConfig.screenScraperUsername != null,
                      onAdd: () => _showScreenScraperDialog(context),
                      onRemove: () {
                        ref.read(apiConfigProvider.notifier).updateScreenScraperCredentials(null, null);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // General Settings
                _buildSectionCard(
                  icon: Icons.settings,
                  title: 'General',
                  children: [
                    _buildToggleRow(
                      title: 'Auto-start on mount',
                      subtitle: 'Launch Project Indie when drive is inserted',
                      value: settings.autoStartEnabled,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).updateSettings(
                              settings.copyWith(autoStartEnabled: value),
                            );
                      },
                    ),
                    _buildToggleRow(
                      title: 'Auto-scan on startup',
                      subtitle: 'Scan Games folder when app launches',
                      value: settings.autoScanOnStartup,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).updateSettings(
                              settings.copyWith(autoScanOnStartup: value),
                            );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // About Section
                _buildSectionCard(
                  icon: Icons.info,
                  title: 'About',
                  children: [
                    _buildInfoRow('Version', '1.0.0'),
                    _buildInfoRow('OmniSave', 'v0.2.0'),
                    const SizedBox(height: 8),
                    Text(
                      'A portable offline-first DRM-free game launcher.',
                      style: TextStyle(
                        color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = ref.watch(themeProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: theme.theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: theme.theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeGrid(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Theme',
            style: TextStyle(
              color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2,
            ),
            itemCount: theme.availableThemes.length,
            itemBuilder: (context, index) {
              final appTheme = theme.availableThemes[index];
              final isSelected = theme.currentTheme == appTheme;

              return FocusEffectWrapper(
                onTap: () => theme.setTheme(appTheme),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getThemeColor(appTheme).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.theme.colorScheme.primary
                          : theme.theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getThemeName(appTheme),
                      style: TextStyle(
                        color: isSelected
                            ? theme.theme.colorScheme.primary
                            : theme.theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getThemeColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.defaultDark:
        return Colors.deepPurple;
      case AppTheme.light:
        return Colors.grey;
      case AppTheme.crimson:
        return Colors.redAccent;
      case AppTheme.roseGold:
        return Colors.pinkAccent;
      case AppTheme.neonCyan:
        return Colors.cyanAccent;
      case AppTheme.oledBlack:
        return Colors.grey;
    }
  }

  String _getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.defaultDark:
        return 'Dark';
      case AppTheme.light:
        return 'Light';
      case AppTheme.crimson:
        return 'Crimson';
      case AppTheme.roseGold:
        return 'Rose Gold';
      case AppTheme.neonCyan:
        return 'Neon Cyan';
      case AppTheme.oledBlack:
        return 'OLED';
    }
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FocusEffectWrapper(
            onTap: () => onChanged(!value),
            child: Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: value
                    ? theme.theme.colorScheme.primary
                    : theme.theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: theme.theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _apiKeyTile({
    required String title,
    required String subtitle,
    required bool enabled,
    required bool hasKey,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final theme = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.green : Colors.white24,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasKey)
            FocusEffectWrapper(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 16),
              ),
            )
          else
            FocusEffectWrapper(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Add Key',
                  style: TextStyle(
                    color: theme.theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSteamGridDbDialog(BuildContext context) {
    final controller = TextEditingController();
    _showApiKeyDialog(
      context: context,
      title: 'SteamGridDB API Key',
      controller: controller,
      onSave: () {
        ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(controller.text);
      },
    );
  }

  void _showIgdbDialog(BuildContext context) {
    final clientController = TextEditingController();
    final secretController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('IGDB Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientController,
              decoration: const InputDecoration(
                hintText: 'Client ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secretController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Client Secret',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(apiConfigProvider.notifier).updateIgdbCredentials(
                    clientController.text,
                    secretController.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showScreenScraperDialog(BuildContext context) {
    final userController = TextEditingController();
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('ScreenScraper Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                hintText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(apiConfigProvider.notifier).updateScreenScraperCredentials(
                    userController.text,
                    passController.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter your API key',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
