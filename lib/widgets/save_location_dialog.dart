import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/settings_provider.dart';
import '../services/omnisave_service.dart';
import '../services/pcgamingwiki_service.dart';

/// Standalone dialog for editing a game's save location.
/// Use via: showDialog(builder: (_) => SaveLocationDialog(game: game))
///
/// Internally stores paths in OmniSave portable form (~/AppData/Roaming/...)
/// but displays them expanded to absolute paths for readability.
class SaveLocationDialog extends ConsumerStatefulWidget {
  final Game game;

  const SaveLocationDialog({super.key, required this.game});

  @override
  ConsumerState<SaveLocationDialog> createState() => _SaveLocationDialogState();
}

class _SaveLocationDialogState extends ConsumerState<SaveLocationDialog> {
  final PcgamingwikiService _pcgamingwiki = PcgamingwikiService();

  // The controller shows the DISPLAY (absolute) path.
  // _portablePath stores the ~/... form that gets written to omnisave.ini.
  final TextEditingController _displayController = TextEditingController();
  String _portablePath = '';

  bool _saveDetecting = false;
  bool _skipSaveSync = false;
  bool _savesArePortable = false;
  String _savePathSource = '';

  @override
  void initState() {
    super.initState();
    _prefillFromIni();
  }

  Future<void> _prefillFromIni() async {
    // Check meta.json for skipSaveSync flag
    final metaFile = File(p.join(widget.game.folderPath, '.indie', 'meta.json'));
    if (await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        if (meta['skipSaveSync'] == true && mounted) {
          setState(() {
            _skipSaveSync = true;
            _savePathSource = 'Save sync disabled';
          });
          return;
        }
      } catch (_) {}
    }

    // Pre-fill path from existing ini
    final iniFile = File(p.join(widget.game.folderPath, '.indie', 'omnisave.ini'));
    if (await iniFile.exists()) {
      final lines = await iniFile.readAsLines();
      for (final line in lines) {
        if (line.startsWith('Local_Path=')) {
          final stored = line.substring('Local_Path='.length).trim();
          if (mounted) {
            setState(() {
              _portablePath = stored;
              _displayController.text = stored; // show ~/... form
              _savePathSource = 'Current configured path';
            });
          }
          break;
        }
      }
    }
  }

  Future<void> _detect() async {
    setState(() {
      _saveDetecting = true;
      _savePathSource = 'Searching PCGamingWiki...';
    });
    try {
      final paths = await _pcgamingwiki.getSavePaths(
        widget.game.name,
        gameFolderPath: widget.game.folderPath,
      );
      if (!mounted) return;
      if (paths.isNotEmpty) {
        final portable = paths.first; // already in ~/... form
        final isPortable = portable.startsWith('./');
        setState(() {
          _portablePath = portable;
          _displayController.text = portable; // show ~/... form directly
          _savePathSource = 'Detected via PCGamingWiki';
          _skipSaveSync = isPortable;
          _savesArePortable = isPortable;
          _saveDetecting = false;
        });
      } else {
        setState(() {
          _savePathSource = 'Not found on PCGamingWiki';
          _saveDetecting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savePathSource = 'Detection failed';
          _saveDetecting = false;
        });
      }
    }
  }

  /// Converts an absolute path picked via Browse back to portable ~/... form.
  String _toPortable(String absolutePath) {
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isNotEmpty &&
        absolutePath.toLowerCase().startsWith(userProfile.toLowerCase())) {
      final rel = absolutePath.substring(userProfile.length).replaceAll('\\', '/');
      return '~$rel'; // e.g. ~/AppData/Roaming/SomeGame
    }
    // Not under userprofile — store as-is with forward slashes
    return absolutePath.replaceAll('\\', '/');
  }

  Future<void> _browse() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null && mounted) {
      setState(() {
        _portablePath = _toPortable(dir);
        _displayController.text = dir; // show the real path the user picked
      });
    }
  }

  Future<void> _save(BuildContext ctx) async {
    if (_skipSaveSync) {
      // Remove any existing omnisave.ini so the game launches directly
      for (final path in [
        p.join(widget.game.folderPath, 'OmniSave.ini'),
        p.join(widget.game.folderPath, '.indie', 'omnisave.ini'),
      ]) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      await _saveMetaJson({'omnisaveConfigured': true, 'skipSaveSync': true});
    } else {
      final pathToWrite = _portablePath.isNotEmpty
          ? _portablePath
          : _toPortable(_displayController.text.trim());
      if (pathToWrite.isNotEmpty) {
        final settings = ref.read(settingsProvider);
        final omniSave = OmniSaveService(savesBasePath: settings.savesPath);
        await omniSave.generateConfig(widget.game, localSavePath: pathToWrite);
      }
      await _saveMetaJson({'omnisaveConfigured': true, 'skipSaveSync': false});
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  Future<void> _saveMetaJson(Map<String, dynamic> data) async {
    try {
      final indieDir = Directory(p.join(widget.game.folderPath, '.indie'));
      if (!await indieDir.exists()) await indieDir.create(recursive: true);
      final metaFile = File(p.join(indieDir.path, 'meta.json'));
      Map<String, dynamic> existing = {};
      if (await metaFile.exists()) {
        try {
          existing = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      existing.addAll(data);
      await metaFile.writeAsString(jsonEncode(existing));
    } catch (e) {
      print('[SaveLocationDialog] Failed to write meta.json: $e');
    }
  }

  @override
  void dispose() {
    _displayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Save Location — ${widget.game.name}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Save Location', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _saveDetecting ? null : _detect,
                  icon: _saveDetecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 14),
                  label: const Text('Detect'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            if (_savePathSource.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _savePathSource,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
              ),
            ],

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _displayController,
                    enabled: !_skipSaveSync,
                    onChanged: (val) {
                      // User typed manually — convert to portable on the fly
                      _portablePath = _toPortable(val);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Path to save folder',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _skipSaveSync ? null : _browse,
                  child: const Text('Browse...'),
                ),
              ],
            ),

            if (_savesArePortable) ...[
              const SizedBox(height: 8),
              Text(
                'Saves are inside the game folder — already portable, no sync needed.',
                style: TextStyle(fontSize: 12, color: Colors.green[700]),
              ),
            ],

            const SizedBox(height: 4),
            CheckboxListTile(
              value: _skipSaveSync,
              onChanged: (val) => setState(() => _skipSaveSync = val ?? false),
              title: const Text(
                'Skip save sync (saves are portable / not needed)',
                style: TextStyle(fontSize: 13),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _save(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
