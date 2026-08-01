import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import '../providers/settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/game_library_provider.dart';
import '../services/autostart_service.dart';
import '../services/drive_service.dart';
import '../widgets/focus_effect_wrapper.dart';
import 'package:file_picker/file_picker.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _currentStep = 0;
  String _gamesPath = '';
  String _savesPath = '';

  final _steamGridDbController = TextEditingController();
  final _igdbClientController = TextEditingController();
  final _igdbSecretController = TextEditingController();
  final _screenScraperUserController = TextEditingController();
  final _screenScraperPassController = TextEditingController();
  final _autostartService = AutostartService();

  @override
  void initState() {
    super.initState();
    // Default paths use ~/ notation — portable across PCs and mount points
    _gamesPath = '~/Games';
    _savesPath = '~/Saves';
    print('[SetupWizard] Default games: $_gamesPath');
    print('[SetupWizard] Default saves: $_savesPath');
  }

  @override
  void dispose() {
    _steamGridDbController.dispose();
    _igdbClientController.dispose();
    _igdbSecretController.dispose();
    _screenScraperUserController.dispose();
    _screenScraperPassController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder(String field) async {
    final result = await FilePicker.getDirectoryPath(dialogTitle: 'Select $field directory');
    if (result != null && mounted) {
      // Convert picked absolute path to ~/ notation for portability
      final portable = DriveService.toPortable(result);
      setState(() {
        if (field == 'Games') _gamesPath = portable;
        if (field == 'Saves') _savesPath = portable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.gamepad_rounded, size: 40, color: theme.colorScheme.primary)),
              const SizedBox(height: 24),
              Text('Satchel Setup', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(_getStepSubtitle(), style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
              const SizedBox(height: 48),
              Expanded(child: _buildCurrentStep()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0) FocusEffectWrapper(onTap: () => setState(() => _currentStep--), child: Padding(padding: const EdgeInsets.all(12), child: Text('Back', style: TextStyle(color: theme.colorScheme.primary)))) else const SizedBox(),
                  FocusEffectWrapper(
                    onTap: _nextStep,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)), child: Text(_currentStep == 3 ? 'Start' : 'Next', style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0: return 'Configure your directories';
      case 1: return 'Set up image scraping APIs';
      case 2: return 'AutoStart for your drive';
      case 3: return 'Ready to go!';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildPathsStep();
      case 1: return _buildApiKeysStep();
      case 2: return _buildAutostartStep();
      case 3: return _buildReviewStep();
      default: return const SizedBox();
    }
  }

  Widget _buildPathsStep() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pathPicker('Games Directory', _gamesPath, () => _pickFolder('Games')),
        const SizedBox(height: 16),
        _pathPicker('Saves Directory', _savesPath, () => _pickFolder('Saves')),
        const SizedBox(height: 24),
        Text('Browse to select where your game folders and save backups live.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }

  Widget _pathPicker(String label, String path, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.folder, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)), const SizedBox(height: 4), Text(path, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontFamily: 'monospace'))])),
          FocusEffectWrapper(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: Text('Browse', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500)))),
        ],
      ),
    );
  }

  Widget _buildApiKeysStep() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _apiKeySection('SteamGridDB', 'Grid art and covers (Free)', [_apiKeyInput(_steamGridDbController, 'API Key', true)]),
          const SizedBox(height: 16),
          _apiKeySection('IGDB', 'Game info and metadata (Free via Twitch)', [_apiKeyInput(_igdbClientController, 'Client ID', false), const SizedBox(height: 8), _apiKeyInput(_igdbSecretController, 'Client Secret', true)]),
          const SizedBox(height: 16),
          _apiKeySection('ScreenScraper', 'Box art and screenshots (Free tier)', [_apiKeyInput(_screenScraperUserController, 'Username', false), const SizedBox(height: 8), _apiKeyInput(_screenScraperPassController, 'Password', true)]),
          const SizedBox(height: 24),
          Text('All keys are stored encrypted on your drive.\nYou can skip this and add later in Settings.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _apiKeySection(String title, String subtitle, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)), const SizedBox(height: 12), ...children]));
  }

  Widget _apiKeyInput(TextEditingController ctrl, String hint, bool obscure) {
    final theme = Theme.of(context);
    return TextField(controller: ctrl, obscureText: obscure, style: TextStyle(color: theme.colorScheme.onSurface), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)), filled: true, fillColor: theme.scaffoldBackgroundColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)));
  }

  Widget _buildAutostartStep() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.usb, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Portable AutoStart', style: TextStyle(fontSize: 20, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Text('Generate AutoRun.inf so this app auto-launches\nwhen the drive is plugged into a Windows PC.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
        const SizedBox(height: 24),
        FocusEffectWrapper(
          onTap: () async {
            final exePath = p.join(DriveService.appDir, 'satchel.exe');
            await _autostartService.generateAutoRunInf(DriveService.appDir, exePath);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AutoRun.inf created!'), backgroundColor: Colors.green));
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)), child: const Text('Generate AutoRun.inf', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Setup Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 24),
        _reviewItem('Games', _gamesPath),
        const SizedBox(height: 8),
        _reviewItem('Saves', _savesPath),
        const SizedBox(height: 8),
        _reviewItem('APIs', '${_getEnabledApisCount()} configured'),
      ],
    );
  }

  Widget _reviewItem(String label, String value) {
    final theme = Theme.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(8)), child: Row(children: [Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))), const Spacer(), Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 13))]));
  }

  int _getEnabledApisCount() {
    int c = 0;
    if (_steamGridDbController.text.isNotEmpty) c++;
    if (_igdbClientController.text.isNotEmpty) c++;
    if (_screenScraperUserController.text.isNotEmpty) c++;
    return c;
  }

  void _nextStep() {
    if (_currentStep == 3) { _completeSetup(); return; }
    setState(() => _currentStep++);
  }

  Future<void> _completeSetup() async {
    print('[SetupWizard] Completing setup...');
    print('[SetupWizard] Games: $_gamesPath');
    print('[SetupWizard] Saves: $_savesPath');

    if (_steamGridDbController.text.isNotEmpty) {
      await ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(_steamGridDbController.text);
    }
    if (_igdbClientController.text.isNotEmpty) {
      await ref.read(apiConfigProvider.notifier).updateIgdbCredentials(_igdbClientController.text, _igdbSecretController.text);
    }
    if (_screenScraperUserController.text.isNotEmpty) {
      await ref.read(apiConfigProvider.notifier).updateScreenScraperCredentials(_screenScraperUserController.text, _screenScraperPassController.text);
    }

    await ref.read(settingsProvider.notifier).updateSettings(
      ref.read(settingsProvider).copyWith(gamesPath: _gamesPath, savesPath: _savesPath, autoStartEnabled: true, autoScanOnStartup: true),
    );

    final settingsBox = Hive.box('settings');
    await settingsBox.put('setupDone', true);
    print('[SetupWizard] setupDone = true');

    final exePath = p.join(DriveService.appDir, 'satchel.exe');
    await _autostartService.generateAutoRunInf(DriveService.appDir, exePath);

    await ref.read(gameLibraryProvider.notifier).rescan();

    if (mounted) Navigator.of(context).pushReplacementNamed('/library');
  }
}
