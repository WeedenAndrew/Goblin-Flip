import 'dart:convert';

import 'commerce_catalog.dart';

import 'package:flutter/foundation.dart';

import 'receipt_security.dart';

enum WagerSide { heads, tails }

enum PowerupType { insurance, speedFlip, rollBackTime }

enum WagerProtection { insurance, rollBackTime }

@immutable
class PendingWager {
  const PendingWager({
    required this.id,
    required this.betAmount,
    required this.guess,
    required this.createdAtUtc,
    this.result,
    this.resolvedAtUtc,
    this.protectionApplied,
    this.wasAllIn = false,
  }) : assert(
         (result == null && resolvedAtUtc == null) ||
             (result != null && resolvedAtUtc != null),
         'A wager result and resolution time must be recorded together.',
       );

  final String id;
  final int betAmount;
  final WagerSide guess;
  final WagerSide? result;
  final DateTime createdAtUtc;
  final DateTime? resolvedAtUtc;
  final WagerProtection? protectionApplied;
  final bool wasAllIn;

  bool get isResolved => result != null;
  bool? get didWin => result == null ? null : result == guess;
  int get payoutAmount => didWin == true ? betAmount * 2 : 0;

  PendingWager resolve(
    WagerSide outcome,
    DateTime now, {
    WagerProtection? protectionApplied,
  }) {
    if (isResolved) return this;

    return PendingWager(
      id: id,
      betAmount: betAmount,
      guess: guess,
      createdAtUtc: createdAtUtc,
      result: outcome,
      resolvedAtUtc: now.toUtc(),
      protectionApplied: protectionApplied,
      wasAllIn: wasAllIn,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'betAmount': betAmount,
    'guess': guess.name,
    'result': result?.name,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'resolvedAtUtc': resolvedAtUtc?.toUtc().toIso8601String(),
    'protectionApplied': protectionApplied?.name,
    'wasAllIn': wasAllIn,
  };

  factory PendingWager.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final betAmount = _requiredInt(json, 'betAmount');
    if (id.trim().isEmpty || id.length > GameState.maxWagerIdLength) {
      throw const FormatException('Invalid pending wager id.');
    }
    if (betAmount <= 0) {
      throw const FormatException('Pending wager amount must be positive.');
    }

    final createdAt = _requiredDateTime(json, 'createdAtUtc');
    final result = switch (json['result']) {
      null => null,
      final String value => _wagerSide(value, 'result'),
      _ => throw const FormatException('Invalid pending wager result.'),
    };
    final resolvedAt = switch (json['resolvedAtUtc']) {
      null => result == null ? null : createdAt,
      final String value => _dateTime(value, 'resolvedAtUtc'),
      _ => throw const FormatException('Invalid wager resolution timestamp.'),
    };
    if (result == null && resolvedAt != null) {
      throw const FormatException(
        'An unresolved wager cannot have a resolution timestamp.',
      );
    }
    if (resolvedAt != null && resolvedAt.isBefore(createdAt)) {
      throw const FormatException(
        'A wager cannot be resolved before it was created.',
      );
    }
    final protectionApplied = switch (json['protectionApplied']) {
      null => null,
      final String value => _wagerProtection(value),
      _ => throw const FormatException('Invalid wager protection.'),
    };
    if (result == null && protectionApplied != null) {
      throw const FormatException('An unresolved wager cannot use protection.');
    }
    final wasAllIn = switch (json['wasAllIn']) {
      null => false,
      final bool value => value,
      _ => throw const FormatException('Invalid all-in wager marker.'),
    };

    return PendingWager(
      id: id,
      betAmount: betAmount,
      guess: _wagerSide(_requiredString(json, 'guess'), 'guess'),
      result: result,
      createdAtUtc: createdAt,
      resolvedAtUtc: resolvedAt,
      protectionApplied: protectionApplied,
      wasAllIn: wasAllIn,
    );
  }
}

@immutable
class PendingSpeedFlip {
  PendingSpeedFlip({
    required this.id,
    required this.purchasePrice,
    required this.guess,
    required List<WagerSide> results,
    required this.createdAtUtc,
  }) : results = List<WagerSide>.unmodifiable(results);

  final String id;
  final int purchasePrice;
  final WagerSide guess;
  final List<WagerSide> results;
  final DateTime createdAtUtc;

  int get matchCount => results.where((result) => result == guess).length;
  int get payoutAmount => matchCount * purchasePrice;

  Map<String, Object?> toJson() => {
    'id': id,
    'purchasePrice': purchasePrice,
    'guess': guess.name,
    'results': results.map((result) => result.name).toList(growable: false),
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
  };

  factory PendingSpeedFlip.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final purchasePrice = _requiredInt(json, 'purchasePrice');
    final rawResults = json['results'];
    if (id.trim().isEmpty || id.length > GameState.maxWagerIdLength) {
      throw const FormatException('Invalid Speed Flip id.');
    }
    if (purchasePrice <= 0) {
      throw const FormatException('Invalid Speed Flip purchase price.');
    }
    if (rawResults is! List<Object?> || rawResults.length != 5) {
      throw const FormatException('A Speed Flip requires five results.');
    }

    return PendingSpeedFlip(
      id: id,
      purchasePrice: purchasePrice,
      guess: _wagerSide(_requiredString(json, 'guess'), 'guess'),
      results: rawResults
          .map(
            (result) => result is String
                ? _wagerSide(result, 'results')
                : throw const FormatException('Invalid Speed Flip result.'),
          )
          .toList(growable: false),
      createdAtUtc: _requiredDateTime(json, 'createdAtUtc'),
    );
  }
}

@immutable
class GameState {
  GameState({
    required this.schemaVersion,
    required this.flipBalance,
    required this.goblinUnlocked,
    required this.pendingWager,
    required this.pendingSpeedFlip,
    required this.insuranceLevel,
    required this.rollBackTimeActive,
    required this.consecutiveWagerLosses,
    required this.recoveryChargesRemaining,
    required this.lastRecoveryUsedAtUtc,
    required List<String> processedPurchaseIds,
    required List<String> processedAdRewardIds,
    required this.revision,
    required this.updatedAtUtc,
  }) : processedPurchaseIds = List<String>.unmodifiable(processedPurchaseIds),
       processedAdRewardIds = List<String>.unmodifiable(processedAdRewardIds);

  static const currentSchemaVersion = 7;
  static const goblinUnlockBalance = 50;
  static const lossStreakOfferThreshold = 5;
  static const highBalanceRecoveryThreshold = 10000;
  static const maxRecoveryCharges = 3;
  static const recoveryRechargePeriod = Duration(hours: 24);
  static const maxInsuranceLevel = 12;
  static const maxWagerIdLength = 128;
  static const maxReceiptIdLength = ReceiptSecurity.maxIdentifierLength;
  static const maxProcessedReceiptCount = 10000;
  static const maxSafeInteger = 9007199254740991;
  static const Object _notProvided = Object();

  final int schemaVersion;
  final int flipBalance;
  final bool goblinUnlocked;
  final PendingWager? pendingWager;
  final PendingSpeedFlip? pendingSpeedFlip;
  final int insuranceLevel;
  final bool rollBackTimeActive;
  final int consecutiveWagerLosses;
  final int recoveryChargesRemaining;
  final DateTime? lastRecoveryUsedAtUtc;
  final List<String> processedPurchaseIds;
  final List<String> processedAdRewardIds;
  final int revision;
  final DateTime updatedAtUtc;

  bool get insuranceActive => insuranceLevel > 0;
  int get insuranceCoveragePercent => insuranceLevel * 5;

  factory GameState.initial({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return GameState(
      schemaVersion: currentSchemaVersion,
      flipBalance: 0,
      goblinUnlocked: false,
      pendingWager: null,
      pendingSpeedFlip: null,
      insuranceLevel: 0,
      rollBackTimeActive: false,
      consecutiveWagerLosses: 0,
      recoveryChargesRemaining: maxRecoveryCharges,
      lastRecoveryUsedAtUtc: null,
      processedPurchaseIds: const [],
      processedAdRewardIds: const [],
      revision: 0,
      updatedAtUtc: timestamp,
    );
  }

  GameState recordNormalFlip(DateTime now) {
    if (pendingWager != null || pendingSpeedFlip != null) {
      throw StateError(
        'A normal flip cannot start while a result is being replayed.',
      );
    }
    if (goblinUnlocked && flipBalance == 0) {
      throw StateError(
        'A zero balance must be recovered or replenished after unlock.',
      );
    }

    final timestamp = now.toUtc();
    final nextBalance = flipBalance + 1;
    return copyWith(
      flipBalance: nextBalance,
      goblinUnlocked:
          goblinUnlocked || nextBalance >= goblinUnlockBalance,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState creditVerifiedThousandFlipPurchase({
    required String transactionId,
    required DateTime now,
  }) {
    _validateNewReceiptId(
      transactionId,
      processedIds: processedPurchaseIds,
      name: 'transactionId',
    );
    final wager = pendingWager;
    final canSettleInsuredAllInLoss =
        wager != null &&
        wager.isResolved &&
        wager.didWin == false &&
        wager.wasAllIn &&
        wager.betAmount > highBalanceRecoveryThreshold &&
        wager.protectionApplied == WagerProtection.insurance;
    if (pendingSpeedFlip != null ||
        (wager != null && !canSettleInsuredAllInLoss)) {
      throw StateError(
        'Purchased flips cannot be credited during this pending result.',
      );
    }
    const purchasedAmount = CommerceCatalog.flipBundleQuantity;
    if (flipBalance > maxSafeInteger - purchasedAmount) {
      throw StateError('The purchased flips exceed the safe balance limit.');
    }

    final timestamp = now.toUtc();
    return copyWith(
      flipBalance: flipBalance + purchasedAmount,
      pendingWager: null,
      consecutiveWagerLosses: 0,
      processedPurchaseIds: [...processedPurchaseIds, transactionId],
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState creditVerifiedThousandFlipAd({
    required String rewardId,
    required DateTime now,
  }) {
    _validateNewReceiptId(
      rewardId,
      processedIds: processedAdRewardIds,
      name: 'rewardId',
    );
    if (pendingWager != null || pendingSpeedFlip != null) {
      throw StateError('Rewarded flips cannot be credited during a result.');
    }
    const rewardedAmount = CommerceCatalog.flipBundleQuantity;
    if (flipBalance > maxSafeInteger - rewardedAmount) {
      throw StateError('The rewarded flips exceed the safe balance limit.');
    }

    final timestamp = now.toUtc();
    return copyWith(
      flipBalance: flipBalance + rewardedAmount,
      consecutiveWagerLosses: 0,
      processedAdRewardIds: [...processedAdRewardIds, rewardId],
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState rechargeRecoveryChargesIfDue(DateTime now) {
    final lastUse = lastRecoveryUsedAtUtc;
    final timestamp = now.toUtc();
    if (recoveryChargesRemaining >= maxRecoveryCharges || lastUse == null) {
      return this;
    }
    if (timestamp.isBefore(lastUse.add(recoveryRechargePeriod))) {
      return this;
    }

    return copyWith(
      recoveryChargesRemaining: maxRecoveryCharges,
      lastRecoveryUsedAtUtc: null,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState creditVerifiedInsuredAllInRecovery({
    required String rewardId,
    required DateTime now,
  }) {
    final refreshed = rechargeRecoveryChargesIfDue(now);
    refreshed._validateNewReceiptId(
      rewardId,
      processedIds: refreshed.processedAdRewardIds,
      name: 'rewardId',
    );
    final wager = refreshed.pendingWager;
    if (wager == null || !wager.isResolved || wager.didWin != false) {
      throw StateError('There is no resolved wager loss to recover.');
    }
    if (!wager.wasAllIn ||
        wager.betAmount <= highBalanceRecoveryThreshold ||
        wager.protectionApplied != WagerProtection.insurance) {
      throw StateError('This wager is not eligible for insured recovery.');
    }
    if (refreshed.recoveryChargesRemaining <= 0) {
      throw StateError('No insured recovery charges remain.');
    }
    if (refreshed.flipBalance > wager.betAmount) {
      throw StateError('The recovered balance would be invalid.');
    }

    final timestamp = now.toUtc();
    return refreshed.copyWith(
      flipBalance: wager.betAmount,
      pendingWager: null,
      consecutiveWagerLosses: 0,
      recoveryChargesRemaining: refreshed.recoveryChargesRemaining - 1,
      lastRecoveryUsedAtUtc: timestamp,
      processedAdRewardIds: [
        ...refreshed.processedAdRewardIds,
        rewardId,
      ],
      revision: refreshed.revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  int powerupPrice(PowerupType type) {
    final basePrice = switch (type) {
      PowerupType.insurance => 100,
      PowerupType.speedFlip => 300,
      PowerupType.rollBackTime => 500,
    };
    final milestoneTier = (flipBalance ~/ 10000).clamp(0, 3).toInt();
    final milestonePercent = 100 + (milestoneTier * 20);

    var scaledBase = basePrice;
    if (type == PowerupType.insurance) {
      scaledBase *= 1 << insuranceLevel;
    }

    final scaledHundreds = scaledBase ~/ 100;
    if (scaledHundreds > maxSafeInteger ~/ milestonePercent) {
      return maxSafeInteger;
    }
    return scaledHundreds * milestonePercent;
  }

  GameState purchasePowerup(PowerupType type, DateTime now) {
    if (!goblinUnlocked) {
      throw StateError('The goblin has not been unlocked.');
    }
    if (pendingWager != null || pendingSpeedFlip != null) {
      throw StateError('A power-up cannot be purchased during a wager.');
    }
    if (type == PowerupType.speedFlip) {
      throw StateError('Speed Flip must be activated when it is purchased.');
    }
    if (type == PowerupType.insurance && insuranceLevel >= maxInsuranceLevel) {
      throw StateError('Insurance is already at its 60% maximum.');
    }
    if (type == PowerupType.rollBackTime && rollBackTimeActive) {
      throw StateError('Roll Back Time is already active.');
    }

    final price = powerupPrice(type);
    if (price > flipBalance) {
      throw StateError('The power-up costs more than the current balance.');
    }

    final timestamp = now.toUtc();
    return copyWith(
      flipBalance: flipBalance - price,
      insuranceLevel: insuranceLevel + (type == PowerupType.insurance ? 1 : 0),
      rollBackTimeActive:
          rollBackTimeActive || type == PowerupType.rollBackTime,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState purchaseSpeedFlip({
    required String id,
    required WagerSide guess,
    required List<WagerSide> results,
    required DateTime now,
  }) {
    if (!goblinUnlocked) {
      throw StateError('The goblin has not been unlocked.');
    }
    if (pendingWager != null || pendingSpeedFlip != null) {
      throw StateError('A result is already in progress.');
    }
    if (results.length != 5) {
      throw ArgumentError.value(
        results.length,
        'results',
        'A Speed Flip requires five results.',
      );
    }

    final price = powerupPrice(PowerupType.speedFlip);
    if (price > flipBalance) {
      throw StateError('Speed Flip costs more than the current balance.');
    }

    final timestamp = now.toUtc();
    final speedFlip = PendingSpeedFlip(
      id: id,
      purchasePrice: price,
      guess: guess,
      results: results,
      createdAtUtc: timestamp,
    );
    return copyWith(
      flipBalance: flipBalance - price + speedFlip.payoutAmount,
      pendingSpeedFlip: speedFlip,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState clearPendingSpeedFlip(DateTime now) {
    if (pendingSpeedFlip == null) return this;
    final timestamp = now.toUtc();
    return copyWith(
      pendingSpeedFlip: null,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState placeWager({
    required String id,
    required int betAmount,
    required WagerSide guess,
    required DateTime now,
  }) {
    if (!goblinUnlocked) {
      throw StateError('The goblin has not been unlocked.');
    }
    if (pendingWager != null || pendingSpeedFlip != null) {
      throw StateError('A wager is already in progress.');
    }
    if (id.trim().isEmpty || id.length > maxWagerIdLength) {
      throw ArgumentError.value(id, 'id', 'Invalid wager id.');
    }
    if (betAmount <= 0) {
      throw ArgumentError.value(
        betAmount,
        'betAmount',
        'The wager amount must be positive.',
      );
    }
    if (betAmount > flipBalance) {
      throw StateError('The wager amount exceeds the flip balance.');
    }

    final timestamp = now.toUtc();
    return copyWith(
      flipBalance: flipBalance - betAmount,
      pendingWager: PendingWager(
        id: id,
        betAmount: betAmount,
        guess: guess,
        createdAtUtc: timestamp,
        wasAllIn: betAmount == flipBalance,
      ),
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState resolvePendingWager(WagerSide outcome, DateTime now) {
    final wager = pendingWager;
    if (wager == null) {
      throw StateError('There is no wager to resolve.');
    }
    if (wager.isResolved) return this;

    final timestamp = now.toUtc();
    final didWin = outcome == wager.guess;
    WagerProtection? protectionApplied;
    var payout = didWin ? wager.betAmount * 2 : 0;
    var nextRollBackTimeActive = rollBackTimeActive;
    if (outcome != wager.guess) {
      if (rollBackTimeActive) {
        payout = wager.betAmount;
        nextRollBackTimeActive = false;
        protectionApplied = WagerProtection.rollBackTime;
      } else if (insuranceActive) {
        payout = (wager.betAmount * insuranceCoveragePercent) ~/ 100;
        protectionApplied = WagerProtection.insurance;
      }
    }
    final nextLossStreak = didWin
        ? 0
        : (consecutiveWagerLosses + 1).clamp(0, maxSafeInteger).toInt();
    final resolvedWager = wager.resolve(
      outcome,
      timestamp,
      protectionApplied: protectionApplied,
    );
    return copyWith(
      flipBalance: flipBalance + payout,
      pendingWager: resolvedWager,
      rollBackTimeActive: nextRollBackTimeActive,
      consecutiveWagerLosses: nextLossStreak,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState clearResolvedWager(DateTime now) {
    final wager = pendingWager;
    if (wager == null) return this;
    if (!wager.isResolved) {
      throw StateError('An unresolved wager cannot be cleared.');
    }

    final timestamp = now.toUtc();
    return copyWith(
      pendingWager: null,
      revision: revision + 1,
      updatedAtUtc: timestamp,
    );
  }

  GameState copyWith({
    int? flipBalance,
    bool? goblinUnlocked,
    Object? pendingWager = _notProvided,
    Object? pendingSpeedFlip = _notProvided,
    int? insuranceLevel,
    bool? rollBackTimeActive,
    int? consecutiveWagerLosses,
    int? recoveryChargesRemaining,
    Object? lastRecoveryUsedAtUtc = _notProvided,
    List<String>? processedPurchaseIds,
    List<String>? processedAdRewardIds,
    int? revision,
    DateTime? updatedAtUtc,
  }) {
    final nextBalance = flipBalance ?? this.flipBalance;
    return GameState(
      schemaVersion: currentSchemaVersion,
      flipBalance: nextBalance,
      goblinUnlocked:
          this.goblinUnlocked ||
          (goblinUnlocked ?? false) ||
          nextBalance >= goblinUnlockBalance,
      pendingWager: identical(pendingWager, _notProvided)
          ? this.pendingWager
          : pendingWager as PendingWager?,
      pendingSpeedFlip: identical(pendingSpeedFlip, _notProvided)
          ? this.pendingSpeedFlip
          : pendingSpeedFlip as PendingSpeedFlip?,
      insuranceLevel: insuranceLevel ?? this.insuranceLevel,
      rollBackTimeActive: rollBackTimeActive ?? this.rollBackTimeActive,
      consecutiveWagerLosses:
          consecutiveWagerLosses ?? this.consecutiveWagerLosses,
      recoveryChargesRemaining:
          recoveryChargesRemaining ?? this.recoveryChargesRemaining,
      lastRecoveryUsedAtUtc: identical(lastRecoveryUsedAtUtc, _notProvided)
          ? this.lastRecoveryUsedAtUtc
          : (lastRecoveryUsedAtUtc as DateTime?)?.toUtc(),
      processedPurchaseIds: processedPurchaseIds ?? this.processedPurchaseIds,
      processedAdRewardIds: processedAdRewardIds ?? this.processedAdRewardIds,
      revision: revision ?? this.revision,
      updatedAtUtc: (updatedAtUtc ?? this.updatedAtUtc).toUtc(),
    );
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'flipBalance': flipBalance,
    'goblinUnlocked': goblinUnlocked,
    'pendingWager': pendingWager?.toJson(),
    'pendingSpeedFlip': pendingSpeedFlip?.toJson(),
    'insuranceLevel': insuranceLevel,
    'rollBackTimeActive': rollBackTimeActive,
    'consecutiveWagerLosses': consecutiveWagerLosses,
    'recoveryChargesRemaining': recoveryChargesRemaining,
    'lastRecoveryUsedAtUtc': lastRecoveryUsedAtUtc?.toIso8601String(),
    'processedPurchaseIds': processedPurchaseIds,
    'processedAdRewardIds': processedAdRewardIds,
    'revision': revision,
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
  };

  factory GameState.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Game state root must be a JSON object.');
    }
    return GameState.fromJson(decoded);
  }

  factory GameState.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion < 1 || schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'Unsupported game state schema version: $schemaVersion.',
      );
    }

    final flipBalance = _requiredInt(json, 'flipBalance');
    final revision = _requiredInt(json, 'revision');
    final legacyInsuranceInventory = schemaVersion == 2
        ? _requiredInt(json, 'insuranceInventory')
        : 0;
    final legacySpeedFlipInventory = schemaVersion == 2
        ? _requiredInt(json, 'speedFlipInventory')
        : 0;
    final legacyRollBackTimeInventory = schemaVersion == 2
        ? _requiredInt(json, 'rollBackTimeInventory')
        : 0;
    final legacyInsurancePurchaseCount =
        schemaVersion == 2 || schemaVersion == 3
        ? _requiredInt(json, 'insurancePurchaseCount')
        : 0;
    if (flipBalance < 0) {
      throw const FormatException('Flip balance cannot be negative.');
    }
    if (revision < 0) {
      throw const FormatException('Revision cannot be negative.');
    }
    if (legacyInsuranceInventory < 0 ||
        legacySpeedFlipInventory < 0 ||
        legacyRollBackTimeInventory < 0 ||
        legacyInsurancePurchaseCount < legacyInsuranceInventory) {
      throw const FormatException('Invalid legacy power-up inventory.');
    }

    final readsRecoveryCycle = schemaVersion < 6 || schemaVersion >= 7;
    final recoveryChargesRemaining = readsRecoveryCycle
        ? _requiredInt(json, 'recoveryChargesRemaining')
        : maxRecoveryCharges;
    if (recoveryChargesRemaining < 0 ||
        recoveryChargesRemaining > maxRecoveryCharges) {
      throw const FormatException('Invalid recovery charge count.');
    }
    final lastRecoveryUsedAtUtc = readsRecoveryCycle
        ? switch (json['lastRecoveryUsedAtUtc']) {
            null => null,
            final String value => _dateTime(value, 'lastRecoveryUsedAtUtc'),
            _ => throw const FormatException(
              'Invalid recovery charge timestamp.',
            ),
          }
        : null;
    if (recoveryChargesRemaining < maxRecoveryCharges &&
        lastRecoveryUsedAtUtc == null) {
      throw const FormatException(
        'A depleted recovery cycle requires its last-use timestamp.',
      );
    }

    final pendingWager = switch (json['pendingWager']) {
      null => null,
      final Map<String, dynamic> value => PendingWager.fromJson(value),
      _ => throw const FormatException('Invalid pending wager.'),
    };
    final pendingSpeedFlip = schemaVersion >= 3
        ? switch (json['pendingSpeedFlip']) {
            null => null,
            final Map<String, dynamic> value => PendingSpeedFlip.fromJson(
              value,
            ),
            _ => throw const FormatException('Invalid pending Speed Flip.'),
          }
        : null;
    if (pendingWager != null && pendingSpeedFlip != null) {
      throw const FormatException(
        'A wager and Speed Flip cannot both be pending.',
      );
    }
    final insuranceLevel = switch (schemaVersion) {
      >= 4 => _requiredInt(json, 'insuranceLevel'),
      3 =>
        legacyInsurancePurchaseCount > 0
            ? legacyInsurancePurchaseCount
            : _requiredBool(json, 'insuranceActive')
            ? 1
            : 0,
      2 =>
        legacyInsurancePurchaseCount > legacyInsuranceInventory
            ? legacyInsurancePurchaseCount
            : legacyInsuranceInventory,
      _ => 0,
    };
    if (insuranceLevel < 0 || insuranceLevel > maxInsuranceLevel) {
      throw const FormatException('Invalid Insurance level.');
    }
    final rollBackTimeActive = schemaVersion >= 3
        ? _requiredBool(json, 'rollBackTimeActive')
        : legacyRollBackTimeInventory > 0;
    final processedPurchaseIds = schemaVersion >= 5
        ? _requiredReceiptIds(json, 'processedPurchaseIds')
        : const <String>[];
    final processedAdRewardIds = schemaVersion >= 5
        ? _requiredReceiptIds(json, 'processedAdRewardIds')
        : const <String>[];
    final consecutiveWagerLosses = schemaVersion >= 6
        ? _requiredInt(json, 'consecutiveWagerLosses')
        : 0;
    if (consecutiveWagerLosses < 0 ||
        consecutiveWagerLosses > maxSafeInteger) {
      throw const FormatException('Invalid wager loss streak.');
    }

    final storedUnlock = _requiredBool(json, 'goblinUnlocked');
    return GameState(
      schemaVersion: currentSchemaVersion,
      flipBalance: flipBalance,
      goblinUnlocked:
          storedUnlock || flipBalance >= goblinUnlockBalance,
      pendingWager: pendingWager,
      pendingSpeedFlip: pendingSpeedFlip,
      insuranceLevel: insuranceLevel,
      rollBackTimeActive: rollBackTimeActive,
      consecutiveWagerLosses: consecutiveWagerLosses,
      recoveryChargesRemaining: recoveryChargesRemaining,
      lastRecoveryUsedAtUtc: lastRecoveryUsedAtUtc,
      processedPurchaseIds: processedPurchaseIds,
      processedAdRewardIds: processedAdRewardIds,
      revision: revision,
      updatedAtUtc: _requiredDateTime(json, 'updatedAtUtc'),
    );
  }

  void _validateNewReceiptId(
    String receiptId, {
    required List<String> processedIds,
    required String name,
  }) {
    if (!ReceiptSecurity.isSafeIdentifier(receiptId)) {
      throw ArgumentError.value(receiptId, name, 'Invalid receipt identifier.');
    }
    if (processedIds.contains(receiptId)) {
      throw StateError('This receipt has already been applied.');
    }
    if (processedIds.length >= maxProcessedReceiptCount) {
      throw StateError('The local receipt ledger is full.');
    }
  }
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Missing or invalid integer: $key.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid string: $key.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Missing or invalid boolean: $key.');
}

List<String> _requiredReceiptIds(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.length > GameState.maxProcessedReceiptCount) {
    throw FormatException('Missing or invalid receipt ledger: $key.');
  }

  final receipts = <String>[];
  final uniqueReceipts = <String>{};
  for (final item in value) {
    if (item is! String ||
        !ReceiptSecurity.isSafeIdentifier(item) ||
        !uniqueReceipts.add(item)) {
      throw FormatException('Invalid receipt identifier in: $key.');
    }
    receipts.add(item);
  }
  return List<String>.unmodifiable(receipts);
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  return _dateTime(value, key);
}

DateTime _dateTime(String value, String key) {
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Missing or invalid timestamp: $key.');
  }
}

WagerSide _wagerSide(String value, String key) {
  try {
    return WagerSide.values.byName(value);
  } on ArgumentError {
    throw FormatException('Invalid wager side: $key.');
  }
}

WagerProtection _wagerProtection(String value) {
  try {
    return WagerProtection.values.byName(value);
  } on ArgumentError {
    throw const FormatException('Invalid wager protection.');
  }
}
