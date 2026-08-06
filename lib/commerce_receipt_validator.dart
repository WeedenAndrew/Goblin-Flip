import 'flip_purchase_service.dart';
import 'receipt_security.dart';
import 'recovery_ad_service.dart';

abstract final class CommerceReceiptValidator {
  static bool acceptsPurchase(
    VerifiedFlipPurchase? purchase, {
    required bool allowDebugReceipts,
  }) {
    if (purchase == null) return false;

    final trustedSource =
        purchase.verificationSource ==
            PurchaseVerificationSource.trustedServer ||
        (allowDebugReceipts &&
            purchase.verificationSource ==
                PurchaseVerificationSource.localDebug);

    return trustedSource &&
        ReceiptSecurity.isSafeIdentifier(purchase.transactionId) &&
        purchase.productId == FlipPurchaseService.thousandFlipProductId &&
        purchase.quantity == FlipPurchaseService.thousandFlipQuantity &&
        purchase.verifiedAtUtc.isUtc;
  }

  static bool acceptsAdReward(
    VerifiedAdReward? reward, {
    required bool allowDebugReceipts,
  }) {
    if (reward == null) return false;

    final trustedSource =
        reward.verificationSource == AdRewardVerificationSource.trustedServer ||
        (allowDebugReceipts &&
            reward.verificationSource == AdRewardVerificationSource.localDebug);

    return trustedSource &&
        ReceiptSecurity.isSafeIdentifier(reward.rewardId) &&
        reward.verifiedAtUtc.isUtc;
  }
}
