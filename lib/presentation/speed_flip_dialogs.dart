part of '../goblin_flip_app.dart';

class _SpeedFlipChoiceDialog extends StatelessWidget {
  const _SpeedFlipChoiceDialog({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFE2C57E),
      title: Text(
        'Choose One Side',
        textAlign: TextAlign.center,
        style: _GameFonts.cinzelDecorative(
          color: const Color(0xFF342012),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        'Your choice applies to all five flips. Each match pays '
        '$price flips.',
        textAlign: TextAlign.center,
        style: _GameFonts.cinzel(
          color: const Color(0xFF4B321E),
          fontWeight: FontWeight.w700,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          key: const Key('speed-flip-heads'),
          onPressed: () => Navigator.of(context).pop(WagerSide.heads),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3D582A),
          ),
          child: const Text('Heads'),
        ),
        FilledButton(
          key: const Key('speed-flip-tails'),
          onPressed: () => Navigator.of(context).pop(WagerSide.tails),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3D582A),
          ),
          child: const Text('Tails'),
        ),
      ],
    );
  }
}

class _SpeedFlipResultsDialog extends StatefulWidget {
  const _SpeedFlipResultsDialog({required this.speedFlip});

  final PendingSpeedFlip speedFlip;

  @override
  State<_SpeedFlipResultsDialog> createState() =>
      _SpeedFlipResultsDialogState();
}

class _SpeedFlipResultsDialogState extends State<_SpeedFlipResultsDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coinController;
  int _completed = 0;

  bool get _finished => _completed == widget.speedFlip.results.length;

  @override
  void initState() {
    super.initState();
    _coinController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 925),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            unawaited(_finishCurrentFlip());
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          setState(() {
            _completed = widget.speedFlip.results.length;
          });
        } else {
          _coinController.forward();
        }
      }
    });
  }

  Future<void> _finishCurrentFlip() async {
    final finishesSequence = _completed + 1 == widget.speedFlip.results.length;
    _emitPlatformHaptic(
      finishesSequence
          ? HapticFeedback.mediumImpact
          : HapticFeedback.selectionClick,
    );
    setState(() {
      _completed += 1;
    });
    if (_finished) return;

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (mounted) {
      _coinController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _coinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guess = widget.speedFlip.guess == WagerSide.heads ? 'Heads' : 'Tails';
    return PopScope(
      canPop: _finished,
      child: AlertDialog(
        backgroundColor: const Color(0xFFE2C57E),
        title: Text(
          'Speed Flip • $guess',
          textAlign: TextAlign.center,
          style: _GameFonts.cinzelDecorative(
            color: const Color(0xFF342012),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 158,
              child: AnimatedBuilder(
                animation: _coinController,
                builder: (context, child) {
                  final currentIndex = math
                      .min(_completed, widget.speedFlip.results.length - 1)
                      .toInt();
                  final target = _coinFace(
                    widget.speedFlip.results[currentIndex],
                  );
                  final progress = _coinController.value;
                  final spins = 8 + (target == CoinFace.tails ? 1 : 0);
                  final angle = progress * math.pi * spins;
                  final visibleFace = progress < 0.76
                      ? (math.cos(angle) >= 0 ? CoinFace.heads : CoinFace.tails)
                      : target;
                  final lift = math.sin(progress * math.pi) * -54;
                  final verticalScale = math
                      .max(0.12, math.cos(angle).abs())
                      .toDouble();
                  return Transform.translate(
                    offset: Offset(0, lift),
                    child: Transform.scale(
                      scale: 0.72,
                      child: Transform.scale(
                        scaleY: verticalScale,
                        child: _GoldCoin(
                          key: ValueKey('speed-coin-$currentIndex'),
                          face: visibleFace,
                          enabled: false,
                          onTap: () {},
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Text(
              _finished
                  ? 'Five flips complete'
                  : 'Flip ${_completed + 1} of 5 • 2× speed',
              key: const Key('speed-flip-counter'),
              style: _GameFonts.cinzel(
                color: const Color(0xFF4B321E),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: List<Widget>.generate(widget.speedFlip.results.length, (
                index,
              ) {
                final revealed = index < _completed;
                final result = widget.speedFlip.results[index];
                final matched = result == widget.speedFlip.guess;
                return AnimatedContainer(
                  key: Key('speed-result-$index'),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  width: revealed ? 48 : 40,
                  height: revealed ? 48 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !revealed
                        ? const Color(0xFF6E5633)
                        : matched
                        ? const Color(0xFF3D582A)
                        : const Color(0xFF70412D),
                    border: Border.all(
                      color: const Color(0xFF342012),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    revealed
                        ? result == WagerSide.heads
                              ? 'H'
                              : 'T'
                        : '?',
                    style: _GameFonts.cinzel(
                      color: const Color(0xFFFFE6A3),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _finished
                  ? Column(
                      key: const Key('speed-flip-summary'),
                      children: [
                        Text(
                          '${widget.speedFlip.matchCount} of 5 matched',
                          style: _GameFonts.cinzel(
                            color: const Color(0xFF4B321E),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Total won: ${widget.speedFlip.payoutAmount} flips',
                          style: _GameFonts.cinzelDecorative(
                            color: const Color(0xFF342012),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'The wizard is bending the odds...',
                      key: ValueKey(_completed),
                      style: _GameFonts.cinzel(
                        color: const Color(0xFF4B321E),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (_finished)
            FilledButton(
              key: const Key('close-speed-flip'),
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3D582A),
              ),
              child: const Text('Collect'),
            ),
        ],
      ),
    );
  }
}
