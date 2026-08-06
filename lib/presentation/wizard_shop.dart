part of '../goblin_flip_app.dart';

class _PowerupSheet extends StatelessWidget {
  const _PowerupSheet({
    required this.state,
    required this.purchasesEnabled,
    required this.onBuy,
  });

  final GameState state;
  final bool purchasesEnabled;
  final ValueChanged<PowerupType> onBuy;

  @override
  Widget build(BuildContext context) {
    const skin = _GameVisualSkins.wizardScroll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _OpenScrollPanel(
              key: const Key('wizard-scroll'),
              style: _OpenScrollStyle.wizard,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/icons/wizard_powerups.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Wizard\'s Charms',
                            style: _GameFonts.cinzelDecorative(
                              color: skin.primaryTextColor,
                              fontSize: skin.titleFontSize,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x594A6B6F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x80516E70)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              'Balance ${state.flipBalance}',
                              key: const Key('wizard-balance'),
                              style: _GameFonts.almendra(
                                color: skin.secondaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          key: const Key('close-powerups'),
                          onPressed: () => Navigator.of(context).pop(),
                          color: const Color(0xFF4A2E19),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PowerupRuleCard(
                      icon: Icons.shield_outlined,
                      title: 'Insurance',
                      priceLabel:
                          state.insuranceLevel >= GameState.maxInsuranceLevel
                          ? 'MAXED'
                          : '${state.powerupPrice(PowerupType.insurance)} flips',
                      status:
                          '${state.insuranceCoveragePercent}% loss protection',
                      actionLabel:
                          state.insuranceLevel >= GameState.maxInsuranceLevel
                          ? 'Maxed'
                          : 'Buy',
                      progress:
                          state.insuranceLevel / GameState.maxInsuranceLevel,
                      progressLabel:
                          '${state.insuranceCoveragePercent}% of 60%',
                      actionKey: const Key('buy-insurance'),
                      enabled:
                          purchasesEnabled &&
                          state.insuranceLevel < GameState.maxInsuranceLevel &&
                          state.flipBalance >=
                              state.powerupPrice(PowerupType.insurance),
                      onBuy: () => onBuy(PowerupType.insurance),
                    ),
                    const SizedBox(height: 9),
                    _PowerupRuleCard(
                      icon: Icons.history,
                      title: 'Roll Back Time',
                      priceLabel:
                          '${state.powerupPrice(PowerupType.rollBackTime)} flips',
                      status: state.rollBackTimeActive
                          ? 'Active • triggers before Insurance'
                          : 'Arms until your next loss',
                      actionLabel: state.rollBackTimeActive ? 'Active' : 'Buy',
                      actionKey: const Key('buy-rollback'),
                      enabled:
                          purchasesEnabled &&
                          !state.rollBackTimeActive &&
                          state.flipBalance >=
                              state.powerupPrice(PowerupType.rollBackTime),
                      onBuy: () => onBuy(PowerupType.rollBackTime),
                    ),
                    const SizedBox(height: 9),
                    _PowerupRuleCard(
                      icon: Icons.fast_forward,
                      title: 'Speed Flip',
                      priceLabel:
                          '${state.powerupPrice(PowerupType.speedFlip)} flips',
                      status: 'Five coin animations at 2× speed',
                      actionLabel: 'Buy',
                      actionKey: const Key('buy-speed-flip'),
                      enabled:
                          purchasesEnabled &&
                          state.flipBalance >=
                              state.powerupPrice(PowerupType.speedFlip),
                      onBuy: () => onBuy(PowerupType.speedFlip),
                    ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerupRuleCard extends StatelessWidget {
  const _PowerupRuleCard({
    required this.icon,
    required this.title,
    required this.priceLabel,
    required this.status,
    required this.actionLabel,
    required this.actionKey,
    required this.enabled,
    required this.onBuy,
    this.progress,
    this.progressLabel,
  });

  final IconData icon;
  final String title;
  final String priceLabel;
  final String status;
  final String actionLabel;
  final Key actionKey;
  final bool enabled;
  final VoidCallback onBuy;
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x8FFFF1C5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF78522E), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3D582A), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: _GameFonts.cinzel(
                          color: const Color(0xFF342012),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        priceLabel,
                        style: _GameFonts.cinzel(
                          color: const Color(0xFF77501E),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (progress != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              key: const Key('insurance-progress'),
                              value: progress,
                              minHeight: 8,
                              backgroundColor: const Color(0x806E5633),
                              color: const Color(0xFF557A38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          progressLabel ?? '',
                          key: const Key('insurance-progress-label'),
                          style: _GameFonts.cinzel(
                            color: const Color(0xFF3F2B1B),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          style: _GameFonts.cinzel(
                            color: const Color(0xFF4B321E),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton(
                        key: actionKey,
                        onPressed: enabled ? onBuy : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3D582A),
                          foregroundColor: const Color(0xFFF3E5B9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                          textStyle: _GameFonts.cinzel(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
