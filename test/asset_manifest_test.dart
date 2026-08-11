import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Automated replacement for eyeballing artwork in the Chrome preview.
///
/// The web preview is still the way to judge how art *looks*. These tests cover
/// the mechanical failures it is otherwise used to catch: an asset added to the
/// folder but never declared, a declared path that no longer exists, a
/// truncated font file, or a font family name that silently falls back to the
/// platform default.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final declarations = _parsePubspecFlutterSection();
  final declaredAssets = declarations.assets;
  final declaredFonts = declarations.fonts;

  test('the pubspec parse actually found the declared manifest', () {
    // Guards every test below: a parser that silently matched nothing would
    // otherwise make the whole suite pass vacuously.
    expect(
      declaredAssets.length,
      greaterThanOrEqualTo(15),
      reason: 'Expected the asset list to be parsed out of pubspec.yaml.',
    );
    expect(
      declaredFonts.keys,
      containsAll(<String>['Cinzel', 'Cinzel Decorative', 'Almendra']),
    );
    for (final family in declaredFonts.keys) {
      expect(
        declaredFonts[family],
        isNotEmpty,
        reason: '$family was parsed with no font files.',
      );
    }
  });

  test(
    'every asset declared in pubspec.yaml is bundled and loadable',
    () async {
      for (final declaration in declaredAssets) {
        if (declaration.endsWith('/')) {
          final directory = Directory(declaration);
          expect(
            directory.existsSync(),
            isTrue,
            reason: '$declaration is declared but the folder is missing.',
          );
          for (final file in directory.listSync().whereType<File>()) {
            final assetPath = _toAssetPath(file.path);
            final bytes = await rootBundle.load(assetPath);
            expect(
              bytes.lengthInBytes,
              greaterThan(0),
              reason: '$assetPath is bundled but empty.',
            );
          }
          continue;
        }

        expect(
          File(declaration).existsSync(),
          isTrue,
          reason:
              '$declaration is declared in pubspec.yaml but is not on disk.',
        );
        final bytes = await rootBundle.load(declaration);
        expect(
          bytes.lengthInBytes,
          greaterThan(0),
          reason: '$declaration is bundled but empty.',
        );
      }
    },
  );

  test('every declared font file is present and is a real font', () {
    // sfnt version tags: 0x00010000 (TrueType), 'OTTO' (CFF), 'true' (legacy).
    const sfntTags = <List<int>>[
      <int>[0x00, 0x01, 0x00, 0x00],
      <int>[0x4F, 0x54, 0x54, 0x4F],
      <int>[0x74, 0x72, 0x75, 0x65],
    ];

    for (final family in declaredFonts.keys) {
      for (final fontPath in declaredFonts[family]!) {
        final file = File(fontPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$family declares $fontPath, which is not on disk.',
        );
        expect(
          file.lengthSync(),
          greaterThan(1000),
          reason: '$fontPath is too small to be a usable font.',
        );
        final header = file.openSync().readSync(4);
        expect(
          sfntTags.any(
            (tag) => tag.indexed.every((entry) => header[entry.$1] == entry.$2),
          ),
          isTrue,
          reason: '$fontPath does not start with a known sfnt version tag.',
        );
      }
    }
  });

  test('no media or font file under assets/ is missing from the manifest', () {
    const trackedExtensions = <String>[
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.gif',
      '.mp3',
      '.wav',
      '.ogg',
      '.ttf',
      '.otf',
    ];

    final covered = <String>{
      ...declaredAssets.where((asset) => !asset.endsWith('/')),
      for (final family in declaredFonts.keys) ...declaredFonts[family]!,
    };
    final coveredDirectories = declaredAssets
        .where((asset) => asset.endsWith('/'))
        .toList(growable: false);

    final undeclared = <String>[];
    for (final entity in Directory('assets').listSync(recursive: true)) {
      if (entity is! File) continue;
      final assetPath = _toAssetPath(entity.path);
      final isTracked = trackedExtensions.any(assetPath.endsWith);
      if (!isTracked) continue;
      if (covered.contains(assetPath)) continue;
      if (coveredDirectories.any(assetPath.startsWith)) continue;
      undeclared.add(assetPath);
    }

    expect(
      undeclared,
      isEmpty,
      reason:
          'These files are in assets/ but no pubspec.yaml declaration bundles '
          'them, so they will be missing at runtime: ${undeclared.join(', ')}',
    );
  });

  test('every font family used by the game is declared in pubspec.yaml', () {
    final appSource = File('lib/goblin_flip_app.dart').readAsStringSync();
    final usedFamilies = RegExp(
      r"_style\(\s*'([^']+)'",
    ).allMatches(appSource).map((match) => match.group(1)!).toSet();

    expect(
      usedFamilies,
      isNotEmpty,
      reason: 'Expected _GameFonts to resolve families through _style.',
    );
    for (final family in usedFamilies) {
      expect(
        declaredFonts.keys,
        contains(family),
        reason:
            "'$family' is requested in code but not declared in pubspec.yaml, "
            'so it silently falls back to the platform default font.',
      );
    }
  });
}

/// Line-oriented reader for the `assets:` and `fonts:` blocks of pubspec.yaml.
///
/// The project keeps no YAML parser in its dependencies, and the manifest shape
/// here is fixed and shallow. `the pubspec parse actually found the declared
/// manifest` fails loudly if this ever stops matching.
({List<String> assets, Map<String, List<String>> fonts})
_parsePubspecFlutterSection() {
  final assets = <String>[];
  final fonts = <String, List<String>>{};
  final assetEntry = RegExp(r'^ {4}- (\S+)$');
  final familyEntry = RegExp(r'^ {4}- family: (.+)$');
  final fontAssetEntry = RegExp(r'^ {8}- asset: (\S+)$');

  var section = '';
  String? family;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    if (line.trim().isEmpty || line.trim().startsWith('#')) continue;

    if (line == '  assets:') {
      section = 'assets';
      family = null;
      continue;
    }
    if (line == '  fonts:') {
      section = 'fonts';
      family = null;
      continue;
    }

    if (section == 'assets') {
      final match = assetEntry.firstMatch(line);
      if (match != null) {
        assets.add(match.group(1)!);
        continue;
      }
      // Any other line at this depth ends the asset list.
      if (!line.startsWith('    ')) section = '';
    }

    if (section == 'fonts') {
      final familyMatch = familyEntry.firstMatch(line);
      if (familyMatch != null) {
        family = familyMatch.group(1)!.trim();
        fonts.putIfAbsent(family, () => <String>[]);
        continue;
      }
      final fontMatch = fontAssetEntry.firstMatch(line);
      if (fontMatch != null && family != null) {
        fonts[family]!.add(fontMatch.group(1)!);
      }
    }
  }

  return (assets: assets, fonts: fonts);
}

/// Normalizes a filesystem path into the forward-slash form pubspec.yaml and
/// the asset bundle both use, so these tests behave the same on Windows.
String _toAssetPath(String filePath) {
  final normalized = filePath.replaceAll(r'\', '/');
  final assetsIndex = normalized.indexOf('assets/');
  return assetsIndex <= 0 ? normalized : normalized.substring(assetsIndex);
}
