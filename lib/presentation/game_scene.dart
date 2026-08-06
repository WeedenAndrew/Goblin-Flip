part of '../goblin_flip_app.dart';

// The foreground stays sealed to the bottom while its tabletop rises on phones.
const double _tableVerticalScale = 1.38;
// Keep scene geometry tied to table_foreground_v2.png (864 x 1821). The image
// is painted with BoxFit.fitHeight, so a guessed ratio shifts overlays off the
// table on narrower Android displays.
const double _tableArtworkAspectRatio = 864 / 1821;
const double _tabletopArtworkLandingY = 0.865;
const double _tabletopLandingY =
    1 - ((1 - _tabletopArtworkLandingY) * _tableVerticalScale);
// The wager pile belongs just inside the tabletop's far edge, in the open
// space opposite the candle, rather than against the quick-bet foundation.
// At the pile's right-side placement, the first opaque tabletop row is 1469.
const double _tabletopArtworkUpperY = 1469 / 1821;
const double _tabletopUpperY =
    1 - ((1 - _tabletopArtworkUpperY) * _tableVerticalScale);
const double _wagerPileDeskTopY = _tabletopUpperY + 0.018;

extension _CoinFlipSceneBuilder on _CoinFlipScreenState {
  Widget _buildGameScene(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        key: const Key('screen-flip-area'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleSceneTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safePadding = MediaQuery.paddingOf(context);
            final safeSceneHeight =
                constraints.maxHeight - safePadding.vertical;
            final tableArtworkWidth =
                constraints.maxHeight * _tableArtworkAspectRatio;
            final tableRightEdge = math.min(
              constraints.maxWidth,
              (constraints.maxWidth + tableArtworkWidth) / 2,
            );
            final tableEdgeInset = math.max(
              6.0,
              math.min(tableArtworkWidth, constraints.maxWidth) * 0.02,
            );
            final tablePileRightEdge = tableRightEdge - tableEdgeInset;
            final wagerPileRight =
                constraints.maxWidth - tablePileRightEdge;
            final flipZoneRightEdge =
                (constraints.maxWidth / 2) + (_goldCoinWidth / 2);
            final wagerPileMaxWidth = math.max(
              28.0,
              tablePileRightEdge - flipZoneRightEdge - 6,
            );
            final landingCenterInsideSafeArea =
                (constraints.maxHeight * _tabletopLandingY) - safePadding.top;
            final coinTravelHeight = safeSceneHeight - _goldCoinHeight;
            final coinLandingOffset =
                landingCenterInsideSafeArea - (_goldCoinHeight / 2);
            final coinAlignmentY = coinTravelHeight <= 0
                ? 0.0
                : ((coinLandingOffset / coinTravelHeight) * 2) - 1;
            final isCoinResultMessage =
                _message == 'Heads' || _message == 'Tails';
            final recoveryOffer = _recoveryOffer;
            final recoveryCharges = _availableRecoveryCharges;
            final messageText = Text(
              _message,
              maxLines: isCoinResultMessage ? 1 : 3,
              softWrap: !isCoinResultMessage,
              overflow: isCoinResultMessage
                  ? TextOverflow.visible
                  : TextOverflow.fade,
              textAlign: TextAlign.center,
              style: _GameFonts.cinzelDecorative(
                color: const Color(0xFFFFE6A3),
                fontSize: _isFlipping || isCoinResultMessage ? 69 : 23,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Transform.scale(
                    scale: 1.12,
                    child: Image.asset(
                      'assets/backgrounds/forest_option_4_green.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Image.asset(
                  'assets/backgrounds/forest_backdrop_v2.png',
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.bottomCenter,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x8A000000), Color(0x00000000)],
                    ),
                  ),
                ),
                if (_goblinVisible)
                  Positioned(
                    left: constraints.maxWidth * 0.04,
                    right: constraints.maxWidth * 0.04,
                    top: constraints.maxHeight * 0.398,
                    bottom: constraints.maxHeight * -0.028,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _goblinController,
                        curve: const Interval(0, 0.52),
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.15, 0.03),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _goblinController,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: Image.asset(
                          'assets/characters/goblin_gambler_v4.png',
                          key: const Key('goblin-character'),
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: Transform.scale(
                    key: const Key('raised-table-layer'),
                    scaleY: _tableVerticalScale,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      'assets/backgrounds/table_foreground_v2.png',
                      key: const Key('table-foreground'),
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (_activeBetPile != null &&
                    (_quickBetPercent > 0 ||
                        _wagerCommitInProgress ||
                        (_activeFlipMode != _FlipMode.normal &&
                            (_isFlipping || _rollbackVisualPending))))
                  Positioned(
                    right: wagerPileRight,
                    top: constraints.maxHeight * _wagerPileDeskTopY,
                    child: IgnorePointer(
                      child: _GoldBetPile(
                        key: const Key('wager-gold-pile'),
                        tier: _activeBetPile!,
                        maxWidth: wagerPileMaxWidth,
                      ),
                    ),
                  ),
                SafeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: 0,
                        left: 10,
                        right: 10,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _AudioMuteButton(
                                muted: _ambientAudioMuted,
                                enabled: !_audioToggleInProgress,
                                onPressed: () {
                                  unawaited(_toggleAmbientAudio());
                                },
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 74,
                                ),
                                child: _Counter(flips: _flips),
                              ),
                            ),
                            if (_canVisitGoblin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: _PowerupMenuButton(
                                  enabled: _powerupMenuEnabled,
                                  onPressed: () {
                                    unawaited(_openPowerupSheet());
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, -0.50),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: math.min(
                              72.0,
                              constraints.maxWidth * 0.16,
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: KeyedSubtree(
                              key: ValueKey(_message),
                              child: isCoinResultMessage
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: messageText,
                                    )
                                  : messageText,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        key: const Key('tabletop-coin-landing'),
                        alignment: Alignment(0, coinAlignmentY),
                        child: AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final progress = _isFlipping
                                ? _flipController.value
                                : (_hasResult ? 1.0 : 0.58);
                            final fallProgress = _animationSegment(
                              progress,
                              begin: 0,
                              end: 0.58,
                              curve: Curves.bounceOut,
                            );
                            final revealProgress = _animationSegment(
                              progress,
                              begin: 0.64,
                              end: 1,
                              curve: Curves.easeOutBack,
                            );
                            final spinProgress = _animationSegment(
                              progress,
                              begin: 0,
                              end: 0.58,
                              curve: Curves.easeOutCubic,
                            );
                            final landingTiltProgress = _animationSegment(
                              progress,
                              begin: 0.40,
                              end: 0.64,
                              curve: Curves.easeInOutCubic,
                            );
                            final distance = constraints.maxHeight * 0.68;
                            final revealLift =
                                constraints.maxHeight * 0.24 * revealProgress;
                            final yOffset =
                                -distance * (1 - fallProgress) - revealLift;
                            final halfTurns =
                                10 + (_targetFace == CoinFace.tails ? 1 : 0);
                            final angle = spinProgress * math.pi * halfTurns;
                            final visibleFace = _isFlipping
                                ? (progress < 0.58
                                      ? (math.cos(angle) >= 0
                                            ? CoinFace.heads
                                            : CoinFace.tails)
                                      : _targetFace)
                                : _settledFace;
                            final spinScale = math
                                .max(0.12, math.cos(angle).abs())
                                .toDouble();
                            const tableTiltScale = 0.52;
                            final landingScale =
                                spinScale +
                                ((tableTiltScale - spinScale) *
                                    landingTiltProgress);
                            final revealedScale =
                                tableTiltScale +
                                ((1 - tableTiltScale) * revealProgress);
                            final verticalScale = _isFlipping && progress < 0.64
                                ? landingScale
                                : revealedScale;
                            final revealScale = 1 + (0.45 * revealProgress);

                            return Transform.translate(
                              offset: Offset(0, yOffset),
                              child: Transform.scale(
                                scale: revealScale,
                                child: Transform.scale(
                                  scaleY: verticalScale,
                                  child: _GoldCoin(
                                    key: const Key('coin-button'),
                                    face: visibleFace,
                                    enabled: _coinEnabled,
                                    onTap: _flipCoin,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_goblinDialogueVisible)
                        Align(
                          alignment: const Alignment(0, -0.66),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.68,
                              ),
                              child: SingleChildScrollView(
                                child: _GoblinDialogue(
                                  onContinue: () {
                                    unawaited(_dismissGoblinDialogue());
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (recoveryOffer != null)
                        Align(
                          alignment: const Alignment(0, -0.54),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.72,
                              ),
                              child: SingleChildScrollView(
                                child: _RecoveryOfferPanel(
                                  reason: recoveryOffer.reason,
                                  adAttemptAvailable:
                                      recoveryOffer.adAttemptAvailable &&
                                      _recoveryAdService.isAvailable &&
                                      (!recoveryOffer.revertsInsuredAllIn ||
                                          recoveryCharges > 0),
                                  purchaseAvailable:
                                      _flipPurchaseService.isAvailable,
                                  purchasePrice:
                                      _flipPurchaseService.displayPrice,
                                  purchaseIsTestMode:
                                      _flipPurchaseService.isTestMode,
                                  recoveryChargesRemaining:
                                      recoveryCharges,
                                  recoveryTargetBalance:
                                      recoveryOffer.recoveryTargetBalance,
                                  inProgress: _recoveryInProgress,
                                  onWatchAd: () {
                                    unawaited(_attemptRecovery());
                                  },
                                  onPurchase: () {
                                    unawaited(_attemptThousandFlipPurchase());
                                  },
                                  onAcceptLoss: () {
                                    unawaited(_declineRecovery());
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_gameState.insuranceActive ||
                          _gameState.rollBackTimeActive)
                        Positioned(
                          top: kDebugMode ? 132 : 80,
                          left: 10,
                          child: _ActivePowerupIcons(
                            insuranceActive: _gameState.insuranceActive,
                            insuranceCoveragePercent:
                                _gameState.insuranceCoveragePercent,
                            rollBackTimeActive: _gameState.rollBackTimeActive,
                          ),
                        ),
                      if (kDebugMode)
                        Positioned(
                          top: 80,
                          left: 10,
                          child: _GoblinPreviewButton(
                            enabled: _goblinPreviewEnabled,
                            onPressed: _previewGoblinIntro,
                          ),
                        ),
                      if (_canVisitGoblin)
                        Positioned(
                          top: 80,
                          right: 10,
                          child: _WagerOpenButton(
                            enabled: _wagerMenuEnabled,
                            onPressed: () {
                              unawaited(_openWagerSheet());
                            },
                          ),
                        ),
                      if (_lossStreakOfferAvailable && _recoveryOffer == null)
                        Positioned(
                          top: 130,
                          right: 10,
                          child: _ThousandFlipOfferButton(
                            enabled: !_sceneInteractionBlocked,
                            onPressed: _openThousandFlipOffer,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_canVisitGoblin)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      key: const Key('quick-bet-rail'),
                      color: _GameVisualSkins.quickBetRail.backdropColor,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: _StoneQuickBetBar(
                          selectedPercent: _quickBetPercent,
                          enabled: _quickBetControlsEnabled,
                          onSelected: _selectQuickBet,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _wispController,
                    builder: (context, child) {
                      if (_wispController.isDismissed) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        key: const Key('rollback-wisp-effect'),
                        painter: _WispRipplePainter(
                          progress: _wispController.value,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
