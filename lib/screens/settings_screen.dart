import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import '../providers/theme_provider.dart';
import '../providers/api_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/game_library_provider.dart';
import '../services/autostart_service.dart';
import '../services/drive_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _autostartService = AutostartService();
  bool _autostartGenerated = false;

  Future<void> _pickDirectory(String field) async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select $field directory',
    );
    if (result != null && mounted) {
      final settings = ref.read(settingsProvider);
      // Convert to ~/ notation for portability
      final portable = DriveService.toPortable(result);
      if (field == 'Games') {
        await ref.read(settingsProvider.notifier).updateSettings(
              settings.copyWith(gamesPath: portable),
            );
        ref.invalidate(gameScannerProvider);
      } else {
        await ref.read(settingsProvider.notifier).updateSettings(
              settings.copyWith(savesPath: portable),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiConfig = ref.watch(apiConfigProvider);
    final settings = ref.watch(settingsProvider);
    final themeP = ref.watch(themeProvider);
    final cs = themeP.theme.colorScheme;

    return Scaffold(
      backgroundColor: themeP.theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Back sidebar strip
          Container(
            width: 72,
            color: cs.surface,
            child: Column(
              children: [
                const SizedBox(height: 16),
                _SidebarBack(onTap: () => Navigator.of(context).pop()),
                const Spacer(),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: cs.outline.withValues(alpha: 0.12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page header
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Configure your launcher',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    children: [
                      _Section(
                        icon: Icons.folder_open_rounded,
                        title: 'Directories',
                        children: [
                          _PathRow(
                            label: 'Games folder',
                            description: 'Where your game folders are stored',
                            path: settings.gamesPath,
                            onBrowse: () => _pickDirectory('Games'),
                          ),
                          _PathRow(
                            label: 'Saves folder',
                            description: 'Root folder for OmniSave backups',
                            path: settings.savesPath,
                            onBrowse: () => _pickDirectory('Saves'),
                          ),
                          _InfoRow(label: 'Config', value: DriveService.configPath),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: _ThemeGrid(themeP),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        icon: Icons.vpn_key_outlined,
                        title: 'API Keys',
                        children: [
                          _ApiKeyRow(
                            service: 'SteamGridDB',
                            description: 'Grid art and cover images',
                            icon: Icons.image_outlined,
                            connected: apiConfig.steamGridDbEnabled,
                            hasKey: apiConfig.steamGridDbKey != null,
                            onAdd: _showSteamGridDbDialog,
                            onRemove: () => ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(null),
                          ),
                          _ApiKeyRow(
                            service: 'IGDB',
                            description: 'Game info, screenshots, metadata',
                            icon: Icons.info_outlined,
                            connected: apiConfig.igdbEnabled,
                            hasKey: apiConfig.igdbClientId != null,
                            onAdd: _showIgdbDialog,
                            onRemove: () => ref.read(apiConfigProvider.notifier).updateIgdbCredentials(null, null),
                          ),
                          _ApiKeyRow(
                            service: 'ScreenScraper',
                            description: 'Box art and screenshots',
                            icon: Icons.collections_outlined,
                            connected: apiConfig.screenScraperEnabled,
                            hasKey: apiConfig.screenScraperUsername != null,
                            onAdd: _showScreenScraperDialog,
                            onRemove: () => ref.read(apiConfigProvider.notifier).updateScreenScraperCredentials(null, null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        icon: Icons.tune_outlined,
                        title: 'General',
                        children: [
                          _ToggleRow(
                            title: 'Auto-scan on startup',
                            subtitle: 'Scan the Games folder when the app launches',
                            value: settings.autoScanOnStartup,
                            onChanged: (v) => ref.read(settingsProvider.notifier)
                                .updateSettings(settings.copyWith(autoScanOnStartup: v)),
                          ),
                          _ToggleRow(
                            title: 'Auto-start on mount',
                            subtitle: 'Launch when drive is plugged in (requires AutoRun.inf)',
                            value: settings.autoStartEnabled,
                            onChanged: (v) => ref.read(settingsProvider.notifier)
                                .updateSettings(settings.copyWith(autoStartEnabled: v)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        icon: Icons.usb_rounded,
                        title: 'Portable AutoStart',
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generates an AutoRun.inf file so Windows automatically '
                                  'launches the app when the drive is inserted.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _ActionButton(
                                  label: _autostartGenerated ? 'Created!' : 'Generate AutoRun.inf',
                                  icon: _autostartGenerated ? Icons.check_circle_outline : Icons.bolt_rounded,
                                  success: _autostartGenerated,
                                  onTap: () async {
                                    final exePath = Platform.resolvedExecutable;
                                    final messenger = ScaffoldMessenger.of(context);
                                    await _autostartService.generateAutoRunInf(
                                      DriveService.appDir, exePath,
                                    );
                                    if (mounted) {
                                      setState(() => _autostartGenerated = true);
                                      messenger.showSnackBar(const SnackBar(
                                        content: Text('AutoRun.inf created'),
                                        backgroundColor: Colors.green,
                                      ));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        icon: Icons.restore_rounded,
                        title: 'Danger Zone',
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reset the setup wizard to reconfigure paths, '
                                  'API keys, and other settings from scratch.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your games and cached metadata will NOT be deleted.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _ActionButton(
                                  label: 'Reset Setup Wizard',
                                  icon: Icons.restart_alt_rounded,
                                  success: false,
                                  onTap: () => _confirmResetSetup(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSteamGridDbDialog() {
    final controller = TextEditingController();
    _showValidatedApiKeyDialog(
      title: 'SteamGridDB API Key',
      controller: controller,
      hint: 'Enter your API key',
      obscure: true,
      validator: (value) =>
          ref.read(apiConfigProvider.notifier).validateSteamGridDbKey(value),
      onSave: (value) =>
          ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(value),
    );
  }

  void _showIgdbDialog() {
    final client = TextEditingController();
    final secret = TextEditingController();
    _showValidatedMultiFieldDialog(
      title: 'IGDB Credentials',
      fields: [
        _DialogFieldData(controller: client, hint: 'Client ID'),
        _DialogFieldData(controller: secret, hint: 'Client Secret', obscure: true),
      ],
      validator: () => ref
          .read(apiConfigProvider.notifier)
          .validateIgdbCredentials(client.text, secret.text),
      onSave: () => ref
          .read(apiConfigProvider.notifier)
          .updateIgdbCredentials(client.text, secret.text),
    );
  }

  void _showScreenScraperDialog() {
    final user = TextEditingController();
    final pass = TextEditingController();
    _showValidatedMultiFieldDialog(
      title: 'ScreenScraper Credentials',
      fields: [
        _DialogFieldData(controller: user, hint: 'Username'),
        _DialogFieldData(controller: pass, hint: 'Password', obscure: true),
      ],
      validator: () => ref
          .read(apiConfigProvider.notifier)
          .validateScreenScraperCredentials(user.text, pass.text),
      onSave: () => ref
          .read(apiConfigProvider.notifier)
          .updateScreenScraperCredentials(user.text, pass.text),
    );
  }

  void _showValidatedApiKeyDialog({
    required String title,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required Future<bool> Function(String) validator,
    required void Function(String) onSave,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _ValidatedDialog(
        title: title,
        fields: [_DialogFieldData(controller: controller, hint: hint, obscure: obscure)],
        validator: () => validator(controller.text.trim()),
        onSave: () => onSave(controller.text.trim()),
      ),
    );
  }

  void _showValidatedMultiFieldDialog({
    required String title,
    required List<_DialogFieldData> fields,
    required Future<bool> Function() validator,
    required VoidCallback onSave,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _ValidatedDialog(
        title: title,
        fields: fields,
        validator: validator,
        onSave: onSave,
      ),
    );
  }

  void _confirmResetSetup() {
    final cs = ref.read(themeProvider).theme.colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 22),
            const SizedBox(width: 10),
            const Text('Reset Setup?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear your setup configuration and restart the setup wizard on next launch.',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Games and cached metadata will NOT be deleted.',
                      style: TextStyle(fontSize: 12, color: Colors.green[400]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final box = Hive.box('settings');
              await box.put('setupDone', false);
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _Section extends ConsumerWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: cs.primary, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
          ...children,
        ],
      ),
    );
  }
}

// ── Path row ─────────────────────────────────────────────────────────────────

class _PathRow extends ConsumerStatefulWidget {
  final String label;
  final String description;
  final String path;
  final VoidCallback onBrowse;

  const _PathRow({
    required this.label,
    required this.description,
    required this.path,
    required this.onBrowse,
  });

  @override
  ConsumerState<_PathRow> createState() => _PathRowState();
}

class _PathRowState extends ConsumerState<_PathRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    final isEmpty = widget.path.isEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? cs.primary.withValues(alpha: 0.04) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(widget.description,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? 'Not configured' : widget.path,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isEmpty ? cs.error.withValues(alpha: 0.8) : cs.onSurface.withValues(alpha: 0.55),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _SmallButton(label: 'Browse', onTap: widget.onBrowse),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends ConsumerWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurface.withValues(alpha: 0.4)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme grid ────────────────────────────────────────────────────────────────

class _ThemeGrid extends ConsumerWidget {
  final ThemeProvider themeP;
  const _ThemeGrid(this.themeP);

  static const _themeData = <AppTheme, (String, Color)>{
    AppTheme.amber:       ('Amber', Color(0xFFF59E0B)),
    AppTheme.defaultDark: ('Dark', Color(0xFF7C3AED)),
    AppTheme.light:       ('Light', Color(0xFF94A3B8)),
    AppTheme.crimson:     ('Crimson', Color(0xFFDC2626)),
    AppTheme.roseGold:    ('Rose Gold', Color(0xFFEC4899)),
    AppTheme.neonCyan:    ('Neon Cyan', Color(0xFF06B6D4)),
    AppTheme.oledBlack:   ('OLED Black', Color(0xFF374151)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = themeP.theme.colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppTheme.values.map((t) {
        final (name, color) = _themeData[t]!;
        final isSelected = themeP.currentTheme == t;
        return GestureDetector(
          onTap: () => themeP.setTheme(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : cs.outline.withValues(alpha: 0.15),
                width: isSelected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? color : cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.check_circle_rounded, size: 14, color: color),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends ConsumerState<_ToggleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered ? cs.primary.withValues(alpha: 0.04) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              _Toggle(value: widget.value, onChanged: widget.onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? cs.primary : cs.outline.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── API Key row ───────────────────────────────────────────────────────────────

class _ApiKeyRow extends ConsumerStatefulWidget {
  final String service;
  final String description;
  final IconData icon;
  final bool connected;
  final bool hasKey;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ApiKeyRow({
    required this.service,
    required this.description,
    required this.icon,
    required this.connected,
    required this.hasKey,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  ConsumerState<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends ConsumerState<_ApiKeyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? cs.primary.withValues(alpha: 0.04) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.connected
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : cs.outline.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 17,
                color: widget.connected ? const Color(0xFF16A34A) : cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.service,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      const SizedBox(width: 8),
                      if (widget.connected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Connected',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(widget.description,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (widget.hasKey)
              _SmallButton(
                label: 'Remove',
                onTap: widget.onRemove,
                destructive: true,
              )
            else
              _SmallButton(label: 'Add Key', onTap: widget.onAdd),
          ],
        ),
      ),
    );
  }
}

// ── Reusable small widgets ───────────────────────────────────────────────────

class _SmallButton extends ConsumerStatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SmallButton({required this.label, required this.onTap, this.destructive = false});

  @override
  ConsumerState<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends ConsumerState<_SmallButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    final color = widget.destructive ? cs.error : cs.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _hovered ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends ConsumerStatefulWidget {
  final String label;
  final IconData icon;
  final bool success;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.success, required this.onTap});

  @override
  ConsumerState<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends ConsumerState<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    final color = widget.success ? const Color(0xFF16A34A) : cs.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: _hovered ? Colors.white : color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarBack extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _SidebarBack({required this.onTap});

  @override
  ConsumerState<_SidebarBack> createState() => _SidebarBackState();
}

class _SidebarBackState extends ConsumerState<_SidebarBack> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Tooltip(
      message: 'Back to Library',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hovered ? cs.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: _hovered ? cs.primary : cs.onSurface.withValues(alpha: 0.45),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Validated dialog ──────────────────────────────────────────────────────────

class _DialogFieldData {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  _DialogFieldData({required this.controller, required this.hint, this.obscure = false});
}

class _ValidatedDialog extends ConsumerStatefulWidget {
  final String title;
  final List<_DialogFieldData> fields;
  final Future<bool> Function() validator;
  final VoidCallback onSave;

  const _ValidatedDialog({
    required this.title,
    required this.fields,
    required this.validator,
    required this.onSave,
  });

  @override
  ConsumerState<_ValidatedDialog> createState() => _ValidatedDialogState();
}

class _ValidatedDialogState extends ConsumerState<_ValidatedDialog> {
  bool _validating = false;
  String? _error;

  Future<void> _validateAndSave() async {
    setState(() {
      _validating = true;
      _error = null;
    });

    try {
      final valid = await widget.validator();
      if (!mounted) return;

      if (!valid) {
        setState(() {
          _validating = false;
          _error = 'Invalid credentials. Please check and try again.';
        });
        return;
      }

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _error = 'Validation failed. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 20),
            for (final field in widget.fields) ...[
              _DialogField(controller: field.controller, hint: field.hint, obscure: field.obscure),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(fontSize: 12, color: cs.error)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _validating ? null : () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                ),
                const SizedBox(width: 8),
                _SmallButton(
                  label: _validating ? 'Validating...' : 'Save',
                  onTap: _validating ? () {} : _validateAndSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const _DialogField({required this.controller, required this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: cs.onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 13),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
