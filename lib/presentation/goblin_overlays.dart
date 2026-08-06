part of '../goblin_flip_app.dart';

class _GoblinDialogue extends StatelessWidget {
  const _GoblinDialogue({required this.onContinue});

  static const greeting =
      'Hello, Traveler. I see you have quite a bit of coin there. '
      'Care to wager on a coin flip?';

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Goblin says: $greeting',
      child: GestureDetector(
        key: const Key('goblin-dialogue'),
        onTap: onContinue,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE0C58B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4B301D), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xB3000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0DDA9), Color(0xFFD4B16E)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: _GameFonts.cinzel(
                      color: const Color(0xFF352213),
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Tap to continue',
                    style: _GameFonts.cinzel(
                      color: const Color(0xFF6B4828),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
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

class _GoblinPreviewButton extends StatelessWidget {
  const _GoblinPreviewButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preview goblin introduction',
      button: true,
      child: FilledButton.tonalIcon(
        key: const Key('debug-goblin-intro'),
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xD92C3D24),
          foregroundColor: const Color(0xFFE4D49F),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 38),
          side: const BorderSide(color: Color(0xFF84944D)),
          textStyle: _GameFonts.cinzel(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: const Text('Goblin intro'),
      ),
    );
  }
}

enum _RecoveryOfferReason {
  emptyBalance,
  lossStreak,
  allInLoss,
  insuredHighBalanceAllIn,
}

@immutable
class _RecoveryOffer {
  const _RecoveryOffer({
    required this.reason,
    required this.adAttemptAvailable,
    this.recoveryTargetBalance,
  });

  final _RecoveryOfferReason reason;
  final bool adAttemptAvailable;
  final int? recoveryTargetBalance;

  bool get revertsInsuredAllIn =>
      reason == _RecoveryOfferReason.insuredHighBalanceAllIn;

  _RecoveryOffer withoutAdAttempt() {
    return _RecoveryOffer(
      reason: reason,
      adAttemptAvailable: false,
      recoveryTargetBalance: recoveryTargetBalance,
    );
  }
}

class _ThousandFlipOfferButton extends StatelessWidget {
  const _ThousandFlipOfferButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('thousand-flip-offer'),
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xE63D582A),
        disabledBackgroundColor: const Color(0x9953452D),
        foregroundColor: const Color(0xFFF3E5B9),
        disabledForegroundColor: const Color(0x999D927D),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 42),
        side: const BorderSide(color: Color(0xFF8A7143), width: 1.4),
        textStyle: _GameFonts.cinzel(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text('+1000 Flips'),
    );
  }
}

class _RecoveryOfferPanel extends StatelessWidget {
  const _RecoveryOfferPanel({
    required this.reason,
    required this.adAttemptAvailable,
    required this.purchaseAvailable,
    required this.purchasePrice,
    required this.purchaseIsTestMode,
    required this.recoveryChargesRemaining,
    required this.recoveryTargetBalance,
    required this.inProgress,
    required this.onWatchAd,
    required this.onPurchase,
    required this.onAcceptLoss,
  });

  final _RecoveryOfferReason reason;
  final bool adAttemptAvailable;
  final bool purchaseAvailable;
  final String purchasePrice;
  final bool purchaseIsTestMode;
  final int recoveryChargesRemaining;
  final int? recoveryTargetBalance;
  final bool inProgress;
  final VoidCallback onWatchAd;
  final VoidCallback onPurchase;
  final VoidCallback onAcceptLoss;

  @override
  Widget build(BuildContext context) {
    final buttonPrice = purchasePrice.replaceFirst(r'$', '');
    final revertsInsuredAllIn =
        reason == _RecoveryOfferReason.insuredHighBalanceAllIn;
    final title = revertsInsuredAllIn ? 'Revert the Loss' : '+1000 Flips';
    final explanation = switch (reason) {
      _RecoveryOfferReason.emptyBalance =>
        'Your purse is empty. Watch an ad or add a fresh bundle.',
      _RecoveryOfferReason.lossStreak =>
        'Five wager losses in a row. Take a lighter reset.',
      _RecoveryOfferReason.allInLoss =>
        'That all-in wager was lost. Refill before the next hand.',
      _RecoveryOfferReason.insuredHighBalanceAllIn =>
        'Insurance caught part of the fall. Watch an ad to return to '
            '${recoveryTargetBalance ?? 0} flips.',
    };
    late final String visibleExplanation;
    if (!revertsInsuredAllIn) {
      visibleExplanation = adAttemptAvailable
          ? explanation
          : 'The ad is unavailable. You can still add a bundle.';
    } else if (recoveryChargesRemaining <= 0) {
      visibleExplanation =
          'No loss reversals remain. All three refill 24 hours after '
          'the last successful recovery.';
    } else if (adAttemptAvailable) {
      visibleExplanation =
          '$explanation\n$recoveryChargesRemaining of '
          '${GameState.maxRecoveryCharges} loss reversals ready.';
    } else {
      visibleExplanation =
          'The recovery ad is unavailable. $recoveryChargesRemaining '
          'loss reversals remain.';
    }
    return Semantics(
      liveRegion: true,
      label:
          '$visibleExplanation Watch an ad or pay $purchasePrice for '
          '${CommerceCatalog.flipBundleDisplayQuantity} flips.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF49301D), width: 2.2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0DDA9), Color(0xFFD2AD69)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xC9000000),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: _GameFonts.cinzelDecorative(
                    color: const Color(0xFF342012),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  visibleExplanation,
                  textAlign: TextAlign.center,
                  style: _GameFonts.cinzel(
                    color: const Color(0xFF4E321D),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                if (adAttemptAvailable)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('watch-recovery-ad'),
                      onPressed: inProgress ? null : onWatchAd,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3D582A),
                        foregroundColor: const Color(0xFFF3E5B9),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: _GameFonts.cinzel(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 19),
                      label: Text(
                        revertsInsuredAllIn
                            ? 'Watch ad • Revert Loss'
                            : 'Watch ad • +1000 Flips',
                      ),
                    ),
                  ),
                if (adAttemptAvailable) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('buy-thousand-flips'),
                    onPressed: purchaseAvailable && !inProgress
                        ? onPurchase
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8A6329),
                      foregroundColor: const Color(0xFFFFE6A3),
                      disabledBackgroundColor: const Color(0xFF6B6251),
                      disabledForegroundColor: const Color(0xFFB7AD98),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: _GameFonts.cinzel(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: const Icon(Icons.monetization_on_outlined, size: 19),
                    label: Text(
                      inProgress
                          ? 'Confirming...'
                          : '${CommerceCatalog.flipBundleDisplayQuantity} '
                                'flips • $buttonPrice',
                    ),
                  ),
                ),
                if (purchaseIsTestMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Local test purchase — no payment is processed.',
                      textAlign: TextAlign.center,
                      style: _GameFonts.cinzel(
                        color: const Color(0xFF76512D),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextButton(
                  key: const Key('accept-wager-loss'),
                  onPressed: inProgress ? null : onAcceptLoss,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF694629),
                    minimumSize: const Size(double.infinity, 46),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: _GameFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text('No Thank You'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
