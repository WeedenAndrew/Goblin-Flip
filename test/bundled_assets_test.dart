import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('release media and font assets are bundled locally', () async {
    const assetPaths = <String>[
      'assets/audio/forest_pathway_reel_1.mp3',
      'assets/backgrounds/forest_backdrop_v2.png',
      'assets/backgrounds/table_foreground_v2.png',
      'assets/characters/goblin_gambler_v4.png',
      'assets/fonts/cinzel/static/Cinzel-Regular.ttf',
      'assets/fonts/cinzel/static/Cinzel-Black.ttf',
      'assets/fonts/cinzel/OFL.txt',
      'assets/fonts/cinzel_decorative/CinzelDecorative-Regular.ttf',
      'assets/fonts/cinzel_decorative/CinzelDecorative-Black.ttf',
      'assets/fonts/cinzel_decorative/OFL.txt',
      'assets/fonts/almendra/Almendra-Regular.ttf',
      'assets/fonts/almendra/Almendra-Bold.ttf',
      'assets/fonts/almendra/OFL.txt',
    ];

    for (final path in assetPaths) {
      final asset = await rootBundle.load(path);
      expect(
        asset.lengthInBytes,
        greaterThan(1000),
        reason: '$path should be a real bundled asset.',
      );
    }
  });
}
