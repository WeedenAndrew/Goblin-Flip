import 'package:flutter/foundation.dart';

enum AdRewardVerificationSource { localDebug, trustedServer }

@immutable
class VerifiedAdReward {
  const VerifiedAdReward({
    required this.rewardId,
    required this.verificationSource,
    required this.verifiedAtUtc,
  });

  final String rewardId;
  final AdRewardVerificationSource verificationSource;
  final DateTime verifiedAtUtc;
}

abstract interface class RecoveryAdService {
  bool get isAvailable;

  Future<VerifiedAdReward?> showRecoveryAd();
}

class DebugRecoveryAdService implements RecoveryAdService {
  const DebugRecoveryAdService();

  @override
  bool get isAvailable => kDebugMode;

  @override
  Future<VerifiedAdReward?> showRecoveryAd() async {
    if (!isAvailable) return null;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    final verifiedAt = DateTime.now().toUtc();
    return VerifiedAdReward(
      rewardId: 'debug-ad-${verifiedAt.microsecondsSinceEpoch.toString()}',
      verificationSource: AdRewardVerificationSource.localDebug,
      verifiedAtUtc: verifiedAt,
    );
  }
}
