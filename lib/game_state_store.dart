import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'game_state.dart';
import 'game_state_transition_validator.dart';

abstract interface class GameStateStore {
  Future<GameState> load();

  Future<void> save(GameState state);
}

class SecureGameStateStore implements GameStateStore {
  SecureGameStateStore({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(migrateWithBackup: true),
           ),
       _clock = clock ?? DateTime.now;

  static const _primaryKey = 'goblin_flip.game_state.v1';
  static const _backupKey = 'goblin_flip.game_state.backup.v1';
  static const _integrityKey = 'goblin_flip.game_state.integrity_key.v1';
  static const _revisionHeadKey = 'goblin_flip.game_state.revision_head.v1';
  static const _envelopeVersion = 1;
  static const _integrityKeyBytes = 32;

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  Future<void> _saveQueue = Future<void>.value();

  @override
  Future<GameState> load() async {
    await _saveQueue;
    final primary = await _storage.read(key: _primaryKey);
    final backup = await _storage.read(key: _backupKey);
    final encodedIntegrityKey = await _storage.read(key: _integrityKey);

    if (primary == null && backup == null) {
      final revisionHead = await _storage.read(key: _revisionHeadKey);
      if (encodedIntegrityKey != null || revisionHead != null) {
        throw const GameStateStorageException(
          'The signed balance ledger is missing.',
        );
      }
      final initial = GameState.initial(now: _clock());
      final integrityKey = await _loadOrCreateIntegrityKey();
      await _writeSignedState(initial, integrityKey);
      return initial;
    }

    if (encodedIntegrityKey == null) {
      return _migrateLegacyState(primary, backup);
    }

    final integrityKey = _decodeIntegrityKey(encodedIntegrityKey);
    final storedState = _newestSignedState(primary, backup, integrityKey);
    final revisionHead = await _readRevisionHead();
    if (revisionHead != null && storedState.revision < revisionHead) {
      throw const GameStateStorageException(
        'A rolled-back game-state revision was rejected.',
      );
    }
    final state = storedState.rechargeRecoveryChargesIfDue(_clock());

    final expectedEnvelope = _encodeSignedState(state, integrityKey);
    if (primary != expectedEnvelope ||
        backup != expectedEnvelope ||
        revisionHead != state.revision) {
      await _writeSignedState(state, integrityKey);
    }
    return state;
  }

  @override
  Future<void> save(GameState state) {
    final queuedSave = _saveQueue.then((_) => _saveNow(state));
    _saveQueue = queuedSave.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return queuedSave;
  }

  Future<void> _saveNow(GameState state) async {
    final encodedIntegrityKey = await _storage.read(key: _integrityKey);
    final current = await _storage.read(key: _primaryKey);
    final backup = await _storage.read(key: _backupKey);

    late final List<int> integrityKey;
    GameState? previous;
    if (encodedIntegrityKey == null) {
      previous = _newestLegacyState(current, backup);
      integrityKey = await _loadOrCreateIntegrityKey();
    } else {
      integrityKey = _decodeIntegrityKey(encodedIntegrityKey);
      if (current != null || backup != null) {
        previous = _newestSignedState(current, backup, integrityKey);
      }
    }

    final revisionHead = await _readRevisionHead();
    if (revisionHead != null && state.revision < revisionHead) {
      throw const GameStateStorageException(
        'A stale game-state revision was rejected.',
      );
    }

    if (previous == null) {
      if (!GameStateTransitionValidator.isInitialState(state)) {
        throw const GameStateStorageException(
          'A non-initial balance cannot create a new ledger.',
        );
      }
    } else if (!GameStateTransitionValidator.isAllowed(previous, state)) {
      throw const GameStateStorageException(
        'The game-state balance transition was rejected.',
      );
    }

    await _writeSignedState(state, integrityKey);
  }

  Future<GameState> _migrateLegacyState(String? primary, String? backup) async {
    final storedState = _newestLegacyState(primary, backup);
    if (storedState == null) {
      throw const GameStateStorageException(
        'Both encrypted legacy game-state copies are unreadable.',
      );
    }

    final state = storedState.rechargeRecoveryChargesIfDue(_clock());
    final integrityKey = await _loadOrCreateIntegrityKey();
    await _writeSignedState(state, integrityKey);
    return state;
  }

  GameState? _newestLegacyState(String? primary, String? backup) {
    GameState? primaryState;
    GameState? backupState;
    Object? primaryError;
    Object? backupError;

    if (primary != null) {
      try {
        primaryState = GameState.decode(primary);
      } on Object catch (error) {
        primaryError = error;
      }
    }
    if (backup != null) {
      try {
        backupState = GameState.decode(backup);
      } on Object catch (error) {
        backupError = error;
      }
    }

    if (primaryState == null && backupState == null) {
      if (primary != null || backup != null) {
        throw GameStateStorageException(
          'Both encrypted game-state copies are unreadable.',
          primaryError: primaryError,
          backupError: backupError,
        );
      }
      return null;
    }
    return _newestState(primaryState, backupState);
  }

  GameState _newestSignedState(
    String? primary,
    String? backup,
    List<int> integrityKey,
  ) {
    GameState? primaryState;
    GameState? backupState;
    Object? primaryError;
    Object? backupError;

    if (primary != null) {
      try {
        primaryState = _decodeSignedState(primary, integrityKey);
      } on Object catch (error) {
        primaryError = error;
      }
    }
    if (backup != null) {
      try {
        backupState = _decodeSignedState(backup, integrityKey);
      } on Object catch (error) {
        backupError = error;
      }
    }

    if (primaryState == null && backupState == null) {
      throw GameStateStorageException(
        'Both signed game-state copies failed integrity verification.',
        primaryError: primaryError,
        backupError: backupError,
      );
    }
    return _newestState(primaryState, backupState)!;
  }

  GameState? _newestState(GameState? first, GameState? second) {
    if (first == null) return second;
    if (second == null) return first;
    if (first.revision == second.revision &&
        first.encode() != second.encode()) {
      throw const GameStateStorageException(
        'Conflicting game states share the same revision.',
      );
    }
    return first.revision >= second.revision ? first : second;
  }

  Future<int?> _readRevisionHead() async {
    final encoded = await _storage.read(key: _revisionHeadKey);
    if (encoded == null) return null;
    final revision = int.tryParse(encoded);
    if (revision == null || revision < 0) {
      throw const GameStateStorageException(
        'The secure revision head is invalid.',
      );
    }
    return revision;
  }

  Future<List<int>> _loadOrCreateIntegrityKey() async {
    final encoded = await _storage.read(key: _integrityKey);
    if (encoded != null) return _decodeIntegrityKey(encoded);

    final random = Random.secure();
    final key = List<int>.generate(
      _integrityKeyBytes,
      (_) => random.nextInt(256),
      growable: false,
    );
    await _storage.write(key: _integrityKey, value: base64UrlEncode(key));
    return key;
  }

  List<int> _decodeIntegrityKey(String encoded) {
    try {
      final key = base64Url.decode(base64Url.normalize(encoded));
      if (key.length != _integrityKeyBytes) {
        throw const FormatException('Invalid integrity key length.');
      }
      return key;
    } on Object catch (error) {
      throw GameStateStorageException(
        'The secure integrity key is invalid.',
        primaryError: error,
      );
    }
  }

  Future<void> _writeSignedState(
    GameState state,
    List<int> integrityKey,
  ) async {
    final envelope = _encodeSignedState(state, integrityKey);
    await _storage.write(key: _backupKey, value: envelope);
    await _storage.write(key: _primaryKey, value: envelope);
    await _storage.write(
      key: _revisionHeadKey,
      value: state.revision.toString(),
    );
  }

  String _encodeSignedState(GameState state, List<int> integrityKey) {
    final payload = state.encode();
    final mac = Hmac(sha256, integrityKey).convert(utf8.encode(payload));
    return jsonEncode({
      'formatVersion': _envelopeVersion,
      'payload': payload,
      'mac': mac.toString(),
    });
  }

  GameState _decodeSignedState(String encoded, List<int> integrityKey) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['formatVersion'] != _envelopeVersion ||
        decoded['payload'] is! String ||
        decoded['mac'] is! String) {
      throw const FormatException('Invalid signed game-state envelope.');
    }

    final payload = decoded['payload'] as String;
    final storedMac = decoded['mac'] as String;
    final expectedMac = Hmac(
      sha256,
      integrityKey,
    ).convert(utf8.encode(payload)).toString();
    if (!_constantTimeEquals(storedMac, expectedMac)) {
      throw const FormatException('Game-state integrity check failed.');
    }
    return GameState.decode(payload);
  }

  bool _constantTimeEquals(String first, String second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }
}

class GameStateStorageException implements Exception {
  const GameStateStorageException(
    this.message, {
    this.primaryError,
    this.backupError,
  });

  final String message;
  final Object? primaryError;
  final Object? backupError;

  @override
  String toString() => 'GameStateStorageException: $message';
}
