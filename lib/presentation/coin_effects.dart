part of '../goblin_flip_app.dart';

const double _goldCoinWidth = 164;
const double _goldCoinHeight = 178;

double _animationSegment(
  double progress, {
  required double begin,
  required double end,
  required Curve curve,
}) {
  final localProgress = ((progress - begin) / (end - begin)).clamp(0.0, 1.0);
  return curve.transform(localProgress);
}

CoinFace _coinFace(WagerSide side) {
  return side == WagerSide.heads ? CoinFace.heads : CoinFace.tails;
}

_BetPileSize _betPileFor(int amount, int balance) {
  if (amount <= 1 || balance <= 0) return _BetPileSize.single;
  final share = amount / balance;
  if (share >= 0.875) return _BetPileSize.allIn;
  if (share >= 0.625) return _BetPileSize.threeQuarters;
  if (share >= 0.375) return _BetPileSize.half;
  if (share >= 0.125) return _BetPileSize.quarter;
  return _BetPileSize.single;
}

int _quickBetAmount(int percent, int balance) {
  if (percent >= 100) return balance;
  return math.max(1, balance * percent ~/ 100).toInt();
}

_BetPileSize? _betPileForQuickPercent(int percent) => switch (percent) {
  0 => null,
  25 => _BetPileSize.quarter,
  50 => _BetPileSize.half,
  75 => _BetPileSize.threeQuarters,
  100 => _BetPileSize.allIn,
  _ => null,
};

String _powerupName(PowerupType type) => switch (type) {
  PowerupType.insurance => 'Insurance',
  PowerupType.speedFlip => 'Speed Flip',
  PowerupType.rollBackTime => 'Roll Back Time',
};

WagerSide _oppositeSide(WagerSide side) {
  return side == WagerSide.heads ? WagerSide.tails : WagerSide.heads;
}

class _WispRipplePainter extends CustomPainter {
  const _WispRipplePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final fade = math.sin(progress * math.pi).clamp(0.0, 1.0).toDouble();

    final screenHaze = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFB7EDFF).withValues(alpha: 0.23 * fade),
              const Color(0xFF78CFF2).withValues(alpha: 0.11 * fade),
              Colors.transparent,
            ],
            stops: const [0, 0.48, 1],
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: size.width * 2.15,
              height: size.height * 1.65,
            ),
          )
      ..blendMode = BlendMode.screen;
    canvas.drawRect(Offset.zero & size, screenHaze);

    final vaporPaint = Paint()
      ..color = const Color(0xFFB9EEFF).withValues(alpha: 0.19 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..blendMode = BlendMode.screen;
    for (var mote = 0; mote < 14; mote++) {
      final angle = mote * 1.73 + progress * math.pi;
      final radiusX = size.width * (0.12 + (mote % 5) * 0.09) * progress;
      final radiusY = size.height * (0.08 + (mote % 4) * 0.08) * progress;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx + math.cos(angle) * radiusX,
            center.dy + math.sin(angle) * radiusY,
          ),
          width: (18 + (mote % 3) * 7).toDouble(),
          height: (7 + (mote % 2) * 4).toDouble(),
        ),
        vaporPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WispRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.flips});

  final int flips;

  @override
  Widget build(BuildContext context) {
    const skin = _GameVisualSkins.counterScroll;
    final availableWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: math.min(skin.width, math.max(0.0, availableWidth - 24.0)),
      height: skin.height,
      child: _SkinnableSurface(
        key: const Key('flip-counter-scroll'),
        artwork: skin.artwork,
        proceduralPainter: const _ScrollCounterPainter(),
        child: Padding(
          padding: skin.contentPadding,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Flips: $flips',
              style: _GameFonts.almendra(
                color: skin.textColor,
                fontSize: skin.fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                shadows: const [
                  Shadow(
                    blurRadius: 1.5,
                    color: Color(0xB8F2DEAA),
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollCounterPainter extends CustomPainter {
  const _ScrollCounterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const rollHeight = 15.0;
    final bodyRect = Rect.fromLTRB(
      11,
      rollHeight * 0.62,
      size.width - 11,
      size.height - rollHeight * 0.62,
    );
    final bodyPath = Path()
      ..moveTo(bodyRect.left + 3, bodyRect.top)
      ..quadraticBezierTo(
        size.width * 0.29,
        bodyRect.top - 2,
        size.width * 0.52,
        bodyRect.top + 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        bodyRect.top + 2,
        bodyRect.right - 3,
        bodyRect.top,
      )
      ..lineTo(bodyRect.right, bodyRect.top + 10)
      ..lineTo(bodyRect.right - 5, bodyRect.top + 15)
      ..lineTo(bodyRect.right, bodyRect.top + 20)
      ..lineTo(bodyRect.right - 1, bodyRect.bottom - 4)
      ..quadraticBezierTo(
        size.width * 0.72,
        bodyRect.bottom + 2,
        size.width * 0.48,
        bodyRect.bottom - 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.24,
        bodyRect.bottom - 2,
        bodyRect.left + 2,
        bodyRect.bottom,
      )
      ..lineTo(bodyRect.left, bodyRect.bottom - 11)
      ..lineTo(bodyRect.left + 5, bodyRect.bottom - 16)
      ..lineTo(bodyRect.left, bodyRect.bottom - 22)
      ..lineTo(bodyRect.left + 1, bodyRect.top + 4)
      ..close();

    Path rollPath(Rect rect) {
      return Path()
        ..moveTo(rect.left + 8, rect.top + 1.5)
        ..quadraticBezierTo(
          rect.center.dx,
          rect.top - 1.3,
          rect.right - 8,
          rect.top + 1.5,
        )
        ..quadraticBezierTo(
          rect.right + 1,
          rect.center.dy,
          rect.right - 8,
          rect.bottom - 1.5,
        )
        ..quadraticBezierTo(
          rect.center.dx,
          rect.bottom + 1.4,
          rect.left + 8,
          rect.bottom - 1.5,
        )
        ..quadraticBezierTo(
          rect.left - 1,
          rect.center.dy,
          rect.left + 8,
          rect.top + 1.5,
        )
        ..close();
    }

    final shadowPaint = Paint()
      ..color = const Color(0xA8000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(bodyPath, shadowPaint);
    canvas.restore();

    final rodPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF24170F), Color(0xFF704522), Color(0xFF21150D)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    for (final y in [rollHeight * 0.58, size.height - rollHeight * 0.58]) {
      canvas.drawLine(Offset(3, y), Offset(size.width - 3, y), rodPaint);
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8D6236),
            Color(0xFFC3A36B),
            Color(0xFFAA824E),
            Color(0xFF69421F),
          ],
          stops: [0, 0.13, 0.82, 1],
        ).createShader(bodyRect),
    );

    final topRollRect = Rect.fromLTRB(9, 1, size.width - 9, rollHeight + 2);
    final bottomRollRect = Rect.fromLTRB(
      9,
      size.height - rollHeight - 2,
      size.width - 9,
      size.height - 1,
    );
    final topRollPath = rollPath(topRollRect);
    final bottomRollPath = rollPath(bottomRollRect);
    const rollGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF5D3A20),
        Color(0xFF957041),
        Color(0xFFB98F55),
        Color(0xFF59371E),
      ],
      stops: [0, 0.23, 0.62, 1],
    );
    canvas.drawPath(
      topRollPath,
      Paint()..shader = rollGradient.createShader(topRollRect),
    );
    canvas.drawPath(
      bottomRollPath,
      Paint()..shader = rollGradient.createShader(bottomRollRect),
    );

    final outlinePaint = Paint()
      ..color = const Color(0xFF3D281A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45;
    canvas.drawPath(bodyPath, outlinePaint);

    final creasePaint = Paint()
      ..color = const Color(0x7050321D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    final topCrease = Path()
      ..moveTo(27, topRollRect.top + 5)
      ..quadraticBezierTo(
        size.width * 0.5,
        topRollRect.top + 3.5,
        size.width - 27,
        topRollRect.top + 5,
      );
    final bottomCrease = Path()
      ..moveTo(27, bottomRollRect.bottom - 5)
      ..quadraticBezierTo(
        size.width * 0.5,
        bottomRollRect.bottom - 3.5,
        size.width - 27,
        bottomRollRect.bottom - 5,
      );
    canvas.drawPath(topCrease, creasePaint);
    canvas.drawPath(bottomCrease, creasePaint);

    final tearShade = Paint()
      ..color = const Color(0x72503320)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(
      Path()
        ..moveTo(bodyRect.right - 5, bodyRect.top + 15)
        ..lineTo(bodyRect.right - 10, bodyRect.top + 17),
      tearShade,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bodyRect.left + 5, bodyRect.bottom - 16)
        ..lineTo(bodyRect.left + 10, bodyRect.bottom - 14),
      tearShade,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrollCounterPainter oldDelegate) => false;
}

class _GoldCoin extends StatelessWidget {
  const _GoldCoin({
    super.key,
    required this.face,
    required this.enabled,
    required this.onTap,
  });

  final CoinFace face;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = face == CoinFace.heads ? 'Heads' : 'Tails';
    final engravingSize = face == CoinFace.heads ? 118.0 : 99.0;
    final engravingTop = 76.0 - (engravingSize / 2);
    final engravingAsset = face == CoinFace.heads
        ? 'assets/coins/king_engraving.png'
        : 'assets/coins/goblin_engraving.png';

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$semanticLabel coin. Tap to flip.',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: _goldCoinWidth,
          height: _goldCoinHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CustomPaint(
                size: const Size(_goldCoinWidth, _goldCoinHeight),
                painter: _FlutedCoinBodyPainter(),
              ),
              Positioned(
                top: engravingTop,
                width: engravingSize,
                height: engravingSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: const Offset(-0.7, 0.7),
                      child: Opacity(
                        opacity: 0.34,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFD7AE62),
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            engravingAsset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF3B2818),
                        BlendMode.srcIn,
                      ),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.dilate(
                          radiusX: 0.65,
                          radiusY: 0.65,
                        ),
                        child: Image.asset(
                          engravingAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldBetPile extends StatelessWidget {
  const _GoldBetPile({
    super.key,
    required this.tier,
    required this.maxWidth,
  });

  final _BetPileSize tier;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final baseSize = switch (tier) {
      _BetPileSize.single => const Size(36, 26),
      _BetPileSize.quarter => const Size(56, 34),
      _BetPileSize.half => const Size(68, 44),
      _BetPileSize.threeQuarters => const Size(80, 52),
      _BetPileSize.allIn => const Size(92, 71),
    };
    final phoneScale = (MediaQuery.sizeOf(context).width / 390)
        .clamp(0.72, 1.0)
        .toDouble();
    final scaledSize = Size(
      baseSize.width * phoneScale,
      baseSize.height * phoneScale,
    );
    final width = math.min(scaledSize.width, maxWidth);
    final fitScale = width / scaledSize.width;
    final size = Size(
      width,
      scaledSize.height * fitScale,
    );
    final asset = switch (tier) {
      _BetPileSize.single => 'assets/coins/wager_pile_single.png',
      _BetPileSize.quarter => 'assets/coins/wager_pile_25.png',
      _BetPileSize.half => 'assets/coins/wager_pile_50.png',
      _BetPileSize.threeQuarters => 'assets/coins/wager_pile_75.png',
      _BetPileSize.allIn => 'assets/coins/wager_pile_all_in.png',
    };
    return Semantics(
      label: 'Coins placed on the table',
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: const Offset(3, 3),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x8A160E07),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
              ),
            ),
            Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlutedCoinBodyPainter extends CustomPainter {
  const _FlutedCoinBodyPainter();

  static const _edgeProfile = <double>[
    0.989,
    1.000,
    0.984,
    0.995,
    0.978,
    0.992,
    0.982,
    1.000,
    0.986,
    0.991,
    0.976,
    0.988,
    0.981,
    1.000,
    0.985,
    0.993,
    0.979,
    0.989,
    0.983,
    1.000,
    0.980,
    0.994,
    0.986,
    0.990,
    0.977,
    0.986,
    0.982,
    1.000,
    0.985,
    0.992,
    0.979,
    0.988,
  ];

  Path _jaggedCoinPath(Offset center, double radius) {
    final path = Path();
    for (var index = 0; index < _edgeProfile.length; index++) {
      final angle =
          (-math.pi / 2) + (math.pi * 2 * index / _edgeProfile.length);
      final point = Offset(
        center.dx + math.cos(angle) * radius * _edgeProfile[index],
        center.dy + math.sin(angle) * radius * _edgeProfile[index],
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Path _flutedSideBand(Offset center, double radius, double depth) {
    const segments = 48;
    final path = Path();

    for (var index = 0; index <= segments; index++) {
      final x = radius - ((radius * 2 * index) / segments);
      final y = math.sqrt(math.max(0, (radius * radius) - (x * x)));
      final point = center + Offset(x, y);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    for (var index = segments; index >= 0; index--) {
      final x = radius - ((radius * 2 * index) / segments);
      final y = math.sqrt(math.max(0, (radius * radius) - (x * x)));
      final point = center + Offset(x, y + depth);
      path.lineTo(point.dx, point.dy);
    }

    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 76);
    const radius = 70.0;
    const depth = 14;

    for (var layer = depth; layer >= 1; layer--) {
      final layerCenter = center.translate(0, layer.toDouble());
      final layerBounds = Rect.fromCircle(center: layerCenter, radius: radius);
      canvas.drawPath(
        _jaggedCoinPath(layerCenter, radius),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-1, 0.25),
            end: Alignment(1, -0.15),
            colors: [Color(0xFF8E642D), Color(0xFF6D5429), Color(0xFF3F321E)],
            stops: [0, 0.48, 1],
          ).createShader(layerBounds),
      );
    }

    final sideBand = _flutedSideBand(center, radius, depth.toDouble());
    final sideBounds = Rect.fromLTRB(
      center.dx - radius,
      center.dy,
      center.dx + radius,
      center.dy + radius + depth,
    );
    canvas.drawPath(
      sideBand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: [Color(0xFF8B622D), Color(0xFF6C5229), Color(0xFF40321E)],
          stops: [0, 0.5, 1],
        ).createShader(sideBounds),
    );

    final fluteDark = Paint()
      ..color = const Color(0xA83A2818)
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.square;
    final fluteLight = Paint()
      ..color = const Color(0x568F7848)
      ..strokeWidth = 0.65
      ..strokeCap = StrokeCap.square;

    canvas.save();
    canvas.clipPath(sideBand);
    const fluteCount = 29;
    for (var index = 0; index < fluteCount; index++) {
      final x =
          (-radius + 6) + (((radius * 2) - 12) * index / (fluteCount - 1));
      final y = math.sqrt(math.max(0, (radius * radius) - (x * x)));
      final grooveStart = center + Offset(x, y - 0.5);
      final grooveEnd = grooveStart.translate(0.45, depth + 1);
      canvas.drawLine(grooveStart, grooveEnd, fluteDark);
      canvas.drawLine(
        grooveStart.translate(1.25, 0),
        grooveEnd.translate(1.25, 0),
        fluteLight,
      );
    }
    canvas.restore();

    final faceBounds = Rect.fromCircle(center: center, radius: radius);
    final facePath = _jaggedCoinPath(center, radius);
    canvas.drawPath(
      facePath,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.52, 0.28),
          radius: 1.22,
          colors: [
            Color(0xFFD2AA5C),
            Color(0xFFB18443),
            Color(0xFF826A36),
            Color(0xFF493621),
          ],
          stops: [0, 0.47, 0.78, 1],
        ).createShader(faceBounds),
    );

    canvas.drawPath(
      facePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: [Color(0x00DAB466), Color(0x125F6938), Color(0x4D43532F)],
          stops: [0, 0.56, 1],
        ).createShader(faceBounds)
        ..blendMode = BlendMode.multiply,
    );

    canvas.drawPath(
      facePath,
      Paint()
        ..color = const Color(0xFF4B3016)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.1
        ..strokeJoin = StrokeJoin.bevel,
    );

    final innerBounds = Rect.fromCircle(center: center, radius: radius - 17);
    canvas.drawCircle(
      center,
      radius - 17,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.58, 0.32),
          radius: 1.25,
          colors: [Color(0xFFC39A4E), Color(0xFFA77B3B), Color(0xFF766033)],
          stops: [0, 0.62, 1],
        ).createShader(innerBounds),
    );

    canvas.save();
    canvas.clipPath(facePath);
    const patinaOffsets = <Offset>[
      Offset(-42, -25),
      Offset(38, -34),
      Offset(48, 3),
      Offset(-47, 28),
      Offset(31, 43),
      Offset(-16, -51),
      Offset(5, 50),
    ];
    const patinaRadii = <double>[3.4, 2.5, 4.2, 2.8, 3.6, 2.1, 2.7];
    final patinaPaint = Paint()
      ..color = const Color(0x334D6035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (var index = 0; index < patinaOffsets.length; index++) {
      canvas.drawCircle(
        center + patinaOffsets[index],
        patinaRadii[index],
        patinaPaint,
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 17,
      Paint()
        ..color = const Color(0xFF5C3B1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawArc(
      innerBounds,
      math.pi * 0.53,
      math.pi * 0.56,
      false,
      Paint()
        ..color = const Color(0x80D4AC60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );

    final wearPaint = Paint()
      ..color = const Color(0x3D4A361F)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-43, 32),
      center.translate(-31, 28),
      wearPaint,
    );
    canvas.drawLine(
      center.translate(33, -39),
      center.translate(42, -32),
      wearPaint,
    );
    canvas.drawLine(
      center.translate(24, 43),
      center.translate(35, 39),
      wearPaint,
    );

    final lowerEdge = Paint()
      ..color = const Color(0x8F2D1B0D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(0, depth.toDouble()),
        radius: radius,
      ),
      0.12,
      math.pi - 0.24,
      false,
      lowerEdge,
    );
  }

  @override
  bool shouldRepaint(covariant _FlutedCoinBodyPainter oldDelegate) => false;
}
