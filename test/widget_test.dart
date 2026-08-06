import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/audio/game_audio_controller.dart';
import 'package:goblin_flip/flip_purchase_service.dart';
import 'package:goblin_flip/game_state.dart';
import 'package:goblin_flip/game_state_store.dart';
import 'package:goblin_flip/main.dart';
import 'package:goblin_flip/recovery_ad_service.dart';

void main() {
  testWidgets('coin flip increments the flip counter', (tester) async {
    final store = _MemoryGameStateStore(GameState.initial());
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flip-counter-scroll')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('flip-counter-scroll'))).width,
      250,
    );
    expect(find.text('Flips: 0'), findsOneWidget);
    expect(find.text('Tap the screen'), findsOneWidget);

    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pump();

    // The committed flip is counted before the visual animation resolves.
    expect(find.text('Flips: 1'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Flips: 1'), findsOneWidget);
    expect(store.state.flipBalance, 1);
  });

  testWidgets('reduced motion resolves a flip without delaying state', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(GameState.initial());
    final audio = _RecordingGameAudioController();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CoinFlipScreen(
            gameStateStore: store,
            gameAudioController: audio,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pump();

    expect(store.state.flipBalance, 1);
    expect(find.text('Flips: 1'), findsOneWidget);
    expect(find.text('...'), findsNothing);
    expect(audio.coinImpactBounces, [3]);
  });

  testWidgets('compact phone layout keeps the counter and quick bets usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );

    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('flip-counter-scroll'))).width,
      lessThanOrEqualTo(296),
    );
    for (final percent in <int>[0, 25, 50, 75, 100]) {
      expect(find.byKey(Key('quick-bet-$percent')), findsOneWidget);
    }
    final counterRect = tester.getRect(
      find.byKey(const Key('flip-counter-scroll')),
    );
    final muteRect = tester.getRect(
      find.byKey(const Key('audio-mute-toggle')),
    );
    final wizardRect = tester.getRect(
      find.byKey(const Key('open-powerups')),
    );
    final wagerRect = tester.getRect(find.byKey(const Key('open-wager')));
    expect(muteRect.center.dy, closeTo(counterRect.center.dy, 0.1));
    expect(wizardRect.center.dy, closeTo(counterRect.center.dy, 0.1));
    expect(wagerRect.right, closeTo(wizardRect.right, 0.1));
    expect(wagerRect.top, greaterThan(wizardRect.bottom));
    final tableBounds = tester.getRect(
      find.byKey(const Key('table-foreground')),
    );
    expect(tableBounds.top, lessThan(0));
    expect(tableBounds.bottom, closeTo(568, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('coin result stays unpunctuated on one compact-phone line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(GameState.initial()),
        random: _FixedRandom(nextBoolValue: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();

    final result = find.text('Heads');
    expect(result, findsOneWidget);
    expect(find.text('Heads!'), findsNothing);
    final resultText = tester.widget<Text>(result);
    expect(resultText.maxLines, 1);
    expect(resultText.softWrap, isFalse);
    expect(
      find.ancestor(of: result, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
  });

  testWidgets('coin remains centered on the table through phone safe areas', (
    tester,
  ) async {
    const phoneSize = Size(320, 568);
    const expectedLandingY = 1 - ((1 - 0.865) * 1.38);
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: phoneSize,
            padding: EdgeInsets.only(top: 28, bottom: 24),
          ),
          child: CoinFlipScreen(
            gameStateStore: _MemoryGameStateStore(GameState.initial()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final coinCenter = tester.getCenter(
      find.byKey(const Key('coin-button')),
    );
    expect(coinCenter.dx, closeTo(phoneSize.width / 2, 0.1));
    expect(coinCenter.dy, closeTo(phoneSize.height * expectedLandingY, 0.1));
    final tableTransform = tester.widget<Transform>(
      find.byKey(const Key('raised-table-layer')),
    );
    expect(tableTransform.transform.storage[5], closeTo(1.38, 0.001));
  });

  testWidgets('large text can scroll inside the compact zero-balance panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 0, goblinUnlocked: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: CoinFlipScreen(gameStateStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();

    expect(find.text('+1000 Flips'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
    expect(find.text('1,000 flips • 0.99'), findsOneWidget);
    expect(find.text('No Thank You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaching 50 permanently unlocks the goblin', (tester) async {
    final initial = GameState.initial().copyWith(flipBalance: 49);
    final store = _MemoryGameStateStore(initial);
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coin-button')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 50);
    expect(store.state.goblinUnlocked, isTrue);
    expect(
      find.text(
        'Hello, Traveler. I see you have quite a bit of coin there. '
        'Care to wager on a coin flip?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a tap outside the goblin dialogue advances the intro', (
    tester,
  ) async {
    final initial = GameState.initial().copyWith(flipBalance: 49);
    final store = _MemoryGameStateStore(initial);
    final audio = _RecordingGameAudioController();
    await tester.pumpWidget(
      GoblinFlipApp(gameStateStore: store, gameAudioController: audio),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coin-button')));
    await tester.pumpAndSettle();

    expect(audio.goblinEntranceCalls, 1);
    final dialogue = find.byKey(const Key('goblin-dialogue'));
    expect(dialogue, findsOneWidget);
    final screenRect = tester.getRect(
      find.byKey(const Key('screen-flip-area')),
    );
    final dialogueRect = tester.getRect(dialogue);
    final outsideTap = Offset(screenRect.right - 12, screenRect.center.dy);
    expect(dialogueRect.contains(outsideTap), isFalse);

    await tester.tapAt(outsideTap);
    await tester.pumpAndSettle();

    expect(dialogue, findsNothing);
    expect(find.byKey(const Key('goblin-character')), findsOneWidget);
    expect(store.state.flipBalance, 50);
  });

  testWidgets('mute silences ambience but a wager win still plays', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    final audio = _RecordingGameAudioController();
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        gameAudioController: audio,
        random: _FixedRandom(nextBoolValue: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio-mute-toggle')), findsOneWidget);
    expect(audio.initializeCalls, 1);
    expect(audio.ensureBackgroundCalls, 1);
    await tester.tap(find.byKey(const Key('audio-mute-toggle')));
    await tester.pumpAndSettle();

    expect(audio.ambientMuted, isTrue);
    expect(audio.muteChanges, [true]);

    await tester.tap(find.byKey(const Key('quick-bet-25')));
    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-wager-heads')));
    await tester.pumpAndSettle();

    expect(audio.wagerWinCalls, 1);
    expect(audio.wagerLossCalls, 0);
    expect(audio.coinImpactBounces, [0, 1, 2, 3]);
    expect(audio.ambientMuted, isTrue);
  });

  testWidgets('a lost wager plays the loss cue', (tester) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    final audio = _RecordingGameAudioController();
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        gameAudioController: audio,
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick-bet-25')));
    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-wager-heads')));
    await tester.pumpAndSettle();

    expect(audio.wagerLossCalls, 1);
    expect(audio.wagerWinCalls, 0);
  });

  testWidgets('debug intro preview never changes the saved balance', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(GameState.initial());
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debug-goblin-intro')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goblin-character')), findsOneWidget);
    expect(find.byKey(const Key('goblin-dialogue')), findsOneWidget);
    expect(store.state.flipBalance, 0);
    expect(store.state.goblinUnlocked, isFalse);

    await tester.tap(find.byKey(const Key('goblin-dialogue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goblin-character')), findsOneWidget);
    expect(find.byKey(const Key('confirm-wager')), findsNothing);
    expect(find.text('Flips: 1000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coin-button')));
    await tester.pump();
    expect(find.text('Flips: 1001'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wager-scroll')), findsOneWidget);
    expect(find.byKey(const Key('confirm-wager')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('wager-amount')), '30');
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Flips: '), findsOneWidget);
    expect(store.state.flipBalance, 0);
    expect(store.state.goblinUnlocked, isFalse);
    expect(store.savedStates, isEmpty);
  });

  testWidgets('an unlocked save loads with the goblin waiting silently', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goblin-character')), findsOneWidget);
    expect(find.byKey(const Key('goblin-dialogue')), findsNothing);
    expect(store.state.flipBalance, 100);
    expect(store.state.goblinUnlocked, isTrue);

    await tester.tap(find.byKey(const Key('coin-button')));
    await tester.pump();
    expect(find.text('Flips: 101'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(store.state.flipBalance, 101);
  });

  testWidgets('wager hotkeys quickly set each balance percentage', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('wager-25-percent')));

    await tester.tap(find.byKey(const Key('wager-25-percent')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wager-amount')))
          .controller
          ?.text,
      '25',
    );

    await tester.tap(find.byKey(const Key('wager-50-percent')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wager-amount')))
          .controller
          ?.text,
      '50',
    );

    await tester.tap(find.byKey(const Key('wager-75-percent')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wager-amount')))
          .controller
          ?.text,
      '75',
    );

    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wager-amount')))
          .controller
          ?.text,
      '100',
    );
  });

  testWidgets('stone preset arms a wager for the next screen tap', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        random: _FixedRandom(nextBoolValue: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-bet-0')), findsOneWidget);
    expect(find.byKey(const Key('quick-bet-25')), findsOneWidget);
    expect(find.byKey(const Key('quick-bet-50')), findsOneWidget);
    expect(find.byKey(const Key('quick-bet-75')), findsOneWidget);
    expect(find.byKey(const Key('quick-bet-100')), findsOneWidget);

    final screenRect = tester.getRect(
      find.byKey(const Key('screen-flip-area')),
    );
    final railRect = tester.getRect(find.byKey(const Key('quick-bet-rail')));
    final brickRects = <Rect>[
      tester.getRect(find.byKey(const Key('quick-bet-0'))),
      tester.getRect(find.byKey(const Key('quick-bet-25'))),
      tester.getRect(find.byKey(const Key('quick-bet-50'))),
      tester.getRect(find.byKey(const Key('quick-bet-75'))),
      tester.getRect(find.byKey(const Key('quick-bet-100'))),
    ];
    expect(railRect.left, closeTo(screenRect.left, 0.001));
    expect(railRect.right, closeTo(screenRect.right, 0.001));
    expect(railRect.bottom, closeTo(screenRect.bottom, 0.001));
    expect(brickRects.first.left, closeTo(railRect.left, 0.001));
    expect(brickRects.last.right, closeTo(railRect.right, 0.001));
    for (var index = 0; index < brickRects.length - 1; index++) {
      expect(
        brickRects[index].right,
        closeTo(brickRects[index + 1].left, 0.001),
      );
    }

    await tester.tap(find.byKey(const Key('quick-bet-25')));
    await tester.pump();
    expect(find.text('25% wager ready.'), findsNothing);
    expect(find.byKey(const Key('wager-gold-pile')), findsOneWidget);
    final pileRect = tester.getRect(
      find.byKey(const Key('wager-gold-pile')),
    );
    const expectedPileTopY =
        1 - ((1 - (1469 / 1821)) * 1.38) + 0.018;
    expect(
      pileRect.top,
      closeTo(screenRect.height * expectedPileTopY, 0.1),
      reason: 'The wager pile should occupy the tabletop\'s upper dead space.',
    );
    expect(
      pileRect.center.dx,
      greaterThan(screenRect.center.dx),
      reason: 'The wager pile should stay opposite the candle.',
    );
    expect(
      pileRect.bottom,
      lessThanOrEqualTo(railRect.top - 12),
      reason: 'The wager pile must stay above the stone quick-bet rail.',
    );

    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wager-scroll')), findsNothing);
    expect(find.byKey(const Key('quick-wager-side-prompt')), findsOneWidget);
    expect(find.byKey(const Key('quick-wager-heads')), findsOneWidget);
    expect(find.byKey(const Key('quick-wager-tails')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-wager-heads')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-wager-side-prompt')), findsNothing);
    expect(store.state.flipBalance, 125);
    expect(find.text('Flips: 125'), findsOneWidget);
    expect(find.byKey(const Key('wager-gold-pile')), findsNothing);

    // The wager preset is one-shot. The next screen tap is a normal flip,
    // rather than silently repeating the previous 25% wager.
    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pump();
    expect(find.text('Flips: 126'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('all-in pile stays inside a compact Android tabletop', (
    tester,
  ) async {
    const phoneSize = Size(320, 568);
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(
          GameState.initial().copyWith(flipBalance: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-bet-100')));
    await tester.pump();

    final pileRect = tester.getRect(
      find.byKey(const Key('wager-gold-pile')),
    );
    final railRect = tester.getRect(find.byKey(const Key('quick-bet-rail')));
    final paintedTableWidth = phoneSize.height * (864 / 1821);
    final paintedTableRight =
        (phoneSize.width + paintedTableWidth) / 2;

    expect(pileRect.width, lessThanOrEqualTo(76));
    expect(
      pileRect.left,
      greaterThanOrEqualTo((phoneSize.width / 2) + (164 / 2) + 6),
      reason: 'The wager pile must stay outside the coin flip zone.',
    );
    expect(pileRect.right, lessThanOrEqualTo(paintedTableRight - 6));
    expect(pileRect.bottom, lessThan(railRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-in pile stays seated on a tall Android tabletop', (
    tester,
  ) async {
    const phoneSize = Size(360, 800);
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(
          GameState.initial().copyWith(flipBalance: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-bet-100')));
    await tester.pump();

    final pileRect = tester.getRect(
      find.byKey(const Key('wager-gold-pile')),
    );
    final railRect = tester.getRect(find.byKey(const Key('quick-bet-rail')));
    final paintedTableWidth = phoneSize.height * (864 / 1821);
    final paintedTableRight = math.min(
      phoneSize.width,
      (phoneSize.width + paintedTableWidth) / 2,
    );
    const transformedTabletopY =
        1 - ((1 - (1469 / 1821)) * 1.38);

    expect(
      pileRect.top,
      greaterThan(phoneSize.height * transformedTabletopY),
      reason: 'The visible pile must begin below the actual tabletop edge.',
    );
    expect(
      pileRect.left,
      greaterThanOrEqualTo((phoneSize.width / 2) + (164 / 2) + 6),
      reason: 'The wager pile must stay outside the coin flip zone.',
    );
    expect(pileRect.right, lessThan(paintedTableRight));
    expect(pileRect.bottom, lessThan(railRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview Roll Back triggers before the recovery ad', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(GameState.initial());
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debug-goblin-intro')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goblin-dialogue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();

    final rollbackButton = find.byKey(const Key('buy-rollback'));
    await tester.ensureVisible(rollbackButton);
    await tester.tap(rollbackButton);
    await tester.pumpAndSettle();

    expect(find.text('Flips: 500'), findsOneWidget);
    expect(find.byKey(const Key('active-rollback')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('rollback-wisp-effect')),
      timeout: const Duration(seconds: 4),
    );

    expect(find.text('Flips: 500'), findsOneWidget);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
    expect(find.byKey(const Key('active-rollback')), findsNothing);
    expect(store.state.flipBalance, 0);
    expect(store.savedStates, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('wizard icon opens the power-up rules', (tester) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();

    expect(find.text('Wizard\'s Charms'), findsOneWidget);
    expect(find.byKey(const Key('wizard-scroll')), findsOneWidget);
    expect(find.text('Insurance'), findsOneWidget);
    expect(find.text('Roll Back Time'), findsOneWidget);
    expect(find.text('Speed Flip'), findsOneWidget);
    expect(find.text('100 flips'), findsOneWidget);
    expect(find.text('300 flips'), findsOneWidget);
    expect(find.text('500 flips'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-powerups')));
    await tester.pumpAndSettle();
    expect(find.text('Wizard\'s Charms'), findsNothing);
  });

  testWidgets('buying Insurance permanently raises its protection', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 1000),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-insurance')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 900);
    expect(store.state.insuranceActive, isTrue);
    expect(store.state.insuranceLevel, 1);
    expect(store.state.insuranceCoveragePercent, 5);
    expect(find.byKey(const Key('active-insurance')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();
    expect(find.text('5% of 60%'), findsOneWidget);
    expect(find.text('200 flips'), findsOneWidget);
    expect(find.byKey(const Key('insurance-progress')), findsOneWidget);
  });

  testWidgets('active power-up icons form a vertical hamburger stack', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(
        flipBalance: 100,
        insuranceLevel: 1,
        rollBackTimeActive: true,
      ),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-powerup-stack')), findsOneWidget);
    final insuranceCenter = tester.getCenter(
      find.byKey(const Key('active-insurance')),
    );
    final rollbackCenter = tester.getCenter(
      find.byKey(const Key('active-rollback')),
    );
    expect(rollbackCenter.dx, closeTo(insuranceCenter.dx, 0.1));
    expect(rollbackCenter.dy, greaterThan(insuranceCenter.dy));
  });

  testWidgets('Speed Flip resolves five weighted bonus results once', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 1000),
    );
    await tester.pumpWidget(
      GoblinFlipApp(gameStateStore: store, random: math.Random(7)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();
    final speedFlipButton = find.byKey(const Key('buy-speed-flip'));
    await tester.ensureVisible(speedFlipButton);
    await tester.pumpAndSettle();
    await tester.tap(speedFlipButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('speed-flip-heads')));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('speed-flip-summary')),
      timeout: const Duration(seconds: 8),
    );

    final pending = store.state.pendingSpeedFlip;
    expect(pending, isNotNull);
    expect(pending!.results, hasLength(5));
    expect(find.byKey(const Key('speed-flip-summary')), findsOneWidget);
    expect(
      store.state.flipBalance,
      1000 - pending.purchasePrice + pending.payoutAmount,
    );

    await tester.tap(find.byKey(const Key('close-speed-flip')));
    await tester.pumpAndSettle();
    expect(store.state.pendingSpeedFlip, isNull);
  });

  testWidgets('Roll Back Time restores a loss with the wisp effect', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final armed = GameState.initial(now: now)
        .copyWith(flipBalance: 1000)
        .purchasePowerup(PowerupType.rollBackTime, now);
    final store = _MemoryGameStateStore(armed);
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('rollback-wisp-effect')),
      timeout: const Duration(seconds: 4),
    );

    expect(find.byKey(const Key('rollback-wisp-effect')), findsOneWidget);
    expect(store.state.flipBalance, armed.flipBalance);
    expect(store.state.rollBackTimeActive, isFalse);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Heads'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rollback-wisp-effect')), findsNothing);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
  });

  testWidgets('a wager persists deduction, result, and cleanup in order', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wager-amount')), '25');
    await tester.tap(find.byKey(const Key('wager-tails')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('wager-gold-pile')),
      timeout: const Duration(seconds: 2),
    );
    expect(find.byKey(const Key('wager-gold-pile')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wager-gold-pile')), findsNothing);

    expect(store.savedStates, hasLength(3));

    final placed = store.savedStates[0];
    final resolved = store.savedStates[1];
    final cleared = store.savedStates[2];

    expect(placed.flipBalance, 75);
    expect(placed.pendingWager?.guess, WagerSide.tails);
    expect(placed.pendingWager?.isResolved, isFalse);
    expect(resolved.pendingWager?.isResolved, isTrue);
    expect(resolved.flipBalance, anyOf(75, 125));
    expect(cleared.pendingWager, isNull);
    expect(cleared.flipBalance, resolved.flipBalance);
    expect(store.state.flipBalance, resolved.flipBalance);
  });

  testWidgets('an interrupted unresolved wager safely resumes on load', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final placed = GameState.initial(now: now)
        .copyWith(flipBalance: 100)
        .placeWager(
          id: 'interrupted-wager',
          betAmount: 40,
          guess: WagerSide.heads,
          now: now,
        );
    final store = _MemoryGameStateStore(placed);

    await tester.pumpWidget(GoblinFlipApp(gameStateStore: store));
    await tester.pumpAndSettle();

    expect(store.savedStates, hasLength(2));
    expect(store.savedStates[0].pendingWager?.isResolved, isTrue);
    expect(store.savedStates[1].pendingWager, isNull);
    expect(store.state.flipBalance, anyOf(60, 140));
  });

  testWidgets('a successful recovery ad grants 1000 flips once', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('watch-recovery-ad')), findsOneWidget);
    expect(store.state.flipBalance, 0);

    await tester.tap(find.byKey(const Key('watch-recovery-ad')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 1000);
    expect(store.state.recoveryChargesRemaining, 3);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
    expect(store.savedStates, hasLength(4));
  });

  testWidgets('insured all-in above 10k offers a charged loss reversion', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(
        flipBalance: 12000,
        insuranceLevel: 1,
      ),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 600);
    expect(store.state.pendingWager?.isResolved, isTrue);
    expect(find.text('Revert the Loss'), findsOneWidget);
    expect(find.textContaining('3 of 3 loss reversals ready.'), findsOneWidget);
    expect(find.text('Watch ad • Revert Loss'), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-recovery-ad')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 12000);
    expect(store.state.pendingWager, isNull);
    expect(store.state.recoveryChargesRemaining, 2);
    expect(store.savedStates, hasLength(3));
  });

  testWidgets('exhausted high-balance recovery falls back to 1000 purchase', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final resolved = GameState.initial(now: now)
        .copyWith(
          flipBalance: 12000,
          insuranceLevel: 1,
          recoveryChargesRemaining: 0,
          lastRecoveryUsedAtUtc: now,
        )
        .placeWager(
          id: 'exhausted-widget-loss',
          betAmount: 12000,
          guess: WagerSide.heads,
          now: now,
        )
        .resolvePendingWager(WagerSide.tails, now);
    final store = _MemoryGameStateStore(resolved);
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        flipPurchaseService: const _FakeFlipPurchaseService(succeeds: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revert the Loss'), findsOneWidget);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
    expect(find.textContaining('No loss reversals remain.'), findsOneWidget);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy-thousand-flips')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 1600);
    expect(store.state.pendingWager, isNull);
    expect(store.state.recoveryChargesRemaining, 0);
  });

  testWidgets('failed high-balance recovery keeps the loss without a charge', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final resolved = GameState.initial(now: now)
        .copyWith(flipBalance: 12000, insuranceLevel: 1)
        .placeWager(
          id: 'failed-high-widget-loss',
          betAmount: 12000,
          guess: WagerSide.heads,
          now: now,
        )
        .resolvePendingWager(WagerSide.tails, now);
    final store = _MemoryGameStateStore(resolved);
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: false),
        flipPurchaseService: const _FakeFlipPurchaseService(succeeds: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('watch-recovery-ad')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 600);
    expect(store.state.pendingWager, isNull);
    expect(store.state.recoveryChargesRemaining, 3);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
  });

  testWidgets('five losses expose the +1000 Flips offer icon', (tester) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(
        flipBalance: 100,
        consecutiveWagerLosses: GameState.lossStreakOfferThreshold,
      ),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thousand-flip-offer')), findsOneWidget);
    expect(find.text('+1000 Flips'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thousand-flip-offer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('watch-recovery-ad')), findsOneWidget);
    expect(find.text('Watch ad • +1000 Flips'), findsOneWidget);
  });

  testWidgets('a failed recovery ad leaves the loss and cannot be retried', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: false),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('watch-recovery-ad')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(find.byKey(const Key('watch-recovery-ad')), findsNothing);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
    expect(store.savedStates, hasLength(3));
  });

  testWidgets('a forged rewarded-ad result cannot restore a loss', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _ForgedRecoveryAdService(),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('watch-recovery-ad')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(store.state.processedAdRewardIds, isEmpty);
    expect(find.text('The ad reward could not be verified.'), findsOneWidget);
  });

  testWidgets('the debug purchase provider adds 1000 flips once', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        flipPurchaseService: const _FakeFlipPurchaseService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
    expect(
      find.text('Local test purchase — no payment is processed.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('buy-thousand-flips')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 1000);
    expect(find.byKey(const Key('buy-thousand-flips')), findsNothing);
    expect(store.savedStates, hasLength(4));
  });

  testWidgets('a forged purchase result cannot credit flips', (tester) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: false),
        flipPurchaseService: const _ForgedFlipPurchaseService(),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-thousand-flips')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(store.state.processedPurchaseIds, isEmpty);
    expect(find.text('The purchase could not be verified.'), findsOneWidget);
  });

  testWidgets('recovery charges do not gate the standard 1000-flip ad', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        flipPurchaseService: const _FakeFlipPurchaseService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(find.byKey(const Key('watch-recovery-ad')), findsOneWidget);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
    expect(find.textContaining('recovery charges'), findsNothing);
  });

  testWidgets('zero after unlock cannot bypass the store with a normal flip', (
    tester,
  ) async {
    final store = _MemoryGameStateStore(
      GameState.initial().copyWith(flipBalance: 100),
    );
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        flipPurchaseService: const _FakeFlipPurchaseService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wager-all-in')));
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    await tester.tap(find.byKey(const Key('confirm-wager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-wager-loss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('buy-thousand-flips')), findsNothing);

    await tester.tap(find.byKey(const Key('screen-flip-area')));
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(find.byKey(const Key('watch-recovery-ad')), findsOneWidget);
    expect(find.byKey(const Key('buy-thousand-flips')), findsOneWidget);
    expect(find.text('+1000 Flips'), findsOneWidget);
    expect(find.text('No flips remain.'), findsOneWidget);
  });

  testWidgets('a restored all-in loss still receives its one offer', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final resolvedLoss = GameState.initial(now: now)
        .copyWith(flipBalance: 100)
        .placeWager(
          id: 'resolved-before-restart',
          betAmount: 100,
          guess: WagerSide.heads,
          now: now,
        )
        .resolvePendingWager(WagerSide.tails, now);
    final store = _MemoryGameStateStore(resolvedLoss);

    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: store,
        recoveryAdService: const _FakeRecoveryAdService(succeeds: true),
        random: _FixedRandom(nextBoolValue: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.state.flipBalance, 0);
    expect(store.state.pendingWager, isNull);
    expect(find.byKey(const Key('watch-recovery-ad')), findsOneWidget);
  });
}

class _MemoryGameStateStore implements GameStateStore {
  _MemoryGameStateStore(this.state);

  GameState state;
  final List<GameState> savedStates = [];

  @override
  Future<GameState> load() async => state;

  @override
  Future<void> save(GameState state) async {
    this.state = state;
    savedStates.add(state);
  }
}

class _RecordingGameAudioController implements GameAudioController {
  @override
  bool ambientMuted = false;

  int initializeCalls = 0;
  int ensureBackgroundCalls = 0;
  int goblinEntranceCalls = 0;
  final List<int> coinImpactBounces = [];
  int wagerWinCalls = 0;
  int wagerLossCalls = 0;
  final List<bool> muteChanges = [];

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> ensureBackgroundMusic() async {
    ensureBackgroundCalls++;
  }

  @override
  Future<void> setAmbientMuted(bool muted) async {
    ambientMuted = muted;
    muteChanges.add(muted);
  }

  @override
  Future<void> playGoblinEntrance() async {
    goblinEntranceCalls++;
  }

  @override
  Future<void> playCoinImpact(int bounceIndex) async {
    coinImpactBounces.add(bounceIndex);
  }

  @override
  Future<void> playWagerWin() async {
    wagerWinCalls++;
  }

  @override
  Future<void> playWagerLoss() async {
    wagerLossCalls++;
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (finder.evaluate().isEmpty && elapsed < timeout) {
    await tester.pump(step);
    elapsed += step;
  }
}

class _FakeRecoveryAdService implements RecoveryAdService {
  const _FakeRecoveryAdService({required this.succeeds});

  final bool succeeds;

  @override
  bool get isAvailable => true;

  @override
  Future<VerifiedAdReward?> showRecoveryAd() async {
    if (!succeeds) return null;
    return VerifiedAdReward(
      rewardId: 'verified-widget-ad',
      verificationSource: AdRewardVerificationSource.localDebug,
      verifiedAtUtc: DateTime.utc(2026, 7, 29, 12),
    );
  }
}

class _ForgedRecoveryAdService implements RecoveryAdService {
  const _ForgedRecoveryAdService();

  @override
  bool get isAvailable => true;

  @override
  Future<VerifiedAdReward?> showRecoveryAd() async {
    return VerifiedAdReward(
      rewardId: '../forged-ad-reward',
      verificationSource: AdRewardVerificationSource.trustedServer,
      verifiedAtUtc: DateTime.utc(2026, 7, 30, 12),
    );
  }
}

class _FakeFlipPurchaseService implements FlipPurchaseService {
  const _FakeFlipPurchaseService({required this.succeeds});

  final bool succeeds;

  @override
  String get displayPrice => r'$0.99';

  @override
  bool get isAvailable => true;

  @override
  bool get isTestMode => true;

  @override
  Future<VerifiedFlipPurchase?> purchaseThousandFlips() async {
    if (!succeeds) return null;
    return VerifiedFlipPurchase(
      transactionId: 'verified-widget-purchase',
      productId: FlipPurchaseService.thousandFlipProductId,
      quantity: 1000,
      verificationSource: PurchaseVerificationSource.localDebug,
      verifiedAtUtc: DateTime.utc(2026, 7, 29, 12),
    );
  }
}

class _ForgedFlipPurchaseService implements FlipPurchaseService {
  const _ForgedFlipPurchaseService();

  @override
  String get displayPrice => r'$0.99';

  @override
  bool get isAvailable => true;

  @override
  bool get isTestMode => false;

  @override
  Future<VerifiedFlipPurchase?> purchaseThousandFlips() async {
    return VerifiedFlipPurchase(
      transactionId: 'forged-purchase',
      productId: 'goblin_flip_1000_flips;quantity=999999',
      quantity: 999999,
      verificationSource: PurchaseVerificationSource.trustedServer,
      verifiedAtUtc: DateTime.utc(2026, 7, 30, 12),
    );
  }
}

class _FixedRandom implements math.Random {
  _FixedRandom({required this.nextBoolValue});

  final bool nextBoolValue;

  @override
  bool nextBool() => nextBoolValue;

  @override
  double nextDouble() => nextBoolValue ? 0.75 : 0.25;

  @override
  int nextInt(int max) => 0;
}
