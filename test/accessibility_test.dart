import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/game_state.dart';
import 'package:goblin_flip/game_state_store.dart';
import 'package:goblin_flip/main.dart';

/// Screen-reader and large-text coverage for the two menus a player spends
/// real flips from. A bare 'Buy' or '25%' announcement is not enough to tell
/// which charm is being bought or what fraction is being wagered.
void main() {
  Future<void> openWagerSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(
          GameState.initial().copyWith(flipBalance: 4000),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wager-scroll')), findsOneWidget);
  }

  Future<void> openWizardShop(WidgetTester tester) async {
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(
          GameState.initial().copyWith(flipBalance: 4000),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wizard-scroll')), findsOneWidget);
  }

  testWidgets('wager side buttons announce their side and selection', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openWagerSheet(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('wager-heads'))),
      isSemantics(label: 'Wager on Heads', isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('wager-tails'))),
      isSemantics(label: 'Wager on Tails', isSelected: false),
    );

    await tester.tap(find.byKey(const Key('wager-tails')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('wager-tails'))),
      isSemantics(label: 'Wager on Tails', isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('wager-heads'))),
      isSemantics(label: 'Wager on Heads', isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('quick bet buttons say what fraction they wager', (tester) async {
    final handle = tester.ensureSemantics();
    await openWagerSheet(tester);

    for (final entry in const <(String, String)>[
      ('wager-25-percent', 'Wager 25% of the balance'),
      ('wager-50-percent', 'Wager 50% of the balance'),
      ('wager-75-percent', 'Wager 75% of the balance'),
      ('wager-all-in', 'Wager the entire balance'),
    ]) {
      expect(
        tester.getSemantics(find.byKey(Key(entry.$1))),
        isSemantics(label: entry.$2),
        reason: '${entry.$1} should announce ${entry.$2}.',
      );
    }

    await tester.tap(find.byKey(const Key('wager-50-percent')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('wager-50-percent'))),
      isSemantics(label: 'Wager 50% of the balance', isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('charm buy buttons name the charm and its price', (tester) async {
    final handle = tester.ensureSemantics();
    await openWizardShop(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('buy-insurance'))),
      isSemantics(label: 'Buy Insurance for 100 flips'),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('buy-rollback'))),
      isSemantics(label: 'Buy Roll Back Time for 500 flips'),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('buy-speed-flip'))),
      isSemantics(label: 'Buy Speed Flip for 300 flips'),
    );
    handle.dispose();
  });

  testWidgets('a disabled charm announces its state instead of Buy', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      GoblinFlipApp(
        gameStateStore: _MemoryGameStateStore(
          GameState.initial().copyWith(
            flipBalance: 4000,
            rollBackTimeActive: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('buy-rollback'))),
      isSemantics(label: 'Roll Back Time: Active'),
    );
    handle.dispose();
  });

  testWidgets('the close controls say which panel they close', (tester) async {
    final handle = tester.ensureSemantics();
    await openWizardShop(tester);
    // IconButton surfaces its tooltip as the semantic tooltip, which is what
    // TalkBack and VoiceOver announce for an icon-only control.
    expect(
      tester.getSemantics(find.byKey(const Key('close-powerups'))),
      isSemantics(tooltip: "Close Wizard's Charms", isButton: true),
    );
    handle.dispose();
  });

  testWidgets('the wager sheet survives doubled text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GoblinFlipApp(
          gameStateStore: _MemoryGameStateStore(
            GameState.initial().copyWith(flipBalance: 4000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-wager')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wager-scroll')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('confirm-wager')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wizard shop survives doubled text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GoblinFlipApp(
          gameStateStore: _MemoryGameStateStore(
            GameState.initial().copyWith(flipBalance: 4000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-powerups')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wizard-scroll')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('buy-speed-flip')));
    expect(tester.takeException(), isNull);
  });
}

class _MemoryGameStateStore implements GameStateStore {
  _MemoryGameStateStore(this.state);

  GameState state;

  @override
  Future<GameState> load() async => state;

  @override
  Future<void> save(GameState state) async {
    this.state = state;
  }
}
