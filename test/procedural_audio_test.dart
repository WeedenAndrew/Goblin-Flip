import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/audio/game_audio_catalog.dart';
import 'package:goblin_flip/audio/procedural_audio.dart';

void main() {
  test('reviewed forest music uses the requested half-volume mix', () {
    expect(GameAudioCatalog.backgroundMusicVolume, 0.09);
    expect(
      GameAudioCatalog.backgroundMusicAsset,
      'audio/forest_pathway_reel_1.mp3',
    );
  });

  test('mobile sound effects mix without taking focus from forest music', () {
    final source = File(
      'lib/audio/game_audio_controller.dart',
    ).readAsStringSync();

    expect(source, contains('AudioContextConfigFocus.mixWithOthers'));
  });

  test('all procedural sounds are valid non-silent PCM wave files', () {
    final sounds = <String, Uint8List>{
      'goblin mumble': ProceduralGameAudio.goblinMumble,
      'wager win': ProceduralGameAudio.wagerWin,
      'wager loss': ProceduralGameAudio.wagerLoss,
    };
    expect(
      ProceduralGameAudio.coinImpacts,
      hasLength(ProceduralGameAudio.coinImpactCount),
    );
    for (
      var index = 0;
      index < ProceduralGameAudio.coinImpacts.length;
      index++
    ) {
      sounds['coin impact $index'] = ProceduralGameAudio.coinImpacts[index];
    }

    for (final MapEntry(key: name, value: audio) in sounds.entries) {
      expect(audio.length, greaterThan(1000), reason: '$name is too short.');
      expect(ascii.decode(audio.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(audio.sublist(8, 12)), 'WAVE');
      expect(ascii.decode(audio.sublist(36, 40)), 'data');

      final samples = ByteData.sublistView(audio, 44);
      var peak = 0;
      for (var offset = 0; offset < samples.lengthInBytes; offset += 2) {
        final amplitude = samples.getInt16(offset, Endian.little).abs();
        if (amplitude > peak) peak = amplitude;
      }
      expect(peak, greaterThan(500), reason: '$name is effectively silent.');
    }
  });
}
