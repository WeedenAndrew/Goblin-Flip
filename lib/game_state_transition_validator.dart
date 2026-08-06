import 'game_state.dart';

abstract final class GameStateTransitionValidator {
  static bool isInitialState(GameState state) {
    return state.encode() ==
        GameState.initial(now: state.updatedAtUtc).encode();
  }

  static bool isAllowed(GameState previous, GameState next) {
    if (next.revision < previous.revision) return false;
    if (next.revision == previous.revision) {
      return next.encode() == previous.encode();
    }

    final timestamp = next.updatedAtUtc;
    if (_matches(() => previous.recordNormalFlip(timestamp), next)) {
      return true;
    }
    if (_matches(
      () => previous.rechargeRecoveryChargesIfDue(timestamp),
      next,
    )) {
      return true;
    }

    if (_hasOneNewTrailingId(
      previous.processedPurchaseIds,
      next.processedPurchaseIds,
    )) {
      final transactionId = next.processedPurchaseIds.last;
      if (_matches(
        () => previous.creditVerifiedThousandFlipPurchase(
          transactionId: transactionId,
          now: timestamp,
        ),
        next,
      )) {
        return true;
      }
    }

    if (_hasOneNewTrailingId(
      previous.processedAdRewardIds,
      next.processedAdRewardIds,
    )) {
      final rewardId = next.processedAdRewardIds.last;
      if (_matches(
        () => previous.creditVerifiedThousandFlipAd(
          rewardId: rewardId,
          now: timestamp,
        ),
        next,
      )) {
        return true;
      }
      if (_matches(
        () => previous.creditVerifiedInsuredAllInRecovery(
          rewardId: rewardId,
          now: timestamp,
        ),
        next,
      )) {
        return true;
      }
    }

    for (final type in <PowerupType>[
      PowerupType.insurance,
      PowerupType.rollBackTime,
    ]) {
      if (_matches(() => previous.purchasePowerup(type, timestamp), next)) {
        return true;
      }
    }

    final speedFlip = next.pendingSpeedFlip;
    if (previous.pendingSpeedFlip == null && speedFlip != null) {
      if (_matches(
        () => previous.purchaseSpeedFlip(
          id: speedFlip.id,
          guess: speedFlip.guess,
          results: speedFlip.results,
          now: timestamp,
        ),
        next,
      )) {
        return true;
      }
    }
    if (previous.pendingSpeedFlip != null &&
        next.pendingSpeedFlip == null &&
        _matches(() => previous.clearPendingSpeedFlip(timestamp), next)) {
      return true;
    }

    final nextWager = next.pendingWager;
    if (previous.pendingWager == null &&
        nextWager != null &&
        !nextWager.isResolved) {
      if (_matches(
        () => previous.placeWager(
          id: nextWager.id,
          betAmount: nextWager.betAmount,
          guess: nextWager.guess,
          now: timestamp,
        ),
        next,
      )) {
        return true;
      }
    }

    final outcome = nextWager?.result;
    if (previous.pendingWager != null &&
        !previous.pendingWager!.isResolved &&
        outcome != null &&
        _matches(
          () => previous.resolvePendingWager(outcome, timestamp),
          next,
        )) {
      return true;
    }
    if (previous.pendingWager?.isResolved ?? false) {
      if (next.pendingWager == null &&
          _matches(() => previous.clearResolvedWager(timestamp), next)) {
        return true;
      }
    }

    return false;
  }

  static bool _hasOneNewTrailingId(List<String> previous, List<String> next) {
    if (next.length != previous.length + 1) return false;
    for (var index = 0; index < previous.length; index++) {
      if (next[index] != previous[index]) return false;
    }
    return true;
  }

  static bool _matches(GameState Function() create, GameState expected) {
    try {
      return create().encode() == expected.encode();
    } on Object {
      return false;
    }
  }
}
