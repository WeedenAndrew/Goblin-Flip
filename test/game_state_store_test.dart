import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/game_state.dart';
import 'package:goblin_flip/game_state_store.dart';

void main() {
  const primaryKey = 'goblin_flip.game_state.v1';
  const backupKey = 'goblin_flip.game_state.backup.v1';
  const integrityKey = 'goblin_flip.game_state.integrity_key.v1';
  const revisionHeadKey = 'goblin_flip.game_state.revision_head.v1';
  final now = DateTime.utc(2026, 7, 29, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('creates, saves, and reloads encrypted state values', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    final changed = initial.recordNormalFlip(now);

    await store.save(changed);
    final restored = await store.load();

    expect(restored.flipBalance, 1);
    expect(restored.revision, 1);
  });

  test('restores the backup when the primary JSON is corrupt', () async {
    final backup = GameState.initial(
      now: now,
    ).copyWith(flipBalance: 42).encode();
    FlutterSecureStorage.setMockInitialValues({
      primaryKey: '{not-json',
      backupKey: backup,
    });

    final store = SecureGameStateStore(clock: () => now);
    final restored = await store.load();

    expect(restored.flipBalance, 42);
  });

  test(
    'reload refills all recovery charges 24 hours after the last use',
    () async {
      final lastUse = now.subtract(const Duration(hours: 24));
      final depleted = GameState.initial(now: lastUse).copyWith(
        recoveryChargesRemaining: 0,
        lastRecoveryUsedAtUtc: lastUse,
      );
      FlutterSecureStorage.setMockInitialValues({
        primaryKey: depleted.encode(),
        backupKey: depleted.encode(),
      });

      final store = SecureGameStateStore(clock: () => now);
      final restored = await store.load();

      expect(restored.recoveryChargesRemaining, 3);
      expect(restored.lastRecoveryUsedAtUtc, isNull);
    },
  );

  test('refuses to silently reset when both copies are corrupt', () async {
    FlutterSecureStorage.setMockInitialValues({
      primaryKey: '{bad-primary',
      backupKey: '{bad-backup',
    });

    final store = SecureGameStateStore(clock: () => now);

    expect(store.load(), throwsA(isA<GameStateStorageException>()));
  });

  test('signs and restores a legitimate purchased counter increase', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    final purchased = initial.creditVerifiedThousandFlipPurchase(
      transactionId: 'store-purchase-1',
      now: now,
    );

    await store.save(purchased);
    final restored = await store.load();

    expect(restored.flipBalance, 1000);
    expect(restored.processedPurchaseIds, ['store-purchase-1']);
  });

  test(
    'accepts legitimate wager, power-up, and rewarded-ad transitions',
    () async {
      final store = SecureGameStateStore(clock: () => now);
      var state = await store.load();

      state = state.creditVerifiedThousandFlipPurchase(
        transactionId: 'store-purchase-flow',
        now: now,
      );
      await store.save(state);
      state = state.purchasePowerup(PowerupType.insurance, now);
      await store.save(state);
      state = state.purchaseSpeedFlip(
        id: 'speed-flow',
        guess: WagerSide.heads,
        results: const [
          WagerSide.heads,
          WagerSide.tails,
          WagerSide.heads,
          WagerSide.tails,
          WagerSide.heads,
        ],
        now: now,
      );
      await store.save(state);
      state = state.clearPendingSpeedFlip(now);
      await store.save(state);
      state = state.placeWager(
        id: 'wager-flow',
        betAmount: 100,
        guess: WagerSide.heads,
        now: now,
      );
      await store.save(state);
      state = state.resolvePendingWager(WagerSide.tails, now);
      await store.save(state);
      state = state.clearResolvedWager(now);
      await store.save(state);
      state = state.creditVerifiedThousandFlipAd(
        rewardId: 'reward-flow',
        now: now,
      );
      await store.save(state);
      state = state.purchasePowerup(PowerupType.rollBackTime, now);
      await store.save(state);

      final restored = await store.load();
      expect(restored.encode(), state.encode());
    },
  );

  test('accepts a verified charged high-balance loss reversion', () async {
    final store = SecureGameStateStore(clock: () => now);
    var state = await store.load();
    for (var purchase = 0; purchase < 12; purchase++) {
      state = state.creditVerifiedThousandFlipPurchase(
        transactionId: 'high-balance-purchase-$purchase',
        now: now,
      );
      await store.save(state);
    }
    state = state.purchasePowerup(PowerupType.insurance, now);
    await store.save(state);
    final balanceBeforeWager = state.flipBalance;
    state = state.placeWager(
      id: 'high-balance-all-in',
      betAmount: balanceBeforeWager,
      guess: WagerSide.heads,
      now: now,
    );
    await store.save(state);
    state = state.resolvePendingWager(WagerSide.tails, now);
    await store.save(state);
    state = state.creditVerifiedInsuredAllInRecovery(
      rewardId: 'high-balance-recovery',
      now: now,
    );
    await store.save(state);

    final restored = await store.load();
    expect(restored.flipBalance, balanceBeforeWager);
    expect(restored.pendingWager, isNull);
    expect(restored.recoveryChargesRemaining, 2);
  });

  test('rejects a direct counter increase with no legitimate event', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    final sameRevisionInjection = initial.copyWith(
      flipBalance: 999999,
      updatedAtUtc: now,
    );
    final forgedRevisionInjection = initial.copyWith(
      flipBalance: 999999,
      revision: initial.revision + 1,
      updatedAtUtc: now,
    );

    expect(
      store.save(sameRevisionInjection),
      throwsA(isA<GameStateStorageException>()),
    );
    expect(
      store.save(forgedRevisionInjection),
      throwsA(isA<GameStateStorageException>()),
    );
    expect((await store.load()).flipBalance, 0);
  });

  test('rejects direct recovery-charge injection', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    final injected = initial.copyWith(
      recoveryChargesRemaining: 0,
      revision: initial.revision + 1,
      updatedAtUtc: now,
    );

    expect(
      store.save(injected),
      throwsA(isA<GameStateStorageException>()),
    );
    expect((await store.load()).recoveryChargesRemaining, 3);
  });

  test('repairs a corrupt signed primary from the signed backup', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    await store.save(initial.recordNormalFlip(now));
    const storage = FlutterSecureStorage();
    final expectedBackup = await storage.read(key: backupKey);
    await storage.write(key: primaryKey, value: '{corrupt-envelope');

    final reopened = SecureGameStateStore(clock: () => now);
    final restored = await reopened.load();

    expect(restored.flipBalance, 1);
    expect(await storage.read(key: primaryKey), expectedBackup);
  });

  test('rejects counter JSON injection when the MAC is unchanged', () async {
    final store = SecureGameStateStore(clock: () => now);
    await store.load();
    const storage = FlutterSecureStorage();
    final envelope =
        jsonDecode((await storage.read(key: primaryKey))!)
            as Map<String, dynamic>;
    final payload =
        jsonDecode(envelope['payload'] as String) as Map<String, dynamic>;
    payload['flipBalance'] = 999999;
    envelope['payload'] = jsonEncode(payload);
    final injectedEnvelope = jsonEncode(envelope);
    await storage.write(key: primaryKey, value: injectedEnvelope);
    await storage.write(key: backupKey, value: injectedEnvelope);

    final reopened = SecureGameStateStore(clock: () => now);
    expect(reopened.load(), throwsA(isA<GameStateStorageException>()));
  });

  test('rejects rollback to an older correctly signed counter', () async {
    final store = SecureGameStateStore(clock: () => now);
    final initial = await store.load();
    const storage = FlutterSecureStorage();
    final oldEnvelope = await storage.read(key: primaryKey);
    await store.save(initial.recordNormalFlip(now));

    await storage.write(key: primaryKey, value: oldEnvelope);
    await storage.write(key: backupKey, value: oldEnvelope);

    final reopened = SecureGameStateStore(clock: () => now);
    expect(reopened.load(), throwsA(isA<GameStateStorageException>()));
  });

  test('does not reset when the signed ledger is deleted', () async {
    final store = SecureGameStateStore(clock: () => now);
    await store.load();
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: integrityKey), isNotNull);
    expect(await storage.read(key: revisionHeadKey), '0');

    await storage.delete(key: primaryKey);
    await storage.delete(key: backupKey);

    final reopened = SecureGameStateStore(clock: () => now);
    expect(reopened.load(), throwsA(isA<GameStateStorageException>()));
  });
}
