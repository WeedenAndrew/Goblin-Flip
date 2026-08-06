part of '../goblin_flip_app.dart';

const _quickBetPresets = <(int, String)>[
  (0, '0'),
  (25, '25'),
  (50, '50'),
  (75, '75'),
  (100, 'All In'),
];

class _WagerOpenButton extends StatelessWidget {
  const _WagerOpenButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const Key('open-wager'),
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xE6A77A34),
        disabledBackgroundColor: const Color(0x9953452D),
        foregroundColor: const Color(0xFF2D1D10),
        disabledForegroundColor: const Color(0xFF9D927D),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: Color(0xFF4B301D), width: 1.5),
        textStyle: _GameFonts.cinzel(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      icon: const Icon(Icons.casino_outlined, size: 17),
      label: const Text('Wager'),
    );
  }
}

class _QuickWagerSidePrompt extends StatelessWidget {
  const _QuickWagerSidePrompt();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('quick-wager-side-prompt'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 42),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF4A4437),
          border: Border.all(color: const Color(0xFF1B1915), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0xD9000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Heads or Tails?',
                style: _GameFonts.cinzelDecorative(
                  color: const Color(0xFFF0D99D),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('quick-wager-heads'),
                      onPressed: () {
                        Navigator.of(context).pop(WagerSide.heads);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF302D25),
                        foregroundColor: const Color(0xFFF0D99D),
                        side: const BorderSide(color: Color(0xFF8C774A)),
                      ),
                      child: const Text('Heads'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('quick-wager-tails'),
                      onPressed: () {
                        Navigator.of(context).pop(WagerSide.tails);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF302D25),
                        foregroundColor: const Color(0xFFF0D99D),
                        side: const BorderSide(color: Color(0xFF8C774A)),
                      ),
                      child: const Text('Tails'),
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
}

class _StoneQuickBetBar extends StatelessWidget {
  const _StoneQuickBetBar({
    required this.selectedPercent,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedPercent;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const skin = _GameVisualSkins.quickBetRail;
    return SizedBox(
      height: skin.height,
      child: _SkinnableSurface(
        artwork: skin.artwork,
        proceduralPainter: const _StoneFoundationPainter(),
        child: CustomPaint(
          painter: _StoneSelectionPainter(
            selectedPercent: selectedPercent,
            enabled: enabled,
            faceTop: skin.selectionTop,
          ),
          child: Row(
            children: [
              for (var index = 0; index < _quickBetPresets.length; index++)
                Expanded(
                  child: _StoneQuickBetButton(
                    key: Key('quick-bet-${_quickBetPresets[index].$1}'),
                    percent: _quickBetPresets[index].$1,
                    label: _quickBetPresets[index].$2,
                    selected: selectedPercent == _quickBetPresets[index].$1,
                    enabled: enabled,
                    onPressed: () => onSelected(_quickBetPresets[index].$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoneQuickBetButton extends StatelessWidget {
  const _StoneQuickBetButton({
    super.key,
    required this.percent,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final int percent;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const skin = _GameVisualSkins.quickBetRail;
    final semanticLabel = percent == 0
        ? 'Clear quick wager'
        : percent == 100
        ? 'All-in quick wager'
        : '$percent percent quick wager';
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: skin.labelPadding,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: _GameFonts.cinzel(
                      color: selected
                          ? skin.selectedLabelColor
                          : skin.labelColor,
                      fontSize: percent == 100
                          ? skin.allInFontSize
                          : skin.labelFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: percent == 100 ? 0 : 0.6,
                      shadows: const [
                        Shadow(
                          color: Color(0xE6000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoneFoundationPainter extends CustomPainter {
  const _StoneFoundationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const faceTop = 14.0;
    final faceRect = Rect.fromLTWH(
      0,
      faceTop,
      size.width,
      size.height - faceTop,
    );
    final topFace = Path()
      ..moveTo(0, 1)
      ..lineTo(size.width, 1)
      ..lineTo(size.width, faceTop)
      ..lineTo(0, faceTop)
      ..close();

    canvas.drawShadow(
      Path()..addRect(faceRect),
      const Color(0xE6000000),
      5,
      false,
    );
    canvas.drawPath(
      topFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF756F5D), Color(0xFF4C483C), Color(0xFF343129)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, faceTop)),
    );
    canvas.drawRect(
      faceRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A5548), Color(0xFF3B3830), Color(0xFF24221D)],
          stops: [0, 0.52, 1],
        ).createShader(faceRect),
    );

    final segmentWidth = size.width / 5;
    final seamShadow = Paint()
      ..color = const Color(0xFF171611)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final seamHighlight = Paint()
      ..color = const Color(0x405F5A4C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 1; index < 5; index++) {
      final x = segmentWidth * index;
      canvas.drawLine(Offset(x, faceTop), Offset(x, size.height), seamShadow);
      canvas.drawLine(
        Offset(x + 1.5, faceTop + 1),
        Offset(x + 1.5, size.height),
        seamHighlight,
      );
      canvas.drawLine(Offset(x, 1), Offset(x, faceTop), seamShadow);
    }

    final pockmark = Paint()..color = const Color(0x4D171611);
    final pockHighlight = Paint()..color = const Color(0x246F6959);
    final textureWidth = math.max(12, size.width.toInt() - 22);
    final textureHeight = math.max(10, (size.height - faceTop - 17).toInt());
    for (var index = 0; index < 12; index++) {
      final x = (11 + ((index * 67) % textureWidth)).toDouble();
      final y = faceTop + 8 + ((index * 19) % textureHeight);
      final radius = index.isEven ? 1.6 : 1.1;
      canvas.drawCircle(Offset(x, y), radius, pockmark);
      canvas.drawCircle(Offset(x + 0.8, y + 0.7), radius * 0.45, pockHighlight);
    }

    final chisel = Paint()
      ..color = const Color(0x4F1B1915)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 5; index++) {
      final segmentLeft = segmentWidth * index;
      final y = faceTop + 9 + ((index * 7) % 20);
      canvas.drawLine(
        Offset(segmentLeft + segmentWidth * 0.18, y),
        Offset(segmentLeft + segmentWidth * 0.38, y + 1.5),
        chisel,
      );
    }

    canvas.drawLine(
      const Offset(0, faceTop),
      Offset(size.width, faceTop),
      Paint()
        ..color = const Color(0xFF171611)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(0, faceTop + 2),
      Offset(size.width, faceTop + 2),
      Paint()
        ..color = const Color(0x456F6959)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(0, size.height - 3),
      Offset(size.width, size.height - 3),
      Paint()
        ..color = const Color(0xFF12110E)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(2, 2),
      Offset(size.width - 2, 2),
      Paint()
        ..color = const Color(0x4FA49B7F)
        ..strokeWidth = 1,
    );

    final crack = Paint()
      ..color = const Color(0xA51B1915)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, faceTop + 4)
        ..lineTo(size.width * 0.15, faceTop + 10)
        ..lineTo(size.width * 0.14, faceTop + 16),
      crack,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, size.height - 3)
        ..lineTo(size.width * 0.69, size.height - 10)
        ..lineTo(size.width * 0.71, size.height - 15),
      crack,
    );

    final frame = Paint()
      ..color = const Color(0xFF14130F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, frame);
  }

  @override
  bool shouldRepaint(covariant _StoneFoundationPainter oldDelegate) => false;
}

/// Interaction state stays code-driven even when the foundation is replaced
/// by replacement artwork, so selected wagers never need to be baked into PNGs.
class _StoneSelectionPainter extends CustomPainter {
  const _StoneSelectionPainter({
    required this.selectedPercent,
    required this.enabled,
    required this.faceTop,
  });

  final int selectedPercent;
  final bool enabled;
  final double faceTop;

  @override
  void paint(Canvas canvas, Size size) {
    final selectedIndex = switch (selectedPercent) {
      0 => 0,
      25 => 1,
      50 => 2,
      75 => 3,
      100 => 4,
      _ => -1,
    };
    if (selectedIndex < 0) return;

    final segmentWidth = size.width / _quickBetPresets.length;
    final selectedRect = Rect.fromLTWH(
      segmentWidth * selectedIndex,
      faceTop,
      segmentWidth,
      size.height - faceTop,
    );
    final opacityScale = enabled ? 1.0 : 0.48;
    canvas.drawRect(
      selectedRect,
      Paint()
        ..color = const Color(
          0x30C8A55B,
        ).withValues(alpha: 0.19 * opacityScale),
    );
    canvas.drawRect(
      Rect.fromLTWH(segmentWidth * selectedIndex, 0, segmentWidth, faceTop),
      Paint()
        ..color = const Color(
          0x28D1A957,
        ).withValues(alpha: 0.16 * opacityScale),
    );
    canvas.drawRect(
      selectedRect.deflate(1),
      Paint()
        ..color = const Color(0xFFD1A957).withValues(alpha: opacityScale)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StoneSelectionPainter oldDelegate) {
    return oldDelegate.selectedPercent != selectedPercent ||
        oldDelegate.enabled != enabled ||
        oldDelegate.faceTop != faceTop;
  }
}
