import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../providers/settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/game_library_provider.dart';
import '../services/autostart_service.dart';


class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isDetecting = false;
  String? _detectedDrive;
  String? _gamesPath;
  String? _savesPath;

  // API Controllers
  final _steamGridDbController = TextEditingController();
  final _igdbClientController = TextEditingController();
  final _igdbSecretController = TextEditingController();
  final _screenScraperUserController = TextEditingController();
  final _screenScraperPassController = TextEditingController();

  final _autostartService = AutostartService();

  @override
  void initState() {
    super.initState();
    _detectDrive();
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

  Future<void> _detectDrive() async {
    setState(() => _isDetecting = true);

    // Check common drive letters for Indie Lib
    final drives = ['H:', 'I:', 'J:', 'K:', 'G:', 'F:', 'E:'];

    for (final drive in drives) {
      final indieMarker = File(p.join(drive, 'OmniSave.exe'));
      if (await indieMarker.exists()) {
        setState(() {
          _detectedDrive = drive;
          _gamesPath = p.join(drive, 'Games');
          _savesPath = p.join(drive, 'Saves');
          _isDetecting = false;
        });
        return;
      }
    }

    setState(() {
      _detectedDrive = null;
      _isDetecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.gamepad_rounded,
                  size: 40,
                  color: Color(0xFFe94560),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Project Indie Setup',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getStepSubtitle(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),

              // Step content
              Expanded(
                child: _buildCurrentStep(),
              ),

              // Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton(
                    onPressed: _isDetecting ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94560),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      _currentStep == 3 ? 'Complete Setup' : 'Next',
                      style: const TextStyle(color: Colors.white),
                    ),
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
      case 0:
        return 'Detecting your drive...';
      case 1:
        return 'Configure your game library';
      case 2:
        return 'Set up image scraping APIs';
      case 3:
        return 'Review and complete';
      default:
        return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildDriveDetectionStep();
      case 1:
        return _buildPathsStep();
      case 2:
        return _buildApiKeysStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDriveDetectionStep() {
    if (_isDetecting) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFe94560)),
          ),
          SizedBox(height: 16),
          Text(
            'Scanning drives for Indie Lib...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (_detectedDrive != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Drive Found!',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16213e),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _detectedDrive!,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFe94560),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.usb_off,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No drive detected',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please insert your Indie Lib drive\nand click Detect Drive',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _detectDrive,
          child: const Text('Detect Drive'),
        ),
      ],
    );
  }

  Widget _buildPathsStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pathField(
          label: 'Games Location',
          value: _gamesPath ?? '',
          icon: Icons.folder,
          onChanged: (v) => setState(() => _gamesPath = v),
        ),
        const SizedBox(height: 16),
        _pathField(
          label: 'Saves Backup Location',
          value: _savesPath ?? '',
          icon: Icons.save,
          onChanged: (v) => setState(() => _savesPath = v),
        ),
        const SizedBox(height: 24),
        Text(
          'These paths are where your games and save backups will be stored.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _pathField({
    required String label,
    required String value,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFe94560)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysStep() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _apiKeySection(
            title: 'SteamGridDB',
            subtitle: 'For grid art and covers (Free)',
            children: [
              _apiKeyInput(
                controller: _steamGridDbController,
                hint: 'API Key',
                isObscured: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _apiKeySection(
            title: 'IGDB',
            subtitle: 'For game info and metadata (Free via Twitch)',
            children: [
              _apiKeyInput(
                controller: _igdbClientController,
                hint: 'Client ID',
              ),
              const SizedBox(height: 8),
              _apiKeyInput(
                controller: _igdbSecretController,
                hint: 'Client Secret',
                isObscured: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _apiKeySection(
            title: 'ScreenScraper',
            subtitle: 'For box art and screenshots (Free tier)',
            children: [
              _apiKeyInput(
                controller: _screenScraperUserController,
                hint: 'Username',
              ),
              const SizedBox(height: 8),
              _apiKeyInput(
                controller: _screenScraperPassController,
                hint: 'Password',
                isObscured: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'All keys are stored encrypted on your drive.\nYou can skip this and add them later in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _apiKeySection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _apiKeyInput({
    required TextEditingController controller,
    required String hint,
    bool isObscured = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: const Color(0xFF0f0f23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFe94560)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Color(0xFFe94560),
        ),
        const SizedBox(height: 16),
        const Text(
          'Setup Complete!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _reviewItem('Drive', _detectedDrive ?? 'Not set'),
        const SizedBox(height: 8),
        _reviewItem('Games', _gamesPath ?? 'Not set'),
        const SizedBox(height: 8),
        _reviewItem('Saves', _savesPath ?? 'Not set'),
        const SizedBox(height: 8),
        _reviewItem(
          'APIs',
          '${_getEnabledApisCount()} configured',
        ),
        const SizedBox(height: 32),
        Text(
          'You can change these anytime in Settings.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _reviewItem(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _getEnabledApisCount() {
    int count = 0;
    if (_steamGridDbController.text.isNotEmpty) count++;
    if (_igdbClientController.text.isNotEmpty) count++;
    if (_screenScraperUserController.text.isNotEmpty) count++;
    return count;
  }

  void _nextStep() {
    if (_currentStep == 3) {
      _completeSetup();
      return;
    }

    setState(() => _currentStep++);
  }

  Future<void> _completeSetup() async {
    // Save API keys
    if (_steamGridDbController.text.isNotEmpty) {
      ref.read(apiConfigProvider.notifier).updateSteamGridDbKey(
            _steamGridDbController.text,
          );
    }

    if (_igdbClientController.text.isNotEmpty) {
      ref.read(apiConfigProvider.notifier).updateIgdbCredentials(
            _igdbClientController.text,
            _igdbSecretController.text,
          );
    }

    if (_screenScraperUserController.text.isNotEmpty) {
      ref.read(apiConfigProvider.notifier).updateScreenScraperCredentials(
            _screenScraperUserController.text,
            _screenScraperPassController.text,
          );
    }

    // Save settings
    ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                gamesPath: _gamesPath,
                savesPath: _savesPath,
                autoStartEnabled: true,
                autoScanOnStartup: true,
              ),
        );

    // Generate AutoRun.inf
    if (_detectedDrive != null) {
      await _autostartService.generateAutoRunInf(
        _detectedDrive!,
        p.join(_detectedDrive!, 'ProjectIndie', 'indie_launcher.exe'),
      );
    }

    // Scan games
    await ref.read(gameLibraryProvider.notifier).rescan();

    // Navigate to library
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/library');
    }
  }
}
