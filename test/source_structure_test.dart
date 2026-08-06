import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the game scene remains split into focused presentation modules', () {
    final entrypointSource = File('lib/main.dart').readAsStringSync();
    final appSource = File('lib/goblin_flip_app.dart').readAsStringSync();
    final presentationModules = <String>[
      'game_scene.dart',
      'audio_controls.dart',
      'coin_effects.dart',
      'goblin_overlays.dart',
      'wager_controls.dart',
      'powerup_status.dart',
      'speed_flip_dialogs.dart',
      'scroll_panels.dart',
      'wizard_shop.dart',
      'wager_sheet.dart',
    ];

    for (final module in presentationModules) {
      expect(
        appSource,
        contains("part 'presentation/$module';"),
        reason: '$module must remain connected to the main game library.',
      );
      expect(
        File('lib/presentation/$module').existsSync(),
        isTrue,
        reason: '$module is missing.',
      );
    }

    expect(entrypointSource, contains("export 'goblin_flip_app.dart';"));
    expect(entrypointSource.split('\n').length, lessThanOrEqualTo(15));
    expect(appSource, isNot(contains('class _GoldCoin')));
    expect(appSource, isNot(contains('class _GoblinDialogue')));
    expect(appSource, isNot(contains('class _WagerSheet')));
  });
}
