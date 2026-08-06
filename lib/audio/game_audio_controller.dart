import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'game_audio_catalog.dart';
import 'procedural_audio.dart';

abstract interface class GameAudioController {
  bool get ambientMuted;

  Future<void> initialize();

  Future<void> ensureBackgroundMusic();

  Future<void> setAmbientMuted(bool muted);

  Future<void> playGoblinEntrance();

  Future<void> playCoinImpact(int bounceIndex);

  Future<void> playWagerWin();

  Future<void> playWagerLoss();

  Future<void> dispose();
}

class SilentGameAudioController implements GameAudioController {
  const SilentGameAudioController();

  @override
  bool get ambientMuted => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> ensureBackgroundMusic() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playGoblinEntrance() async {}

  @override
  Future<void> playCoinImpact(int bounceIndex) async {}

  @override
  Future<void> playWagerLoss() async {}

  @override
  Future<void> playWagerWin() async {}

  @override
  Future<void> setAmbientMuted(bool muted) async {}
}

abstract interface class AudioPreferenceStore {
  Future<bool> readAmbientMuted();

  Future<void> writeAmbientMuted(bool muted);
}

class SecureAudioPreferenceStore implements AudioPreferenceStore {
  SecureAudioPreferenceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _ambientMutedKey = 'goblin_flip_ambient_muted_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readAmbientMuted() async {
    try {
      return await _storage.read(key: _ambientMutedKey) == 'true';
    } on Object {
      return false;
    }
  }

  @override
  Future<void> writeAmbientMuted(bool muted) {
    return _storage.write(key: _ambientMutedKey, value: muted.toString());
  }
}

class AudioplayersGameAudioController implements GameAudioController {
  AudioplayersGameAudioController({AudioPreferenceStore? preferenceStore})
    : _preferenceStore = preferenceStore ?? SecureAudioPreferenceStore(),
      _musicPlayer = AudioPlayer(playerId: 'goblin-flip-music'),
      _goblinPlayer = AudioPlayer(playerId: 'goblin-flip-goblin'),
      _impactPlayers = List<AudioPlayer>.generate(
        ProceduralGameAudio.coinImpactCount,
        (index) => AudioPlayer(playerId: 'goblin-flip-impact-$index'),
        growable: false,
      ),
      _resultPlayer = AudioPlayer(playerId: 'goblin-flip-result');

  // Forty percent of the original impact mix: noticeable above the music
  // without dominating it.
  static const _coinImpactVolumes = <double>[0.288, 0.236, 0.192, 0.16];

  final AudioPreferenceStore _preferenceStore;
  final AudioPlayer _musicPlayer;
  final AudioPlayer _goblinPlayer;
  final List<AudioPlayer> _impactPlayers;
  final AudioPlayer _resultPlayer;

  bool _ambientMuted = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  bool get ambientMuted => _ambientMuted;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _ambientMuted = await _preferenceStore.readAmbientMuted();
    await _safely(
      () => AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      ),
    );
    await _safely(() => _musicPlayer.setReleaseMode(ReleaseMode.loop));
    await _safely(() => _goblinPlayer.setReleaseMode(ReleaseMode.stop));
    for (final impactPlayer in _impactPlayers) {
      await _safely(() => impactPlayer.setReleaseMode(ReleaseMode.stop));
    }
    await _safely(() => _resultPlayer.setReleaseMode(ReleaseMode.stop));
  }

  @override
  Future<void> ensureBackgroundMusic() async {
    if (_ambientMuted || _disposed) return;
    if (_musicPlayer.state == PlayerState.playing) return;

    if (_musicPlayer.state == PlayerState.paused) {
      await _safely(_musicPlayer.resume);
      return;
    }

    await _safely(
      () => _musicPlayer.play(
        AssetSource(GameAudioCatalog.backgroundMusicAsset),
        volume: GameAudioCatalog.backgroundMusicVolume,
      ),
    );
  }

  @override
  Future<void> setAmbientMuted(bool muted) async {
    if (_disposed) return;
    _ambientMuted = muted;
    await _safely(() => _preferenceStore.writeAmbientMuted(muted));
    if (muted) {
      await _safely(_musicPlayer.pause);
      await _safely(_goblinPlayer.stop);
      return;
    }
    await ensureBackgroundMusic();
  }

  @override
  Future<void> playGoblinEntrance() async {
    if (_ambientMuted || _disposed) return;
    await _safely(_goblinPlayer.stop);
    await _safely(
      () => _goblinPlayer.play(
        BytesSource(ProceduralGameAudio.goblinMumble, mimeType: 'audio/wav'),
        volume: 0.24,
      ),
    );
  }

  @override
  Future<void> playCoinImpact(int bounceIndex) async {
    if (_disposed) return;
    final index = bounceIndex
        .clamp(0, ProceduralGameAudio.coinImpactCount - 1)
        .toInt();
    final player = _impactPlayers[index];
    await _safely(
      () => player.play(
        BytesSource(
          ProceduralGameAudio.coinImpacts[index],
          mimeType: 'audio/wav',
        ),
        volume: _coinImpactVolumes[index],
      ),
    );
  }

  @override
  Future<void> playWagerWin() {
    return _playResult(ProceduralGameAudio.wagerWin, volume: 0.58);
  }

  @override
  Future<void> playWagerLoss() {
    return _playResult(ProceduralGameAudio.wagerLoss, volume: 0.56);
  }

  Future<void> _playResult(Uint8List audio, {required double volume}) async {
    if (_disposed) return;
    await _safely(_resultPlayer.stop);
    await _safely(
      () => _resultPlayer.play(
        BytesSource(audio, mimeType: 'audio/wav'),
        volume: volume,
      ),
    );
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Audio is decorative. A platform playback failure must not interrupt
      // ledger transitions or leave the game scene unusable.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _disposePlayer(_musicPlayer);
    await _disposePlayer(_goblinPlayer);
    for (final impactPlayer in _impactPlayers) {
      await _disposePlayer(impactPlayer);
    }
    await _disposePlayer(_resultPlayer);
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.dispose();
    } on Object {
      // Disposal remains best-effort for the same reason as playback.
    }
  }
}
