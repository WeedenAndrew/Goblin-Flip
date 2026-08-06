import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/game_audio_controller.dart';
import 'commerce_catalog.dart';
import 'commerce_receipt_validator.dart';
import 'flip_purchase_service.dart';
import 'game_state.dart';
import 'game_state_store.dart';
import 'recovery_ad_service.dart';

part 'presentation/game_scene.dart';
part 'presentation/visual_skins.dart';
part 'presentation/audio_controls.dart';
part 'presentation/coin_effects.dart';
part 'presentation/goblin_overlays.dart';
part 'presentation/wager_controls.dart';
part 'presentation/powerup_status.dart';
part 'presentation/speed_flip_dialogs.dart';
part 'presentation/scroll_panels.dart';
part 'presentation/wizard_shop.dart';
part 'presentation/wager_sheet.dart';

void _emitPlatformHaptic(Future<void> Function() feedback) {
  if (kIsWeb) return;
  unawaited(feedback().catchError((Object _) {}));
}

abstract final class _GameFonts {
  static TextStyle cinzel({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) => _style(
    'Cinzel',
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows,
  );

  static TextStyle cinzelDecorative({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) => _style(
    'Cinzel Decorative',
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows,
  );

  static TextStyle almendra({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) => _style(
    'Almendra',
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows,
  );

  static TextTheme cinzelTextTheme(TextTheme base) =>
      base.apply(fontFamily: 'Cinzel');

  static TextStyle _style(
    String family, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: family,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows,
  );
}

class GoblinFlipApp extends StatelessWidget {
  const GoblinFlipApp({
    super.key,
    this.gameStateStore,
    this.recoveryAdService,
    this.flipPurchaseService,
    this.gameAudioController,
    this.random,
  });

  final GameStateStore? gameStateStore;
  final RecoveryAdService? recoveryAdService;
  final FlipPurchaseService? flipPurchaseService;
  final GameAudioController? gameAudioController;
  final math.Random? random;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goblin Flip',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB88924),
          brightness: Brightness.dark,
        ),
        textTheme: _GameFonts.cinzelTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: CoinFlipScreen(
        gameStateStore: gameStateStore,
        recoveryAdService: recoveryAdService,
        flipPurchaseService: flipPurchaseService,
        gameAudioController: gameAudioController,
        random: random,
      ),
    );
  }
}

enum CoinFace { heads, tails }

enum _FlipMode { normal, wager, previewWager }

enum _BetPileSize { single, quarter, half, threeQuarters, allIn }

class CoinFlipScreen extends StatefulWidget {
  const CoinFlipScreen({
    super.key,
    this.gameStateStore,
    this.recoveryAdService,
    this.flipPurchaseService,
    this.gameAudioController,
    this.random,
  });

  final GameStateStore? gameStateStore;
  final RecoveryAdService? recoveryAdService;
  final FlipPurchaseService? flipPurchaseService;
  final GameAudioController? gameAudioController;
  final math.Random? random;

  @override
  State<CoinFlipScreen> createState() => _CoinFlipScreenState();
}

class _CoinFlipScreenState extends State<CoinFlipScreen>
    with TickerProviderStateMixin {
  // Curves.bounceOut returns the falling coin to the tabletop four times
  // before the reveal lift begins at 0.64.
  static const _coinImpactProgress = <double>[
    0.58 / 2.75,
    0.58 * 2 / 2.75,
    0.58 * 2.5 / 2.75,
    0.58,
  ];

  late final math.Random _random;
  late final AnimationController _flipController;
  late final AnimationController _goblinController;
  late final AnimationController _wispController;
  late final GameStateStore _gameStateStore;
  late final RecoveryAdService _recoveryAdService;
  late final FlipPurchaseService _flipPurchaseService;
  late final GameAudioController _gameAudioController;

  GameState _gameState = GameState.initial();
  bool _stateReady = false;
  String? _stateErrorMessage;
  bool _unlockedOnCurrentFlip = false;
  bool _isFlipping = false;
  int _nextCoinImpactIndex = 0;
  bool _hasResult = false;
  bool _goblinVisible = false;
  bool _goblinIntroPlaying = false;
  bool _goblinDialogueVisible = false;
  bool _wagerCommitInProgress = false;
  bool _wagerSheetOpen = false;
  bool _powerupSheetOpen = false;
  bool _powerupPurchaseInProgress = false;
  bool _ambientAudioMuted = false;
  bool _audioToggleInProgress = false;
  bool _debugPreviewMode = false;
  int _debugPreviewBalance = CommerceCatalog.flipBundleQuantity;
  bool _recoveryInProgress = false;
  _RecoveryOffer? _recoveryOffer;
  _RecoveryOffer? _previewRecoveryAfterAnimation;
  _FlipMode _activeFlipMode = _FlipMode.normal;
  CoinFace _settledFace = CoinFace.heads;
  CoinFace _targetFace = CoinFace.heads;
  CoinFace _rollbackReturnFace = CoinFace.heads;
  bool _rollbackVisualPending = false;
  bool _previewWagerWon = false;
  _BetPileSize? _activeBetPile;
  int _quickBetPercent = 0;
  String _message = 'Tap the screen';

  int get _flips =>
      _debugPreviewMode ? _debugPreviewBalance : _gameState.flipBalance;

  bool get _goblinUnlocked => _gameState.goblinUnlocked;

  bool get _canVisitGoblin => _goblinUnlocked || _debugPreviewMode;

  bool get _hasPendingResolution =>
      _gameState.pendingWager != null || _gameState.pendingSpeedFlip != null;

  bool get _sceneInteractionBlocked =>
      !_stateReady ||
      _stateErrorMessage != null ||
      _hasPendingResolution ||
      _isFlipping ||
      _rollbackVisualPending ||
      _goblinIntroPlaying ||
      _goblinDialogueVisible ||
      _wagerCommitInProgress ||
      _wagerSheetOpen ||
      _powerupSheetOpen ||
      _powerupPurchaseInProgress ||
      _recoveryOffer != null ||
      _recoveryInProgress;

  bool get _coinEnabled => !_sceneInteractionBlocked;

  bool get _goblinPreviewEnabled => kDebugMode && !_sceneInteractionBlocked;

  bool get _powerupMenuEnabled => _canVisitGoblin && !_sceneInteractionBlocked;

  bool get _wagerMenuEnabled => _powerupMenuEnabled && _flips > 0;

  bool get _quickBetControlsEnabled =>
      _canVisitGoblin && _flips > 0 && !_sceneInteractionBlocked;

  bool get _lossStreakOfferAvailable =>
      !_debugPreviewMode &&
      _gameState.consecutiveWagerLosses >=
          GameState.lossStreakOfferThreshold;

  int get _availableRecoveryCharges => _gameState
      .rechargeRecoveryChargesIfDue(DateTime.now())
      .recoveryChargesRemaining;

  bool _usesInsuredHighBalanceRecovery(PendingWager wager) {
    return wager.didWin == false &&
        wager.wasAllIn &&
        wager.betAmount > GameState.highBalanceRecoveryThreshold &&
        wager.protectionApplied == WagerProtection.insurance;
  }

  GameState get _shopState => _debugPreviewMode
      ? _gameState.copyWith(
          flipBalance: _debugPreviewBalance,
          goblinUnlocked: true,
        )
      : _gameState;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random.secure();
    _gameStateStore = widget.gameStateStore ?? SecureGameStateStore();
    _recoveryAdService =
        widget.recoveryAdService ?? const DebugRecoveryAdService();
    _flipPurchaseService =
        widget.flipPurchaseService ?? const DebugFlipPurchaseService();
    _gameAudioController =
        widget.gameAudioController ?? const SilentGameAudioController();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
    _flipController.addListener(_handleFlipProgress);
    _flipController.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;

      final shouldIntroduceGoblin = _unlockedOnCurrentFlip;
      final completedWager = _activeFlipMode == _FlipMode.wager;
      final completedPreviewWager = _activeFlipMode == _FlipMode.previewWager;
      final wagerDidWin = completedWager
          ? _gameState.pendingWager?.didWin
          : completedPreviewWager
          ? _previewWagerWon
          : null;
      setState(() {
        _isFlipping = false;
        _hasResult = true;
        _settledFace = _targetFace;
        if (_stateErrorMessage == null) {
          _message = _targetFace == CoinFace.heads ? 'Heads' : 'Tails';

          if (_unlockedOnCurrentFlip) {
            _message = 'A goblin gambler steps from the trees...';
          }
        }
        _unlockedOnCurrentFlip = false;
        if (completedPreviewWager) {
          _recoveryOffer = _previewRecoveryAfterAnimation;
          _previewRecoveryAfterAnimation = null;
          _quickBetPercent = 0;
          _activeBetPile = null;
        }
      });
      _emitPlatformHaptic(
        completedWager || completedPreviewWager
            ? HapticFeedback.mediumImpact
            : HapticFeedback.lightImpact,
      );
      _playWagerResult(wagerDidWin);

      if (shouldIntroduceGoblin) {
        unawaited(_presentGoblinIntro());
      }
      if (completedWager) {
        unawaited(_completeWagerReveal());
        if (_rollbackVisualPending) {
          unawaited(_playRollbackEffect());
        }
      }
      if (completedPreviewWager && _rollbackVisualPending) {
        unawaited(_playRollbackEffect());
      }
    });
    _goblinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _wispController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    unawaited(_initializeAudio());
    _loadGameState();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _goblinController.dispose();
    _wispController.dispose();
    unawaited(_gameAudioController.dispose());
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Future<void> _initializeAudio() async {
    await _gameAudioController.initialize();
    await _gameAudioController.ensureBackgroundMusic();
    if (!mounted) return;
    setState(() {
      _ambientAudioMuted = _gameAudioController.ambientMuted;
    });
  }

  Future<void> _toggleAmbientAudio() async {
    if (_audioToggleInProgress) return;
    final nextMuted = !_ambientAudioMuted;
    setState(() {
      _ambientAudioMuted = nextMuted;
      _audioToggleInProgress = true;
    });
    await _gameAudioController.setAmbientMuted(nextMuted);
    if (!mounted) return;
    setState(() {
      _ambientAudioMuted = _gameAudioController.ambientMuted;
      _audioToggleInProgress = false;
    });
  }

  void _playWagerResult(bool? didWin) {
    if (didWin == null) return;
    unawaited(
      didWin
          ? _gameAudioController.playWagerWin()
          : _gameAudioController.playWagerLoss(),
    );
  }

  void _handleFlipProgress() {
    if (!_isFlipping) return;

    while (_nextCoinImpactIndex < _coinImpactProgress.length &&
        _flipController.value >=
            _coinImpactProgress[_nextCoinImpactIndex]) {
      final bounceIndex = _nextCoinImpactIndex;
      _nextCoinImpactIndex++;
      unawaited(_gameAudioController.playCoinImpact(bounceIndex));
    }
  }

  void _playFlipAnimation() {
    _nextCoinImpactIndex = 0;
    _emitPlatformHaptic(HapticFeedback.selectionClick);
    if (_reduceMotion) {
      _nextCoinImpactIndex = _coinImpactProgress.length - 1;
      _flipController.value = 0;
      _flipController.value = 1;
      return;
    }
    _flipController.forward(from: 0);
  }

  Future<void> _playGoblinEntrance() async {
    if (_reduceMotion) {
      _goblinController.value = 1;
      return;
    }
    await _goblinController.forward(from: 0);
  }

  Future<void> _playGoblinExit() async {
    if (_reduceMotion) {
      _goblinController.value = 0;
      return;
    }
    await _goblinController.reverse();
  }

  Future<void> _loadGameState() async {
    try {
      final loadedState = await _gameStateStore.load();
      if (!mounted) return;
      if (loadedState.goblinUnlocked) {
        _goblinController.value = 1;
      }
      setState(() {
        _gameState = loadedState;
        _stateReady = true;
        _stateErrorMessage = null;
        _goblinVisible = loadedState.goblinUnlocked;
        _wagerCommitInProgress = loadedState.pendingWager != null;
        _powerupPurchaseInProgress = loadedState.pendingSpeedFlip != null;
        _message = loadedState.pendingWager != null
            ? 'Restoring the goblin\'s wager...'
            : loadedState.pendingSpeedFlip != null
            ? 'Restoring the wizard\'s Speed Flip...'
            : 'Tap the screen';
      });
      if (loadedState.pendingWager != null) {
        unawaited(_resumePendingWager(loadedState));
      } else if (loadedState.pendingSpeedFlip != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_showPendingSpeedFlip());
          }
        });
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _stateReady = false;
        _stateErrorMessage = 'The encrypted ledger could not be opened.';
        _message = _stateErrorMessage!;
      });
    }
  }

  Future<void> _persistGameState(GameState snapshot) async {
    try {
      await _gameStateStore.save(snapshot);
    } on Object {
      if (!mounted || _gameState.revision != snapshot.revision) return;
      setState(() {
        _stateErrorMessage = 'The encrypted ledger could not be saved.';
        _message = _stateErrorMessage!;
      });
    }
  }

  void _flipCoin() {
    if (_sceneInteractionBlocked) return;

    if (!_debugPreviewMode &&
        _gameState.goblinUnlocked &&
        _gameState.flipBalance == 0) {
      setState(() {
        _recoveryOffer = const _RecoveryOffer(
          reason: _RecoveryOfferReason.emptyBalance,
          adAttemptAvailable: true,
        );
        _message = 'No flips remain.';
      });
      return;
    }

    if (_quickBetPercent > 0 && _canVisitGoblin) {
      unawaited(_promptAndPlaceQuickWager());
      return;
    }

    if (_debugPreviewMode) {
      setState(() {
        _activeFlipMode = _FlipMode.normal;
        _quickBetPercent = 0;
        _activeBetPile = null;
        _debugPreviewBalance += 1;
        _isFlipping = true;
        _hasResult = false;
        _targetFace = _random.nextBool() ? CoinFace.heads : CoinFace.tails;
        _message = '...';
      });
      _playFlipAnimation();
      return;
    }

    final previousState = _gameState;
    final nextState = previousState.recordNormalFlip(DateTime.now());
    setState(() {
      _activeFlipMode = _FlipMode.normal;
      _quickBetPercent = 0;
      _activeBetPile = null;
      _gameState = nextState;
      _unlockedOnCurrentFlip =
          !previousState.goblinUnlocked && nextState.goblinUnlocked;
      _isFlipping = true;
      _hasResult = false;
      _targetFace = _random.nextBool() ? CoinFace.heads : CoinFace.tails;
      _message = '...';
    });

    unawaited(_persistGameState(nextState));
    _playFlipAnimation();
  }

  void _handleSceneTap() {
    unawaited(_gameAudioController.ensureBackgroundMusic());
    if (_goblinDialogueVisible) {
      unawaited(_dismissGoblinDialogue());
      return;
    }
    _flipCoin();
  }

  Future<void> _presentGoblinIntro() async {
    if (!mounted || _goblinIntroPlaying) return;

    setState(() {
      _goblinVisible = true;
      _goblinIntroPlaying = true;
      _goblinDialogueVisible = false;
      _message = '';
    });

    unawaited(_gameAudioController.playGoblinEntrance());
    await _playGoblinEntrance();
    if (!mounted) return;

    setState(() {
      _goblinIntroPlaying = false;
      _goblinDialogueVisible = true;
    });
  }

  void _previewGoblinIntro() {
    if (!_goblinPreviewEnabled) {
      return;
    }
    if (!_goblinUnlocked) {
      setState(() {
        _debugPreviewMode = true;
        _debugPreviewBalance = CommerceCatalog.flipBundleQuantity;
      });
    }
    unawaited(_presentGoblinIntro());
  }

  Future<void> _dismissGoblinDialogue() async {
    if (!_goblinDialogueVisible) return;

    final shouldLeaveAfterPreview = !_canVisitGoblin;
    setState(() {
      _goblinDialogueVisible = false;
      _goblinIntroPlaying = shouldLeaveAfterPreview;
      _message = 'Tap the screen';
    });

    if (!shouldLeaveAfterPreview) return;

    await _playGoblinExit();
    if (!mounted) return;
    setState(() {
      _goblinVisible = false;
      _goblinIntroPlaying = false;
    });
  }

  Future<void> _openPowerupSheet() async {
    if (!mounted || !_powerupMenuEnabled) return;

    setState(() {
      _powerupSheetOpen = true;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3000000),
      builder: (context) => _PowerupSheet(
        state: _shopState,
        purchasesEnabled: true,
        onBuy: (type) {
          unawaited(_purchasePowerup(type));
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _powerupSheetOpen = false;
    });
  }

  Future<void> _purchasePowerup(PowerupType type) async {
    if (!mounted ||
        _powerupPurchaseInProgress ||
        _gameState.pendingWager != null ||
        _gameState.pendingSpeedFlip != null) {
      return;
    }

    final purchaseState = _shopState;
    WagerSide? speedFlipGuess;
    if (type == PowerupType.speedFlip) {
      setState(() {
        _powerupPurchaseInProgress = true;
      });
      speedFlipGuess = await showDialog<WagerSide>(
        context: context,
        builder: (context) => _SpeedFlipChoiceDialog(
          price: purchaseState.powerupPrice(PowerupType.speedFlip),
        ),
      );
      if (!mounted) return;
      if (speedFlipGuess == null) {
        setState(() {
          _powerupPurchaseInProgress = false;
        });
        return;
      }
    }

    final previous = _gameState;
    late final GameState purchased;
    try {
      if (speedFlipGuess == null) {
        purchased = purchaseState.purchasePowerup(type, DateTime.now());
      } else {
        final guess = speedFlipGuess;
        final opposite = _oppositeSide(guess);
        final results = List<WagerSide>.generate(
          5,
          (_) => _random.nextDouble() < 0.60 ? guess : opposite,
          growable: false,
        );
        purchased = purchaseState.purchaseSpeedFlip(
          id: _newWagerId(),
          guess: guess,
          results: results,
          now: DateTime.now(),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _powerupPurchaseInProgress = false;
        _message = error is StateError
            ? error.message.toString()
            : 'The wizard refused that purchase.';
      });
      return;
    }

    setState(() {
      _gameState = purchased;
      if (_debugPreviewMode) {
        _debugPreviewBalance = purchased.flipBalance;
      }
      _powerupPurchaseInProgress = true;
      _message = '${_powerupName(type)} purchased.';
    });
    Navigator.of(context).pop();

    if (_debugPreviewMode) {
      final speedFlip = purchased.pendingSpeedFlip;
      if (speedFlip != null) {
        await _showPreviewSpeedFlip(speedFlip);
      } else if (mounted) {
        setState(() {
          _powerupPurchaseInProgress = false;
        });
      }
      return;
    }

    try {
      await _gameStateStore.save(purchased);
    } on Object {
      if (!mounted) return;
      setState(() {
        _gameState = previous;
        _powerupPurchaseInProgress = false;
        _stateErrorMessage = 'The power-up purchase could not be secured.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted) return;
    if (purchased.pendingSpeedFlip != null) {
      await _showPendingSpeedFlip();
      return;
    }
    setState(() {
      _powerupPurchaseInProgress = false;
    });
  }

  Future<void> _showPreviewSpeedFlip(PendingSpeedFlip speedFlip) async {
    setState(() {
      _message = 'Speed Flip!';
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SpeedFlipResultsDialog(speedFlip: speedFlip),
    );
    if (!mounted || _gameState.pendingSpeedFlip?.id != speedFlip.id) return;

    final cleared = _gameState.clearPendingSpeedFlip(DateTime.now());
    setState(() {
      _gameState = cleared;
      _debugPreviewBalance = cleared.flipBalance;
      _quickBetPercent = 0;
      _activeBetPile = null;
      _powerupPurchaseInProgress = false;
      _message = 'Speed Flip won ${speedFlip.payoutAmount} flips!';
    });
  }

  Future<void> _showPendingSpeedFlip() async {
    final speedFlip = _gameState.pendingSpeedFlip;
    if (!mounted || speedFlip == null) return;
    setState(() {
      _powerupPurchaseInProgress = true;
      _message = 'Speed Flip!';
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SpeedFlipResultsDialog(speedFlip: speedFlip),
    );
    if (!mounted || _gameState.pendingSpeedFlip?.id != speedFlip.id) return;

    final cleared = _gameState.clearPendingSpeedFlip(DateTime.now());
    try {
      await _gameStateStore.save(cleared);
    } on Object {
      if (!mounted) return;
      setState(() {
        _powerupPurchaseInProgress = false;
        _stateErrorMessage = 'The Speed Flip result could not be closed.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _gameState = cleared;
      _quickBetPercent = 0;
      _activeBetPile = null;
      _powerupPurchaseInProgress = false;
      _message = 'Speed Flip won ${speedFlip.payoutAmount} flips!';
    });
  }

  Future<void> _openWagerSheet() async {
    if (!mounted) return;
    if (_canVisitGoblin && _flips <= 0) {
      setState(() {
        _message = 'You have no flips to wager.';
      });
      return;
    }
    if (!_wagerMenuEnabled) {
      return;
    }

    setState(() {
      _wagerSheetOpen = true;
    });
    final initialAmount = _quickBetPercent == 0
        ? null
        : _quickBetAmount(_quickBetPercent, _flips);
    final request = await showModalBottomSheet<_WagerRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3000000),
      builder: (context) =>
          _WagerSheet(balance: _flips, initialAmount: initialAmount),
    );
    if (!mounted) return;
    setState(() {
      _wagerSheetOpen = false;
    });

    if (request != null) {
      await _placeAndRunWager(request);
    }
  }

  void _selectQuickBet(int percent) {
    if (!_quickBetControlsEnabled ||
        !_quickBetPresets.any((preset) => preset.$1 == percent)) {
      return;
    }
    setState(() {
      _quickBetPercent = percent;
      _activeBetPile = _betPileForQuickPercent(percent);
    });
  }

  Future<void> _promptAndPlaceQuickWager() async {
    if (!_quickBetControlsEnabled || _quickBetPercent == 0) return;

    final amount = _quickBetAmount(_quickBetPercent, _flips);
    setState(() {
      _wagerSheetOpen = true;
    });
    final guess = await showDialog<WagerSide>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (context) => const _QuickWagerSidePrompt(),
    );
    if (!mounted) return;
    setState(() {
      _wagerSheetOpen = false;
    });
    if (guess == null) return;

    await _placeAndRunWager(_WagerRequest(amount: amount, guess: guess));
  }

  Future<void> _placeAndRunWager(_WagerRequest request) async {
    if (_debugPreviewMode) {
      _startPreviewWager(request);
      return;
    }
    if (_wagerCommitInProgress ||
        _gameState.pendingWager != null ||
        _gameState.pendingSpeedFlip != null) {
      return;
    }

    final beforeWager = _gameState;
    final betPile = _betPileFor(request.amount, beforeWager.flipBalance);
    late final GameState placed;
    try {
      placed = beforeWager.placeWager(
        id: _newWagerId(),
        betAmount: request.amount,
        guess: request.guess,
        now: DateTime.now(),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is StateError
            ? error.message.toString()
            : error is ArgumentError
            ? 'Choose a valid wager amount.'
            : 'The goblin refused that wager.';
      });
      return;
    }

    setState(() {
      _gameState = placed;
      _activeBetPile = betPile;
      _wagerCommitInProgress = true;
      _message = 'The goblin counts your wager...';
    });

    try {
      await _gameStateStore.save(placed);
    } on Object {
      if (!mounted) return;
      setState(() {
        _gameState = beforeWager;
        _wagerCommitInProgress = false;
        _stateErrorMessage = 'The encrypted wager could not be saved.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    final outcome = _random.nextBool() ? WagerSide.heads : WagerSide.tails;
    final resolved = placed.resolvePendingWager(outcome, DateTime.now());
    if (!mounted) return;
    setState(() {
      _gameState = resolved;
      _message = 'The wager is sealed...';
    });

    try {
      await _gameStateStore.save(resolved);
    } on Object {
      if (!mounted) return;
      setState(() {
        _gameState = placed;
        _wagerCommitInProgress = false;
        _stateErrorMessage = 'The wager result could not be secured.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted) return;
    _startWagerAnimation(resolved);
  }

  Future<void> _resumePendingWager(GameState restored) async {
    var resolved = restored;
    final pending = restored.pendingWager;
    if (pending == null) return;
    _activeBetPile = _betPileFor(
      pending.betAmount,
      restored.flipBalance + pending.betAmount,
    );

    if (!pending.isResolved) {
      final outcome = _random.nextBool() ? WagerSide.heads : WagerSide.tails;
      resolved = restored.resolvePendingWager(outcome, DateTime.now());
      if (mounted) {
        setState(() {
          _gameState = resolved;
          _message = 'Securing the restored wager...';
        });
      }
      try {
        await _gameStateStore.save(resolved);
      } on Object {
        if (!mounted) return;
        setState(() {
          _gameState = restored;
          _wagerCommitInProgress = false;
          _stateErrorMessage = 'The restored wager could not be secured.';
          _message = _stateErrorMessage!;
        });
        return;
      }
    }

    if (!mounted) return;
    _startWagerAnimation(resolved);
  }

  void _startWagerAnimation(GameState resolved) {
    final wager = resolved.pendingWager;
    final result = wager?.result;
    if (result == null) return;

    setState(() {
      _rollbackVisualPending =
          wager?.protectionApplied == WagerProtection.rollBackTime;
      if (_rollbackVisualPending) {
        _rollbackReturnFace = _settledFace;
      }
      _activeFlipMode = _FlipMode.wager;
      _quickBetPercent = 0;
      _gameState = resolved;
      _wagerCommitInProgress = false;
      _isFlipping = true;
      _hasResult = false;
      _targetFace = _coinFace(result);
      _message = '...';
    });
    _playFlipAnimation();
  }

  Future<void> _playRollbackEffect() async {
    final returnFace = _rollbackReturnFace;
    _emitPlatformHaptic(HapticFeedback.heavyImpact);
    if (_reduceMotion) {
      _wispController.reset();
      setState(() {
        _settledFace = returnFace;
        _targetFace = returnFace;
        _rollbackVisualPending = false;
        if (_stateErrorMessage == null) {
          _message = returnFace == CoinFace.heads ? 'Heads' : 'Tails';
        }
      });
      return;
    }
    setState(() {
      _message = 'Time bends...';
    });

    final animation = _wispController.forward(from: 0).orCancel;
    await Future<void>.delayed(const Duration(milliseconds: 430));
    if (!mounted) return;
    setState(() {
      _settledFace = returnFace;
      _targetFace = returnFace;
      if (_stateErrorMessage == null) {
        _message = returnFace == CoinFace.heads ? 'Heads' : 'Tails';
      }
    });

    try {
      await animation;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    _wispController.reset();
    setState(() {
      _rollbackVisualPending = false;
    });
  }

  void _startPreviewWager(_WagerRequest request) {
    if (request.amount <= 0 || request.amount > _debugPreviewBalance) return;

    final result = _random.nextBool() ? WagerSide.heads : WagerSide.tails;
    final won = result == request.guess;
    final balanceBeforeWager = _debugPreviewBalance;
    var payout = won ? request.amount * 2 : 0;
    final usesRollBack = !won && _gameState.rollBackTimeActive;
    if (usesRollBack) {
      payout = request.amount;
    } else if (!won && _gameState.insuranceActive) {
      payout =
          (request.amount * _gameState.insuranceCoveragePercent) ~/ 100;
    }
    final nextBalance = balanceBeforeWager - request.amount + payout;
    setState(() {
      _activeFlipMode = _FlipMode.previewWager;
      _quickBetPercent = 0;
      _activeBetPile = _betPileFor(request.amount, balanceBeforeWager);
      _debugPreviewBalance = nextBalance;
      _previewWagerWon = won;
      _rollbackVisualPending = usesRollBack;
      if (usesRollBack) {
        _rollbackReturnFace = _settledFace;
        _gameState = _gameState.copyWith(rollBackTimeActive: false);
      }
      _isFlipping = true;
      _hasResult = false;
      _targetFace = _coinFace(result);
      _previewRecoveryAfterAnimation =
          !won && !usesRollBack && request.amount == balanceBeforeWager
          ? _RecoveryOffer(
              reason: _RecoveryOfferReason.allInLoss,
              adAttemptAvailable: _recoveryAdService.isAvailable,
            )
          : null;
      _message = '...';
    });
    _playFlipAnimation();
  }

  Future<void> _completeWagerReveal() async {
    final resolved = _gameState;
    final wager = resolved.pendingWager;
    if (wager == null || !wager.isResolved) return;

    if (_usesInsuredHighBalanceRecovery(wager)) {
      if (!mounted) return;
      setState(() {
        _activeFlipMode = _FlipMode.normal;
        _wagerCommitInProgress = false;
        _recoveryOffer = _RecoveryOffer(
          reason: _RecoveryOfferReason.insuredHighBalanceAllIn,
          adAttemptAvailable: _recoveryAdService.isAvailable,
          recoveryTargetBalance: wager.betAmount,
        );
        _quickBetPercent = 0;
        _activeBetPile = null;
      });
      return;
    }

    final now = DateTime.now();
    final cleared = resolved.clearResolvedWager(now);
    final recoveryOffer =
        wager.didWin == false &&
            wager.wasAllIn &&
            wager.protectionApplied != WagerProtection.rollBackTime
        ? _RecoveryOffer(
            reason: _RecoveryOfferReason.allInLoss,
            adAttemptAvailable: _recoveryAdService.isAvailable,
          )
        : null;
    if (mounted) {
      setState(() {
        _wagerCommitInProgress = true;
      });
    }
    try {
      await _gameStateStore.save(cleared);
    } on Object {
      if (!mounted) return;
      setState(() {
        _wagerCommitInProgress = false;
        _stateErrorMessage = 'The completed wager could not be closed.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted || _gameState.revision != resolved.revision) return;
    setState(() {
      _activeFlipMode = _FlipMode.normal;
      _gameState = cleared;
      _wagerCommitInProgress = false;
      _recoveryOffer = recoveryOffer;
      _quickBetPercent = 0;
      _activeBetPile = null;
    });
  }

  Future<bool> _settlePendingHighBalanceLoss() async {
    final beforeClear = _gameState;
    final wager = beforeClear.pendingWager;
    if (wager == null || !_usesInsuredHighBalanceRecovery(wager)) return true;

    final cleared = beforeClear.clearResolvedWager(DateTime.now());
    try {
      await _gameStateStore.save(cleared);
    } on Object {
      if (!mounted) return false;
      setState(() {
        _recoveryInProgress = false;
        _stateErrorMessage = 'The insured loss could not be secured.';
        _message = _stateErrorMessage!;
      });
      return false;
    }
    if (!mounted || _gameState.revision != beforeClear.revision) return false;
    setState(() {
      _gameState = cleared;
    });
    return true;
  }

  Future<void> _attemptRecovery() async {
    final offer = _recoveryOffer;
    if (offer == null ||
        !offer.adAttemptAvailable ||
        (offer.revertsInsuredAllIn && _availableRecoveryCharges <= 0) ||
        _recoveryInProgress) {
      return;
    }

    setState(() {
      _recoveryOffer = null;
      _recoveryInProgress = true;
      _message = 'Playing the rewarded ad...';
    });

    VerifiedAdReward? reward;
    try {
      reward = await _recoveryAdService.showRecoveryAd();
    } on Object {
      reward = null;
    }
    if (!mounted) return;
    if (reward == null ||
        !CommerceReceiptValidator.acceptsAdReward(
          reward,
          allowDebugReceipts: kDebugMode,
        )) {
      if (offer.revertsInsuredAllIn &&
          !await _settlePendingHighBalanceLoss()) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _recoveryOffer = offer.withoutAdAttempt();
        _recoveryInProgress = false;
        _message = reward == null
            ? 'The recovery offer has passed.'
            : 'The ad reward could not be verified.';
      });
      return;
    }

    if (_debugPreviewMode) {
      setState(() {
        _debugPreviewBalance = offer.revertsInsuredAllIn
            ? offer.recoveryTargetBalance ?? _debugPreviewBalance
            : _debugPreviewBalance + CommerceCatalog.flipBundleQuantity;
        _quickBetPercent = 0;
        _activeBetPile = null;
        _recoveryInProgress = false;
        _message = offer.revertsInsuredAllIn
            ? 'The insured loss was reverted.'
            : '${CommerceCatalog.flipBundleDisplayQuantity} flips added.';
      });
      return;
    }

    final beforeRecovery = _gameState;
    late final GameState recovered;
    try {
      recovered = offer.revertsInsuredAllIn
          ? beforeRecovery.creditVerifiedInsuredAllInRecovery(
              rewardId: reward.rewardId,
              now: DateTime.now(),
            )
          : beforeRecovery.creditVerifiedThousandFlipAd(
              rewardId: reward.rewardId,
              now: DateTime.now(),
            );
    } on Object {
      if (offer.revertsInsuredAllIn &&
          !await _settlePendingHighBalanceLoss()) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _recoveryOffer = offer.withoutAdAttempt();
        _recoveryInProgress = false;
        _message = 'The ad reward could not be applied.';
      });
      return;
    }

    try {
      await _gameStateStore.save(recovered);
    } on Object {
      if (!mounted) return;
      setState(() {
        _recoveryOffer = offer.withoutAdAttempt();
        _recoveryInProgress = false;
        _stateErrorMessage = 'The recovered flips could not be secured.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted || _gameState.revision != beforeRecovery.revision) return;
    setState(() {
      _gameState = recovered;
      _quickBetPercent = 0;
      _activeBetPile = null;
      _recoveryInProgress = false;
      _message = offer.revertsInsuredAllIn
          ? 'The insured loss was reverted.'
          : '${CommerceCatalog.flipBundleDisplayQuantity} flips added.';
    });
  }

  Future<void> _attemptThousandFlipPurchase() async {
    final offer = _recoveryOffer;
    if (offer == null ||
        _recoveryInProgress ||
        !_flipPurchaseService.isAvailable) {
      return;
    }

    setState(() {
      _recoveryInProgress = true;
      _message = 'Confirming the coin bundle...';
    });

    VerifiedFlipPurchase? purchase;
    try {
      purchase = await _flipPurchaseService.purchaseThousandFlips();
    } on Object {
      purchase = null;
    }
    if (!mounted) return;
    if (purchase == null ||
        !CommerceReceiptValidator.acceptsPurchase(
          purchase,
          allowDebugReceipts: kDebugMode,
        )) {
      setState(() {
        _recoveryInProgress = false;
        _message = purchase == null
            ? 'The coin bundle was not completed.'
            : 'The purchase could not be verified.';
      });
      return;
    }

    if (_debugPreviewMode) {
      setState(() {
        _debugPreviewBalance += CommerceCatalog.flipBundleQuantity;
        _recoveryOffer = null;
        _quickBetPercent = 0;
        _activeBetPile = null;
        _recoveryInProgress = false;
        _message = '${CommerceCatalog.flipBundleDisplayQuantity} flips added.';
      });
      return;
    }

    final beforePurchase = _gameState;
    late final GameState purchased;
    try {
      purchased = beforePurchase.creditVerifiedThousandFlipPurchase(
        transactionId: purchase.transactionId,
        now: DateTime.now(),
      );
    } on Object {
      setState(() {
        _recoveryInProgress = false;
        _message = 'The coin bundle could not be applied.';
      });
      return;
    }

    try {
      await _gameStateStore.save(purchased);
    } on Object {
      if (!mounted) return;
      setState(() {
        _recoveryInProgress = false;
        _stateErrorMessage = 'The purchased flips could not be secured.';
        _message = _stateErrorMessage!;
      });
      return;
    }

    if (!mounted || _gameState.revision != beforePurchase.revision) return;
    setState(() {
      _gameState = purchased;
      _recoveryOffer = null;
      _quickBetPercent = 0;
      _activeBetPile = null;
      _recoveryInProgress = false;
      _message = '${CommerceCatalog.flipBundleDisplayQuantity} flips added.';
    });
  }

  Future<void> _declineRecovery() async {
    final offer = _recoveryOffer;
    if (offer == null || _recoveryInProgress) return;
    if (offer.revertsInsuredAllIn && !_debugPreviewMode) {
      setState(() {
        _recoveryInProgress = true;
      });
      if (!await _settlePendingHighBalanceLoss()) return;
      if (!mounted) return;
    }
    setState(() {
      _recoveryOffer = null;
      _recoveryInProgress = false;
      _message = 'Maybe next time.';
    });
  }

  void _openThousandFlipOffer() {
    if (!_lossStreakOfferAvailable || _sceneInteractionBlocked) return;
    setState(() {
      _recoveryOffer = _RecoveryOffer(
        reason: _RecoveryOfferReason.lossStreak,
        adAttemptAvailable: _recoveryAdService.isAvailable,
      );
    });
  }

  String _newWagerId() {
    final randomPart = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$randomPart';
  }

  @override
  Widget build(BuildContext context) => _buildGameScene(context);
}
