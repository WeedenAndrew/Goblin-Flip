import 'package:flutter_test/flutter_test.dart';
import 'package:goblin_flip/commerce_receipt_validator.dart';
import 'package:goblin_flip/flip_purchase_service.dart';
import 'package:goblin_flip/game_state.dart';
import 'package:goblin_flip/receipt_security.dart';
import 'package:goblin_flip/recovery_ad_service.dart';

void main() {
  final verifiedAt = DateTime.utc(2026, 7, 30, 12);

  VerifiedFlipPurchase purchase({
    String transactionId = 'GPA.1234-5678-9012-34567',
    String productId = FlipPurchaseService.thousandFlipProductId,
    int quantity = 1000,
    PurchaseVerificationSource source =
        PurchaseVerificationSource.trustedServer,
    DateTime? timestamp,
  }) {
    return VerifiedFlipPurchase(
      transactionId: transactionId,
      productId: productId,
      quantity: quantity,
      verificationSource: source,
      verifiedAtUtc: timestamp ?? verifiedAt,
    );
  }

  VerifiedAdReward adReward({
    String rewardId = 'admob-reward:1234-5678',
    AdRewardVerificationSource source =
        AdRewardVerificationSource.trustedServer,
    DateTime? timestamp,
  }) {
    return VerifiedAdReward(
      rewardId: rewardId,
      verificationSource: source,
      verifiedAtUtc: timestamp ?? verifiedAt,
    );
  }

  group('purchase receipt injection resistance', () {
    test('accepts only the exact trusted product and quantity', () {
      expect(
        CommerceReceiptValidator.acceptsPurchase(
          purchase(),
          allowDebugReceipts: false,
        ),
        isTrue,
      );
      expect(
        CommerceReceiptValidator.acceptsPurchase(
          purchase(productId: 'goblin_flip_1000_flips;grant=999999'),
          allowDebugReceipts: false,
        ),
        isFalse,
      );
      expect(
        CommerceReceiptValidator.acceptsPurchase(
          purchase(quantity: 999999),
          allowDebugReceipts: false,
        ),
        isFalse,
      );
    });

    test('rejects a debug receipt when release policy is simulated', () {
      final debugReceipt = purchase(
        source: PurchaseVerificationSource.localDebug,
      );

      expect(
        CommerceReceiptValidator.acceptsPurchase(
          debugReceipt,
          allowDebugReceipts: false,
        ),
        isFalse,
      );
      expect(
        CommerceReceiptValidator.acceptsPurchase(
          debugReceipt,
          allowDebugReceipts: true,
        ),
        isTrue,
      );
    });

    test('rejects path, command, control-character, and oversized IDs', () {
      final injectedIds = <String>[
        '../store/transaction',
        r'receipt$(grant 999999)',
        'receipt"; DROP TABLE entitlements;--',
        'receipt\nforged',
        List<String>.filled(
          ReceiptSecurity.maxIdentifierLength + 1,
          'a',
        ).join(),
      ];

      for (final transactionId in injectedIds) {
        expect(
          CommerceReceiptValidator.acceptsPurchase(
            purchase(transactionId: transactionId),
            allowDebugReceipts: false,
          ),
          isFalse,
          reason: 'Rejected injected transaction ID: $transactionId',
        );
      }
    });

    test('rejects a non-UTC verification timestamp', () {
      expect(
        CommerceReceiptValidator.acceptsPurchase(
          purchase(timestamp: DateTime(2026, 7, 30, 12)),
          allowDebugReceipts: false,
        ),
        isFalse,
      );
    });
  });

  group('rewarded-ad injection resistance', () {
    test('rejects debug rewards under release policy', () {
      final debugReward = adReward(
        source: AdRewardVerificationSource.localDebug,
      );

      expect(
        CommerceReceiptValidator.acceptsAdReward(
          debugReward,
          allowDebugReceipts: false,
        ),
        isFalse,
      );
      expect(
        CommerceReceiptValidator.acceptsAdReward(
          debugReward,
          allowDebugReceipts: true,
        ),
        isTrue,
      );
    });

    test('rejects an injected or malformed reward ID', () {
      for (final rewardId in <String>[
        '',
        '../../recovery',
        'reward\nsecond-reward',
        'reward<script>grant()</script>',
      ]) {
        expect(
          CommerceReceiptValidator.acceptsAdReward(
            adReward(rewardId: rewardId),
            allowDebugReceipts: false,
          ),
          isFalse,
          reason: 'Rejected injected ad reward ID: $rewardId',
        );
      }
    });
  });

  group('persisted receipt-ledger injection resistance', () {
    test('rejects a replayed purchase after save and reload', () {
      final credited = GameState.initial(now: verifiedAt)
          .creditVerifiedThousandFlipPurchase(
            transactionId: 'store-transaction-1',
            now: verifiedAt,
          );
      final restored = GameState.decode(credited.encode());

      expect(restored.flipBalance, 1000);
      expect(
        () => restored.creditVerifiedThousandFlipPurchase(
          transactionId: 'store-transaction-1',
          now: verifiedAt,
        ),
        throwsStateError,
      );
    });

    test('rejects a replayed ad reward after save and reload', () {
      final recovered = GameState.initial(
        now: verifiedAt,
      ).creditVerifiedThousandFlipAd(
        rewardId: 'ad-reward-1',
        now: verifiedAt,
      );
      final restored = GameState.decode(recovered.encode());

      expect(
        () => restored.creditVerifiedThousandFlipAd(
          rewardId: 'ad-reward-1',
          now: verifiedAt,
        ),
        throwsStateError,
      );
    });

    test('rejects an injected reward ID on charged loss reversion', () {
      final resolved = GameState.initial(now: verifiedAt)
          .copyWith(flipBalance: 12000, insuranceLevel: 1)
          .placeWager(
            id: 'secure-high-all-in',
            betAmount: 12000,
            guess: WagerSide.heads,
            now: verifiedAt,
          )
          .resolvePendingWager(WagerSide.tails, verifiedAt);

      expect(
        () => resolved.creditVerifiedInsuredAllInRecovery(
          rewardId: '../restore=999999',
          now: verifiedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects type-confused, duplicate, and injected saved ledgers', () {
      final clean = GameState.initial(now: verifiedAt).toJson();
      final hostileLedgers = <Object?>[
        'not-a-list',
        <Object?>[1234],
        <Object?>['same-id', 'same-id'],
        <Object?>['valid-id', '../injected-id'],
      ];

      for (final hostileLedger in hostileLedgers) {
        final hostileState = Map<String, Object?>.from(clean)
          ..['processedPurchaseIds'] = hostileLedger;
        expect(
          () => GameState.fromJson(hostileState),
          throwsFormatException,
          reason: 'Rejected hostile receipt ledger: $hostileLedger',
        );
      }
    });

    test('rejects balance overflow attempts', () {
      final fullBalance = GameState.initial(
        now: verifiedAt,
      ).copyWith(flipBalance: GameState.maxSafeInteger);

      expect(
        () => fullBalance.creditVerifiedThousandFlipPurchase(
          transactionId: 'overflow-purchase',
          now: verifiedAt,
        ),
        throwsStateError,
      );
      expect(
        () => fullBalance.creditVerifiedThousandFlipAd(
          rewardId: 'overflow-ad-reward',
          now: verifiedAt,
        ),
        throwsStateError,
      );
    });
  });
}
