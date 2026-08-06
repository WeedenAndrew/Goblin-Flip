part of '../goblin_flip_app.dart';

class _PowerupMenuButton extends StatelessWidget {
  const _PowerupMenuButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Open wizard power-ups',
      child: Tooltip(
        message: 'Wizard power-ups',
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              key: const Key('open-powerups'),
              onTap: enabled ? onPressed : null,
              radius: 36,
              customBorder: const CircleBorder(),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF24190F),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xB8000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/wizard_powerups.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
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

enum _OpenScrollStyle { wizard, wager }

class _OpenScrollPanel extends StatelessWidget {
  const _OpenScrollPanel({super.key, required this.style, required this.child});

  final _OpenScrollStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = _GameVisualSkins.openScroll(style);
    return _SkinnableSurface(
      artwork: skin.artwork,
      proceduralPainter: _OpenScrollPainter(style: style),
      child: Padding(padding: skin.contentPadding, child: child),
    );
  }
}

class _OpenScrollPainter extends CustomPainter {
  const _OpenScrollPainter({required this.style});

  final _OpenScrollStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final isWizard = style == _OpenScrollStyle.wizard;
    const edge = 17.0;
    const rollHeight = 36.0;
    final bodyRect = Rect.fromLTRB(
      edge,
      rollHeight * 0.56,
      size.width - edge,
      size.height - rollHeight * 0.56,
    );
    final bodyPath = Path()
      ..moveTo(bodyRect.left + 4, bodyRect.top)
      ..quadraticBezierTo(
        size.width * 0.28,
        bodyRect.top - (isWizard ? 2.2 : 1.1),
        size.width * 0.51,
        bodyRect.top + 1.2,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        bodyRect.top + (isWizard ? 2.4 : 1.2),
        bodyRect.right - 4,
        bodyRect.top,
      )
      ..lineTo(bodyRect.right, size.height * 0.31)
      ..lineTo(bodyRect.right - (isWizard ? 6 : 10), size.height * 0.34)
      ..lineTo(bodyRect.right, size.height * 0.38)
      ..lineTo(bodyRect.right - 1, bodyRect.bottom - 4)
      ..quadraticBezierTo(
        size.width * 0.73,
        bodyRect.bottom + (isWizard ? 2.2 : 1),
        size.width * 0.49,
        bodyRect.bottom - 1,
      )
      ..quadraticBezierTo(
        size.width * 0.24,
        bodyRect.bottom - (isWizard ? 2 : 0.8),
        bodyRect.left + 3,
        bodyRect.bottom,
      )
      ..lineTo(bodyRect.left, size.height * 0.72)
      ..lineTo(bodyRect.left + (isWizard ? 6 : 9), size.height * 0.68)
      ..lineTo(bodyRect.left, size.height * 0.64)
      ..lineTo(bodyRect.left + 1, bodyRect.top + 4)
      ..close();

    Path rollPath(Rect rect) {
      final wave = isWizard ? 2.2 : 1.4;
      return Path()
        ..moveTo(rect.left + 12, rect.top + 2)
        ..quadraticBezierTo(
          rect.center.dx,
          rect.top - wave,
          rect.right - 12,
          rect.top + 2,
        )
        ..quadraticBezierTo(
          rect.right + 1,
          rect.center.dy,
          rect.right - 12,
          rect.bottom - 2,
        )
        ..quadraticBezierTo(
          rect.center.dx,
          rect.bottom + wave,
          rect.left + 12,
          rect.bottom - 2,
        )
        ..quadraticBezierTo(
          rect.left - 1,
          rect.center.dy,
          rect.left + 12,
          rect.top + 2,
        )
        ..close();
    }

    canvas.drawShadow(bodyPath, const Color(0xE6000000), 16, false);
    final bodyColors = isWizard
        ? const [
            Color(0xFFB8AF88),
            Color(0xFFCFC39A),
            Color(0xFFA39767),
            Color(0xFF625D40),
          ]
        : const [
            Color(0xFFC39E67),
            Color(0xFFD5B47B),
            Color(0xFFA86F3C),
            Color(0xFF643B20),
          ];
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bodyColors,
          stops: [0, 0.28, 0.76, 1],
        ).createShader(bodyRect),
    );

    final grainPaint = Paint()
      ..color = isWizard ? const Color(0x28545B52) : const Color(0x315C3A21);
    final grainWidth = bodyRect.width - 30;
    final grainHeight = bodyRect.height - 40;
    for (var fleck = 0; fleck < 32; fleck++) {
      final x = bodyRect.left + 15 + (((fleck * 47) % 101) / 101) * grainWidth;
      final y = bodyRect.top + 20 + (((fleck * 73) % 103) / 103) * grainHeight;
      canvas.drawCircle(Offset(x, y), 0.55 + (fleck % 3) * 0.32, grainPaint);
    }
    final wearPaint = Paint()
      ..color = isWizard ? const Color(0x16505E5D) : const Color(0x1C774B25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (final patch in [
      Offset(bodyRect.left + bodyRect.width * 0.22, bodyRect.top + 62),
      Offset(bodyRect.right - bodyRect.width * 0.19, bodyRect.bottom - 78),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: patch, width: 46, height: 22),
        wearPaint,
      );
    }

    final bodyEdgePaint = Paint()
      ..color = isWizard ? const Color(0xFF4B4532) : const Color(0xFF54341E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1;
    canvas.drawPath(bodyPath, bodyEdgePaint);

    final topRollRect = Rect.fromLTRB(8, 3, size.width - 8, rollHeight + 3);
    final bottomRollRect = Rect.fromLTRB(
      8,
      size.height - rollHeight - 3,
      size.width - 8,
      size.height - 3,
    );
    final topRollPath = rollPath(topRollRect);
    final bottomRollPath = rollPath(bottomRollRect);
    final rollShadowPaint = Paint()
      ..color = const Color(0x8F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(topRollPath, rollShadowPaint);
    canvas.drawPath(bottomRollPath, rollShadowPaint);
    canvas.restore();

    final rodPaint = Paint()
      ..shader = LinearGradient(
        colors: isWizard
            ? const [Color(0xFF181C1C), Color(0xFF53615A), Color(0xFF1C201E)]
            : const [Color(0xFF21140C), Color(0xFF784821), Color(0xFF2B190E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final y in [
      rollHeight * 0.56 + 3,
      size.height - rollHeight * 0.56 - 3,
    ]) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), rodPaint);
    }

    final rollColors = isWizard
        ? const [
            Color(0xFF464638),
            Color(0xFF8A825F),
            Color(0xFFB5AA81),
            Color(0xFFC9BE98),
            Color(0xFF504B35),
          ]
        : const [
            Color(0xFF543019),
            Color(0xFF8B582B),
            Color(0xFFB78348),
            Color(0xFFCDAA6B),
            Color(0xFF58311A),
          ];
    final rollGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: rollColors,
      stops: const [0, 0.18, 0.48, 0.7, 1],
    );
    canvas.drawPath(
      topRollPath,
      Paint()..shader = rollGradient.createShader(topRollRect),
    );
    canvas.drawPath(
      bottomRollPath,
      Paint()..shader = rollGradient.createShader(bottomRollRect),
    );

    final creasePaint = Paint()
      ..color = isWizard ? const Color(0x704D5148) : const Color(0x805C371D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final topCrease = Path()
      ..moveTo(38, topRollRect.top + 9)
      ..quadraticBezierTo(
        size.width * 0.5,
        topRollRect.top + (isWizard ? 6 : 8),
        size.width - 38,
        topRollRect.top + 9,
      );
    final bottomCrease = Path()
      ..moveTo(38, bottomRollRect.bottom - 9)
      ..quadraticBezierTo(
        size.width * 0.5,
        bottomRollRect.bottom - (isWizard ? 6 : 8),
        size.width - 38,
        bottomRollRect.bottom - 9,
      );
    canvas.drawPath(topCrease, creasePaint);
    canvas.drawPath(bottomCrease, creasePaint);

    final vinePaint = Paint()
      ..color = isWizard ? const Color(0xA8436871) : const Color(0xB23F5B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final leftVine = Path()
      ..moveTo(bodyRect.left + 8, bodyRect.bottom - 17)
      ..cubicTo(
        bodyRect.left + 25,
        bodyRect.bottom - 31,
        bodyRect.left + 16,
        bodyRect.bottom - 48,
        bodyRect.left + 35,
        bodyRect.bottom - 57,
      );
    canvas.drawPath(leftVine, vinePaint);
    final leafPaint = Paint()
      ..color = isWizard ? const Color(0x994A7480) : const Color(0xA84E6B31);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyRect.left + 21, bodyRect.bottom - 35),
        width: 12,
        height: 6,
      ),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyRect.left + 32, bodyRect.bottom - 51),
        width: 11,
        height: 6,
      ),
      leafPaint,
    );

    final sealCenter = Offset(bodyRect.right - 20, bodyRect.bottom - 24);
    canvas.drawCircle(
      sealCenter.translate(0, 2),
      11,
      Paint()..color = const Color(0x72000000),
    );
    canvas.drawCircle(
      sealCenter,
      10,
      Paint()
        ..color = isWizard ? const Color(0xFF496D7A) : const Color(0xFF5A3B22),
    );
    final sealMarkPaint = Paint()
      ..color = isWizard ? const Color(0xFFD3E2D9) : const Color(0xFFE2BA72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    if (isWizard) {
      canvas.drawLine(
        sealCenter.translate(0, -5),
        sealCenter.translate(0, 5),
        sealMarkPaint,
      );
      canvas.drawLine(
        sealCenter.translate(-5, 0),
        sealCenter.translate(5, 0),
        sealMarkPaint,
      );
      canvas.drawLine(
        sealCenter.translate(-3.5, -3.5),
        sealCenter.translate(3.5, 3.5),
        sealMarkPaint,
      );
    } else {
      for (var slash = -1; slash <= 1; slash++) {
        final slashOffset = (slash * 3).toDouble();
        canvas.drawLine(
          sealCenter.translate(-4 + slashOffset, -4),
          sealCenter.translate(-1 + slashOffset, 4),
          sealMarkPaint,
        );
      }
    }

    final tearShade = Paint()
      ..color = isWizard ? const Color(0x70494B3A) : const Color(0x80513420)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(bodyRect.right - (isWizard ? 6 : 10), size.height * 0.34),
      Offset(bodyRect.right - 14, size.height * 0.35),
      tearShade,
    );
    canvas.drawLine(
      Offset(bodyRect.left + (isWizard ? 6 : 9), size.height * 0.68),
      Offset(bodyRect.left + 14, size.height * 0.69),
      tearShade,
    );
  }

  @override
  bool shouldRepaint(covariant _OpenScrollPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}
