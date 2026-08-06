import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/game_state.dart';

void main() {
  group('GameState', () {
    Map<String, Object?> legacyJson(int schemaVersion) {
      return GameState.initial().toJson()
        ..['schemaVersion'] = schemaVersion
        ..remove('consecutiveWagerLosses')
        ..['recoveryChargesRemaining'] = 3
        ..['lastRecoveryUsedAtUtc'] = null;
    }

    test('unlocks the goblin once and preserves that flag', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final atFortyNine = GameState.initial(
        now: now,
      ).copyWith(flipBalance: 49);

      final unlocked = atFortyNine.recordNormalFlip(now);
      final spentDown = unlocked.copyWith(
        flipBalance: 0,
        goblinUnlocked: false,
      );
      final restored = GameState.decode(spentDown.encode());

      expect(unlocked.flipBalance, 50);
      expect(unlocked.goblinUnlocked, isTrue);
      expect(restored.flipBalance, 0);
      expect(restored.goblinUnlocked, isTrue);
    });

    test('locks the free counter at zero after the goblin is unlocked', () {
      final now = DateTime.utc(2026, 7, 30, 12);
      final beforeUnlock = GameState.initial(now: now);
      final afterUnlockAtZero = beforeUnlock.copyWith(
        flipBalance: 0,
        goblinUnlocked: true,
      );

      expect(beforeUnlock.recordNormalFlip(now).flipBalance, 1);
      expect(() => afterUnlockAtZero.recordNormalFlip(now), throwsStateError);
    });

    test('power-up prices scale from current balance and cap at 60%', () {
      final base = GameState.initial().copyWith(flipBalance: 9999);
      final tenThousand = base.copyWith(flipBalance: 10000);
      final twentyThousand = base.copyWith(flipBalance: 20000);
      final thirtyThousand = base.copyWith(flipBalance: 30000);
      final fortyThousand = base.copyWith(flipBalance: 40000);

      expect(base.powerupPrice(PowerupType.insurance), 100);
      expect(tenThousand.powerupPrice(PowerupType.insurance), 120);
      expect(twentyThousand.powerupPrice(PowerupType.insurance), 140);
      expect(thirtyThousand.powerupPrice(PowerupType.insurance), 160);
      expect(fortyThousand.powerupPrice(PowerupType.insurance), 160);
      expect(tenThousand.powerupPrice(PowerupType.speedFlip), 360);
      expect(thirtyThousand.powerupPrice(PowerupType.rollBackTime), 800);
    });

    test('only Insurance doubles after each persisted purchase', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final stocked = GameState.initial(now: now).copyWith(flipBalance: 100000);

      final insured = stocked.purchasePowerup(PowerupType.insurance, now);
      final spedUp = insured.purchaseSpeedFlip(
        id: 'speed-one',
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

      expect(insured.flipBalance, 99840);
      expect(insured.insuranceActive, isTrue);
      expect(insured.insuranceLevel, 1);
      expect(insured.insuranceCoveragePercent, 5);
      expect(insured.powerupPrice(PowerupType.insurance), 320);
      expect(insured.powerupPrice(PowerupType.speedFlip), 480);
      expect(spedUp.pendingSpeedFlip?.matchCount, 3);
      expect(spedUp.pendingSpeedFlip?.payoutAmount, 1440);
      expect(spedUp.flipBalance, 100800);
      expect(spedUp.powerupPrice(PowerupType.speedFlip), 480);

      final restored = GameState.decode(spedUp.encode());
      expect(restored.insuranceActive, isTrue);
      expect(
        restored.pendingSpeedFlip?.results,
        spedUp.pendingSpeedFlip?.results,
      );
      expect(restored.insuranceLevel, 1);
    });

    test('Insurance is permanent and caps at 60%', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      var state = GameState.initial(
        now: now,
      ).copyWith(flipBalance: GameState.maxSafeInteger);

      for (var level = 1; level <= GameState.maxInsuranceLevel; level++) {
        state = state.purchasePowerup(PowerupType.insurance, now);
        expect(state.insuranceLevel, level);
        expect(state.insuranceCoveragePercent, level * 5);
      }

      expect(state.insuranceCoveragePercent, 60);
      expect(
        () => state.purchasePowerup(PowerupType.insurance, now),
        throwsStateError,
      );
    });

    test('migrates schema-one saves with no armed power-ups', () {
      final legacy = legacyJson(1)
        ..remove('pendingSpeedFlip')
        ..remove('insuranceLevel')
        ..remove('rollBackTimeActive')
        ..remove('insurancePurchaseCount');

      final restored = GameState.fromJson(legacy);

      expect(restored.schemaVersion, GameState.currentSchemaVersion);
      expect(restored.insuranceActive, isFalse);
      expect(restored.rollBackTimeActive, isFalse);
      expect(restored.pendingSpeedFlip, isNull);
    });

    test('migrates schema-two inventory into permanent Insurance', () {
      final legacy = legacyJson(2)
        ..remove('pendingSpeedFlip')
        ..remove('insuranceLevel')
        ..remove('rollBackTimeActive')
        ..['insuranceInventory'] = 2
        ..['speedFlipInventory'] = 0
        ..['rollBackTimeInventory'] = 1
        ..['insurancePurchaseCount'] = 2;

      final restored = GameState.fromJson(legacy);

      expect(restored.insuranceActive, isTrue);
      expect(restored.rollBackTimeActive, isTrue);
      expect(restored.insuranceLevel, 2);
      expect(restored.insuranceCoveragePercent, 10);
    });

    test('migrates schema-three armed Insurance into a permanent level', () {
      final legacy = legacyJson(3)
        ..remove('insuranceLevel')
        ..['insuranceActive'] = true
        ..['insurancePurchaseCount'] = 3;

      final restored = GameState.fromJson(legacy);

      expect(restored.insuranceLevel, 3);
      expect(restored.insuranceCoveragePercent, 15);
    });

    test('migrates schema-four saves with empty receipt ledgers', () {
      final legacy = legacyJson(4)
        ..remove('processedPurchaseIds')
        ..remove('processedAdRewardIds');

      final restored = GameState.fromJson(legacy);

      expect(restored.processedPurchaseIds, isEmpty);
      expect(restored.processedAdRewardIds, isEmpty);
    });

    test('migrates schema-five saves with no wager loss streak', () {
      final restored = GameState.fromJson(legacyJson(5));

      expect(restored.schemaVersion, GameState.currentSchemaVersion);
      expect(restored.consecutiveWagerLosses, 0);
    });

    test('migrates schema-six saves with a fresh recovery cycle', () {
      final legacy = GameState.initial().toJson()
        ..['schemaVersion'] = 6
        ..remove('recoveryChargesRemaining')
        ..remove('lastRecoveryUsedAtUtc');

      final restored = GameState.fromJson(legacy);

      expect(restored.schemaVersion, GameState.currentSchemaVersion);
      expect(
        restored.recoveryChargesRemaining,
        GameState.maxRecoveryCharges,
      );
      expect(restored.lastRecoveryUsedAtUtc, isNull);
    });

    test('Roll Back Time triggers before Insurance on losses', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final armed = GameState.initial(now: now)
          .copyWith(flipBalance: 2000)
          .purchasePowerup(PowerupType.insurance, now)
          .purchasePowerup(PowerupType.rollBackTime, now);

      final firstLoss = armed
          .placeWager(
            id: 'protected-one',
            betAmount: 500,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);
      final afterRollback = firstLoss.clearResolvedWager(now);
      final secondLoss = afterRollback
          .placeWager(
            id: 'protected-two',
            betAmount: 500,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);

      expect(firstLoss.rollBackTimeActive, isFalse);
      expect(firstLoss.insuranceActive, isTrue);
      expect(firstLoss.flipBalance, armed.flipBalance);
      expect(
        firstLoss.pendingWager?.protectionApplied,
        WagerProtection.rollBackTime,
      );
      expect(
        GameState.decode(firstLoss.encode()).pendingWager?.protectionApplied,
        WagerProtection.rollBackTime,
      );
      expect(secondLoss.insuranceActive, isTrue);
      expect(secondLoss.flipBalance, afterRollback.flipBalance - 475);
      expect(
        secondLoss.pendingWager?.protectionApplied,
        WagerProtection.insurance,
      );
    });

    test('insurance always floors fractional protected flips', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final insured = GameState.initial(now: now).copyWith(
        flipBalance: 101,
        insuranceLevel: 1,
      );
      final resolved = insured
          .placeWager(
            id: 'floor-insurance',
            betAmount: 99,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);

      expect(resolved.flipBalance, 6);
      expect(
        resolved.pendingWager?.protectionApplied,
        WagerProtection.insurance,
      );
    });

    test('five consecutive losses unlock the offer and a win resets it', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      var state = GameState.initial(now: now).copyWith(flipBalance: 1000);

      for (var loss = 0; loss < GameState.lossStreakOfferThreshold; loss++) {
        state = state
            .placeWager(
              id: 'loss-$loss',
              betAmount: 10,
              guess: WagerSide.heads,
              now: now,
            )
            .resolvePendingWager(WagerSide.tails, now)
            .clearResolvedWager(now);
      }
      expect(
        state.consecutiveWagerLosses,
        GameState.lossStreakOfferThreshold,
      );

      final won = state
          .placeWager(
            id: 'streak-reset-win',
            betAmount: 10,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.heads, now);
      expect(won.consecutiveWagerLosses, 0);
    });

    test('a verified rewarded ad grants exactly 1000 flips once', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final initial = GameState.initial(now: now).copyWith(
        flipBalance: 25,
        consecutiveWagerLosses: 5,
      );

      final rewarded = initial.creditVerifiedThousandFlipAd(
        rewardId: 'ad-thousand-1',
        now: now,
      );

      expect(rewarded.flipBalance, 1025);
      expect(rewarded.consecutiveWagerLosses, 0);
      expect(rewarded.recoveryChargesRemaining, 3);
      expect(rewarded.processedAdRewardIds, ['ad-thousand-1']);
      expect(
        () => rewarded.creditVerifiedThousandFlipAd(
          rewardId: 'ad-thousand-1',
          now: now,
        ),
        throwsStateError,
      );
    });

    test('insured all-in above 10k can revert through a verified ad', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final resolved = GameState.initial(now: now)
          .copyWith(flipBalance: 12000, insuranceLevel: 1)
          .placeWager(
            id: 'high-insured-all-in',
            betAmount: 12000,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);

      expect(resolved.flipBalance, 600);
      final recovered = resolved.creditVerifiedInsuredAllInRecovery(
        rewardId: 'high-recovery-1',
        now: now,
      );

      expect(recovered.flipBalance, 12000);
      expect(recovered.pendingWager, isNull);
      expect(recovered.recoveryChargesRemaining, 2);
      expect(recovered.lastRecoveryUsedAtUtc, now);
      expect(recovered.consecutiveWagerLosses, 0);
      expect(recovered.processedAdRewardIds, ['high-recovery-1']);

      final replayLoss = recovered
          .placeWager(
            id: 'high-insured-replay-loss',
            betAmount: recovered.flipBalance,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);
      expect(
        () => replayLoss.creditVerifiedInsuredAllInRecovery(
          rewardId: 'high-recovery-1',
          now: now,
        ),
        throwsStateError,
      );
    });

    test('high-balance loss reversions use three charges and refill together', () {
      final start = DateTime.utc(2026, 7, 29, 12);
      var state = GameState.initial(
        now: start,
      ).copyWith(flipBalance: 12000, insuranceLevel: 1);

      for (var use = 0; use < GameState.maxRecoveryCharges; use++) {
        final now = start.add(Duration(hours: use));
        state = state
            .placeWager(
              id: 'charged-loss-$use',
              betAmount: state.flipBalance,
              guess: WagerSide.heads,
              now: now,
            )
            .resolvePendingWager(WagerSide.tails, now)
            .creditVerifiedInsuredAllInRecovery(
              rewardId: 'charged-reward-$use',
              now: now,
            );
      }
      expect(state.recoveryChargesRemaining, 0);

      final finalLossAt = start.add(const Duration(hours: 3));
      final finalLoss = state
          .placeWager(
            id: 'charged-loss-final',
            betAmount: state.flipBalance,
            guess: WagerSide.heads,
            now: finalLossAt,
          )
          .resolvePendingWager(WagerSide.tails, finalLossAt);
      expect(
        () => finalLoss.creditVerifiedInsuredAllInRecovery(
          rewardId: 'charged-reward-blocked',
          now: finalLossAt,
        ),
        throwsStateError,
      );

      final lastUse = state.lastRecoveryUsedAtUtc!;
      expect(
        finalLoss
            .rechargeRecoveryChargesIfDue(
              lastUse.add(const Duration(hours: 23, minutes: 59)),
            )
            .recoveryChargesRemaining,
        0,
      );
      final recharged = finalLoss.rechargeRecoveryChargesIfDue(
        lastUse.add(GameState.recoveryRechargePeriod),
      );
      expect(recharged.recoveryChargesRemaining, 3);
      expect(recharged.lastRecoveryUsedAtUtc, isNull);
    });

    test('10k or uninsured all-ins cannot use loss reversion', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final exactlyTenThousand = GameState.initial(now: now)
          .copyWith(flipBalance: 10000, insuranceLevel: 1)
          .placeWager(
            id: 'exact-threshold',
            betAmount: 10000,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);
      final uninsured = GameState.initial(now: now)
          .copyWith(flipBalance: 12000)
          .placeWager(
            id: 'uninsured-high-loss',
            betAmount: 12000,
            guess: WagerSide.heads,
            now: now,
          )
          .resolvePendingWager(WagerSide.tails, now);

      for (final state in [exactlyTenThousand, uninsured]) {
        expect(
          () => state.creditVerifiedInsuredAllInRecovery(
            rewardId: 'ineligible-recovery-${state.flipBalance}',
            now: now,
          ),
          throwsStateError,
        );
      }
    });

    test('a verified purchase credits exactly 1000 persisted flips once', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final initial = GameState.initial(now: now);

      final purchased = initial.creditVerifiedThousandFlipPurchase(
        transactionId: 'store-transaction-1',
        now: now,
      );

      expect(purchased.flipBalance, 1000);
      expect(purchased.goblinUnlocked, isTrue);
      expect(purchased.revision, initial.revision + 1);
      expect(purchased.updatedAtUtc, now);
      expect(purchased.processedPurchaseIds, ['store-transaction-1']);
      expect(
        () => purchased.creditVerifiedThousandFlipPurchase(
          transactionId: 'store-transaction-1',
          now: now,
        ),
        throwsStateError,
      );
      expect(GameState.decode(purchased.encode()).processedPurchaseIds, [
        'store-transaction-1',
      ]);
    });

    test('round-trips a crash-safe pending wager record', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final wager = PendingWager(
        id: 'wager-42',
        betAmount: 500,
        guess: WagerSide.tails,
        result: WagerSide.heads,
        createdAtUtc: now,
        resolvedAtUtc: now.add(const Duration(seconds: 1)),
        wasAllIn: true,
      );
      final encoded = GameState.initial(
        now: now,
      ).copyWith(pendingWager: wager).encode();

      final restored = GameState.decode(encoded);

      expect(restored.pendingWager?.id, 'wager-42');
      expect(restored.pendingWager?.betAmount, 500);
      expect(restored.pendingWager?.guess, WagerSide.tails);
      expect(restored.pendingWager?.result, WagerSide.heads);
      expect(restored.pendingWager?.isResolved, isTrue);
      expect(restored.pendingWager?.wasAllIn, isTrue);
      expect(
        restored.pendingWager?.resolvedAtUtc,
        now.add(const Duration(seconds: 1)),
      );
    });

    test('rejects invalid balances instead of silently resetting them', () {
      final state = GameState.initial().toJson();
      state['flipBalance'] = -1;

      expect(() => GameState.fromJson(state), throwsFormatException);
    });

    test('deducts a wager immediately and allows the entire balance', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final unlocked = GameState.initial(now: now).copyWith(flipBalance: 100);

      final placed = unlocked.placeWager(
        id: 'wager-all-in',
        betAmount: 100,
        guess: WagerSide.heads,
        now: now,
      );

      expect(placed.flipBalance, 0);
      expect(placed.pendingWager?.betAmount, 100);
      expect(placed.pendingWager?.isResolved, isFalse);
      expect(placed.pendingWager?.wasAllIn, isTrue);
      expect(placed.goblinUnlocked, isTrue);
    });

    test('rejects hostile wager loss-streak values', () {
      for (final hostileValue in <Object?>[-1, '5', null]) {
        final state = GameState.initial().toJson()
          ..['consecutiveWagerLosses'] = hostileValue;

        expect(
          () => GameState.fromJson(state),
          throwsFormatException,
          reason: 'Rejected hostile loss streak: $hostileValue',
        );
      }
    });

    test('rejects hostile recovery-cycle values', () {
      for (final hostileValue in <Object?>[-1, 4, '3', null]) {
        final state = GameState.initial().toJson()
          ..['recoveryChargesRemaining'] = hostileValue;
        expect(
          () => GameState.fromJson(state),
          throwsFormatException,
          reason: 'Rejected hostile recovery charges: $hostileValue',
        );
      }
      for (final hostileTimestamp in <Object?>[1234, 'not-a-date']) {
        final state = GameState.initial().toJson()
          ..['lastRecoveryUsedAtUtc'] = hostileTimestamp;
        expect(
          () => GameState.fromJson(state),
          throwsFormatException,
          reason: 'Rejected hostile recovery timestamp: $hostileTimestamp',
        );
      }
      final missingTimestamp = GameState.initial().toJson()
        ..['recoveryChargesRemaining'] = 2;
      expect(
        () => GameState.fromJson(missingTimestamp),
        throwsFormatException,
      );
    });

    test('rejects locked, invalid, unaffordable, and overlapping wagers', () {
      final now = DateTime.utc(2026, 7, 29, 12);
      final locked = GameState.initial(now: now).copyWith(flipBalance: 49);
      final unlocked = locked.copyWith(flipBalance: 50);
      final placed = unlocked.placeWager(
        id: 'wager-one',
        betAmount: 25,
        guess: WagerSide.tails,
        now: now,
      );

      expect(
        () => locked.placeWager(
          id: 'locked',
          betAmount: 1,
          guess: WagerSide.heads,
          now: now,
        ),
        throwsStateError,
      );
      expect(
        () => unlocked.placeWager(
          id: 'zero',
          betAmount: 0,
          guess: WagerSide.heads,
          now: now,
        ),
        throwsArgumentError,
      );
      expect(
        () => unlocked.placeWager(
          id: 'too-large',
          betAmount: 101,
          guess: WagerSide.heads,
          now: now,
        ),
        throwsStateError,
      );
      expect(
        () => placed.placeWager(
          id: 'overlap',
          betAmount: 1,
          guess: WagerSide.heads,
          now: now,
        ),
        throwsStateError,
      );
      expect(() => placed.recordNormalFlip(now), throwsStateError);
    });

    test('a winning wager pays exactly once even after crash recovery', () {
      final placedAt = DateTime.utc(2026, 7, 29, 12);
      final resolvedAt = placedAt.add(const Duration(seconds: 1));
      final unlocked = GameState.initial(
        now: placedAt,
      ).copyWith(flipBalance: 1000);
      final placed = unlocked.placeWager(
        id: 'wager-win',
        betAmount: 500,
        guess: WagerSide.heads,
        now: placedAt,
      );

      final restoredUnresolved = GameState.decode(placed.encode());
      final resolved = restoredUnresolved.resolvePendingWager(
        WagerSide.heads,
        resolvedAt,
      );
      final restoredResolved = GameState.decode(resolved.encode());
      final repeatedResolution = restoredResolved.resolvePendingWager(
        WagerSide.tails,
        resolvedAt.add(const Duration(seconds: 1)),
      );

      expect(restoredUnresolved.flipBalance, 500);
      expect(resolved.flipBalance, 1500);
      expect(restoredResolved.pendingWager?.didWin, isTrue);
      expect(repeatedResolution.flipBalance, 1500);
      expect(repeatedResolution.pendingWager?.result, WagerSide.heads);
      expect(repeatedResolution.revision, restoredResolved.revision);
    });

    test('a lost wager stays deducted and can clear only after resolution', () {
      final placedAt = DateTime.utc(2026, 7, 29, 12);
      final unlocked = GameState.initial(
        now: placedAt,
      ).copyWith(flipBalance: 1000);
      final placed = unlocked.placeWager(
        id: 'wager-loss',
        betAmount: 500,
        guess: WagerSide.tails,
        now: placedAt,
      );

      expect(() => placed.clearResolvedWager(placedAt), throwsStateError);

      final resolved = placed.resolvePendingWager(
        WagerSide.heads,
        placedAt.add(const Duration(seconds: 1)),
      );
      final cleared = resolved.clearResolvedWager(
        placedAt.add(const Duration(seconds: 2)),
      );
      final clearedAgain = cleared.clearResolvedWager(
        placedAt.add(const Duration(seconds: 3)),
      );

      expect(resolved.flipBalance, 500);
      expect(resolved.pendingWager?.didWin, isFalse);
      expect(cleared.pendingWager, isNull);
      expect(clearedAgain.revision, cleared.revision);
    });
  });
}
