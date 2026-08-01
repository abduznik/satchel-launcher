import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen screenshot lightbox with left/right arrows and keyboard nav.
/// Push this as a route or call [ScreenshotViewer.show].
class ScreenshotViewer extends StatefulWidget {
  final List<String> paths; // local file paths
  final int initialIndex;

  const ScreenshotViewer({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> paths,
    int initialIndex = 0,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      pageBuilder: (ctx, _, __) => ScreenshotViewer(
        paths: paths,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<ScreenshotViewer> {
  late int _index;
  late final FocusNode _focusNode;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _focusNode = FocusNode();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.paths.length) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.paths.length;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) _goTo(_index + 1);
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) _goTo(_index - 1);
        if (e.logicalKey == LogicalKeyboardKey.escape) Navigator.of(context).pop();
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // --- Image pager ---
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (ctx, i) {
                return GestureDetector(
                  // Tap background to close
                  onTap: () => Navigator.of(context).pop(),
                  child: Center(
                    child: GestureDetector(
                      // Absorb tap on image so it doesn't close
                      onTap: () {},
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: Image.file(
                          File(widget.paths[i]),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 80,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // --- Close button ---
            Positioned(
              top: 16,
              right: 16,
              child: _CircleButton(
                icon: Icons.close,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            // --- Counter ---
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / $total',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

            // --- Left arrow ---
            if (_index > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CircleButton(
                    icon: Icons.chevron_left_rounded,
                    size: 36,
                    onTap: () => _goTo(_index - 1),
                  ),
                ),
              ),

            // --- Right arrow ---
            if (_index < total - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CircleButton(
                    icon: Icons.chevron_right_rounded,
                    size: 36,
                    onTap: () => _goTo(_index + 1),
                  ),
                ),
              ),

            // --- Thumbnail strip ---
            if (total > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (i) {
                        final selected = i == _index;
                        return GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Opacity(
                                opacity: selected ? 1.0 : 0.5,
                                child: Image.file(
                                  File(widget.paths[i]),
                                  width: 64,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 64,
                                    height: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
