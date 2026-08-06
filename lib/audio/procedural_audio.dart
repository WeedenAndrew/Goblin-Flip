import 'dart:math' as math;
import 'dart:typed_data';

/// Original, deterministic sound effects synthesized for Goblin Flip.
///
/// Keeping short interaction sounds procedural makes every shipped effect
/// reproducible from reviewed source code.
abstract final class ProceduralGameAudio {
  static const _sampleRate = 12000;
  static const _tau = math.pi * 2;
  static const coinImpactCount = 4;

  static final Uint8List goblinMumble = _createGoblinMumble();
  static final List<Uint8List> coinImpacts = List<Uint8List>.generate(
    coinImpactCount,
    _createCoinImpact,
    growable: false,
  );
  static final Uint8List wagerWin = _createWagerWin();
  static final Uint8List wagerLoss = _createWagerLoss();

  static Uint8List _createGoblinMumble() {
    const duration = 2.35;
    final noise = _DeterministicNoise(0x60B11);
    var throatNoise = 0.0;

    return _encodeWave(duration, (time) {
      final envelope =
          _mumbleBurst(time, start: 0.06, length: 0.54) +
          _mumbleBurst(time, start: 0.76, length: 0.60) +
          _mumbleBurst(time, start: 1.52, length: 0.70);
      if (envelope == 0) return 0;

      final pitch =
          78 +
          8 * math.sin(_tau * 1.7 * time) +
          5 * math.sin(_tau * 3.4 * time);
      final glottal =
          math.sin(_tau * pitch * time) +
          0.44 * math.sin(_tau * pitch * 2 * time) +
          0.16 * math.sin(_tau * pitch * 3 * time);
      final nasal =
          0.18 * math.sin(_tau * 430 * time) +
          0.08 * math.sin(_tau * 760 * time);
      throatNoise = throatNoise * 0.72 + noise.nextSigned() * 0.28;

      return envelope * (glottal * 0.17 + nasal * 0.07 + throatNoise * 0.035);
    });
  }

  static double _mumbleBurst(
    double time, {
    required double start,
    required double length,
  }) {
    final local = time - start;
    if (local < 0 || local > length) return 0;
    final envelope = _attackRelease(local, length, attack: 0.09, release: 0.18);
    return envelope * (0.78 + 0.22 * math.sin(_tau * 5.2 * local));
  }

  static Uint8List _createCoinImpact(int bounceIndex) {
    const durations = <double>[0.22, 0.18, 0.145, 0.12];
    const pitchScales = <double>[0.92, 1.00, 1.09, 1.18];
    const ringDecays = <double>[17, 22, 29, 38];
    final duration = durations[bounceIndex];
    final pitchScale = pitchScales[bounceIndex];
    final ringDecay = ringDecays[bounceIndex];
    final noise = _DeterministicNoise(0xC01C1 + bounceIndex * 0x101);
    var previousNoise = 0.0;

    return _encodeWave(duration, (time) {
      final rawNoise = noise.nextSigned();
      final sharpNoise = rawNoise - previousNoise;
      previousNoise = rawNoise;

      final transient = math.exp(-68 * time) * sharpNoise;
      final surfaceClick =
          math.exp(-52 * time) *
          math.sin(_tau * 760 * pitchScale * time);
      final metalRing =
          math.exp(-ringDecay * time) *
          (math.sin(_tau * 1480 * pitchScale * time) +
              0.62 * math.sin(_tau * 2460 * pitchScale * time + 0.45) +
              0.31 * math.sin(_tau * 3820 * pitchScale * time + 1.10));

      return transient * 0.13 + surfaceClick * 0.12 + metalRing * 0.24;
    });
  }

  static Uint8List _createWagerWin() {
    const duration = 1.15;
    const frequency = 783.99;

    return _encodeWave(duration, (time) {
      final attack = 1 - math.exp(-90 * time);
      final decay = math.exp(-4.6 * time);
      final chime =
          math.sin(_tau * frequency * time) +
          0.38 * math.sin(_tau * frequency * 2.01 * time) +
          0.16 * math.sin(_tau * frequency * 3.98 * time);
      return attack * decay * chime * 0.22;
    });
  }

  static Uint8List _createWagerLoss() {
    const duration = 1.30;
    const notes = <double>[329.63, 277.18, 220.00, 164.81];
    final noise = _DeterministicNoise(0x1055);
    return _encodeWave(duration, (time) {
      var sample = 0.0;
      for (var index = 0; index < notes.length; index++) {
        final start = index * 0.22;
        final local = time - start;
        if (local < 0 || local > 0.48) continue;
        final decay = math.exp(-4.8 * local);
        final frequency = notes[index];
        sample +=
            decay *
            (math.sin(_tau * frequency * local) +
                0.30 * math.sin(_tau * frequency * 0.5 * local));
      }
      final thudTime = time - 0.76;
      final thud = thudTime < 0
          ? 0.0
          : math.exp(-7.5 * thudTime) *
                (math.sin(_tau * 72 * thudTime) + noise.nextSigned() * 0.10);
      return sample * 0.13 + thud * 0.22;
    });
  }

  static double _attackRelease(
    double time,
    double duration, {
    required double attack,
    required double release,
  }) {
    final attackLevel = (time / attack).clamp(0.0, 1.0);
    final releaseLevel = ((duration - time) / release).clamp(0.0, 1.0);
    return math.min(attackLevel, releaseLevel);
  }

  static Uint8List _encodeWave(
    double duration,
    double Function(double time) sampleAt,
  ) {
    final sampleCount = (duration * _sampleRate).round();
    final dataLength = sampleCount * 2;
    final bytes = ByteData(44 + dataLength);

    _writeAscii(bytes, 0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');
    _writeAscii(bytes, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    _writeAscii(bytes, 36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      final time = index / _sampleRate;
      final sample = sampleAt(time).clamp(-0.96, 0.96);
      bytes.setInt16(44 + index * 2, (sample * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static void _writeAscii(ByteData bytes, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}

class _DeterministicNoise {
  _DeterministicNoise(this._state);

  int _state;

  double nextSigned() {
    _state = (1664525 * _state + 1013904223) & 0xFFFFFFFF;
    return ((_state / 0xFFFFFFFF) * 2) - 1;
  }
}
