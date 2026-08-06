import 'package:flutter/foundation.dart';

import 'commerce_catalog.dart';

enum PurchaseVerificationSource { localDebug, trustedServer }

@immutable
class VerifiedFlipPurchase {
  const VerifiedFlipPurchase({
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.verificationSource,
    required this.verifiedAtUtc,
  });

  final String transactionId;
  final String productId;
  final int quantity;
  final PurchaseVerificationSource verificationSource;
  final DateTime verifiedAtUtc;
}

abstract interface class FlipPurchaseService {
  static const thousandFlipProductId = CommerceCatalog.flipBundleProductId;
  static const thousandFlipQuantity = CommerceCatalog.flipBundleQuantity;

  bool get isAvailable;

  bool get isTestMode;

  String get displayPrice;

  Future<VerifiedFlipPurchase?> purchaseThousandFlips();
}

class DebugFlipPurchaseService implements FlipPurchaseService {
  const DebugFlipPurchaseService();

  @override
  bool get isAvailable => kDebugMode;

  @override
  bool get isTestMode => true;

  @override
  String get displayPrice => r'$0.99';

  @override
  Future<VerifiedFlipPurchase?> purchaseThousandFlips() async {
    if (!isAvailable) return null;

    await Future<void>.delayed(const Duration(milliseconds: 650));
    final verifiedAt = DateTime.now().toUtc();
    return VerifiedFlipPurchase(
      transactionId:
          'debug-purchase-${verifiedAt.microsecondsSinceEpoch.toString()}',
      productId: FlipPurchaseService.thousandFlipProductId,
      quantity: FlipPurchaseService.thousandFlipQuantity,
      verificationSource: PurchaseVerificationSource.localDebug,
      verifiedAtUtc: verifiedAt,
    );
  }
}
