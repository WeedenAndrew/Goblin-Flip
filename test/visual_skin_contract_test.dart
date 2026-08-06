import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset-based UI art can replace surfaces without changing controls', () {
    final registry = File(
      'lib/presentation/visual_skins.dart',
    ).readAsStringSync();

    expect(registry, contains('class _SkinnableSurface'));
    expect(registry, contains('static const counterScroll'));
    expect(registry, contains('static const wagerScroll'));
    expect(registry, contains('static const wizardScroll'));
    expect(registry, contains('static const quickBetRail'));
    expect(registry, contains('assets/ui/skins/'));
    expect(registry, contains('if (assetPath == null)'));
    expect(registry, contains('Image.asset('));
  });

  test('quick wager selection remains separate from foundation artwork', () {
    final controls = File(
      'lib/presentation/wager_controls.dart',
    ).readAsStringSync();

    expect(controls, contains('class _StoneFoundationPainter'));
    expect(controls, contains('class _StoneSelectionPainter'));
    expect(controls, contains('selectedPercent: selectedPercent'));
  });
}
