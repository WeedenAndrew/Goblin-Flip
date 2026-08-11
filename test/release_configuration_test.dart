import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release configuration', () {
    test('Android release never falls back to debug signing', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(
        gradle,
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
      );
      expect(gradle, contains('minSdk = maxOf(23, flutter.minSdkVersion)'));
      expect(gradle, contains('compileSdk = 36'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, contains('ndkVersion = "27.0.12077973"'));
      expect(gradle, contains('hasReleaseSigning'));
    });

    test('Android release data is excluded from device backups', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, isNot(contains('android.permission.INTERNET')));
    });

    test('Play bundle script pins permanent identity and requires signing', () {
      final script = File('Build Play Bundle.cmd').readAsStringSync();

      expect(script, contains('com.AIO.goblinFlip'));
      expect(script, contains('android\\key.properties'));
      expect(script, contains('call "%FLUTTER_CMD%" analyze'));
      expect(script, contains('build appbundle --release'));
    });

    test('unused prototype dependencies stay out of the package manifest', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('cupertino_icons:')));
      expect(pubspec, isNot(contains('google_fonts:')));
    });

    test('public repository rules exclude local signing material', () {
      final gitignore = File('.gitignore').readAsStringSync();
      final editorSettings = File('.vscode/settings.json').readAsStringSync();

      for (final ignoredPath in <String>[
        '/android/local.properties',
        '/android/key.properties',
        '*.jks',
        '*.keystore',
        '.env',
        '.env.*',
        '*.pem',
        '*.p12',
        '*.pfx',
        'secrets.*',
      ]) {
        expect(gitignore, contains(ignoredPath));
      }
      expect(editorSettings, isNot(contains('dart.flutterSdkPath')));
    });

    test('public helper files contain no machine-specific paths', () {
      final publicFiles = <String>[
        'README.md',
        'ROADMAP.md',
        '.vscode/settings.json',
        'Build Android APK.cmd',
        'Build Play Bundle.cmd',
        'Create Upload Key.cmd',
        'Install Android APK.cmd',
        'Run Goblin Flip.cmd',
        'Test Goblin Flip.cmd',
        'docs/architecture.md',
        'docs/commerce_security.md',
        'docs/release_readiness.md',
        'web/index.html',
        'web/manifest.json',
      ];

      for (final path in publicFiles) {
        final contents = File(path).readAsStringSync();
        expect(contents, isNot(contains(r'C:\Users\')));
        expect(contents, isNot(contains('dart.flutterSdkPath')));
      }
    });

    test('the web preview carries project identity, not template text', () {
      final page = File('web/index.html').readAsStringSync();
      final rawManifest = File('web/manifest.json').readAsStringSync();

      for (final scaffolding in <String>[page, rawManifest]) {
        expect(scaffolding, isNot(contains('A new Flutter project')));
        expect(scaffolding, isNot(contains('com.example')));
        // The package name is lowercase with an underscore; the public-facing
        // name is 'Goblin Flip'.
        expect(scaffolding, isNot(contains('goblin_flip')));
      }
      expect(page, contains('<title>Goblin Flip (development preview)</title>'));

      final manifest =
          jsonDecode(rawManifest) as Map<String, Object?>;
      expect(manifest['name'], 'Goblin Flip');
      expect(manifest['short_name'], 'Goblin Flip');

      final icons = manifest['icons']! as List<Object?>;
      expect(icons, isNotEmpty);
      for (final entry in icons) {
        final icon = entry! as Map<String, Object?>;
        final source = icon['src']! as String;
        expect(
          File('web/$source').existsSync(),
          isTrue,
          reason: '$source is referenced by the manifest but is not on disk.',
        );
      }
    });

    test('iOS release and profile builds retain keychain access', () {
      for (final path in <String>[
        'ios/Runner/Release.entitlements',
        'ios/Runner/DebugProfile.entitlements',
      ]) {
        final entitlements = File(path).readAsStringSync();
        expect(entitlements, contains('<key>keychain-access-groups</key>'));
        expect(entitlements, contains('<array/>'));
      }
    });
  });
}
