part of '../goblin_flip_app.dart';

class _ActivePowerupIcons extends StatelessWidget {
  const _ActivePowerupIcons({
    required this.insuranceActive,
    required this.insuranceCoveragePercent,
    required this.rollBackTimeActive,
  });

  final bool insuranceActive;
  final int insuranceCoveragePercent;
  final bool rollBackTimeActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('active-powerup-stack'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (insuranceActive)
          _ActivePowerupIcon(
            key: Key('active-insurance'),
            icon: Icons.shield_outlined,
            tooltip:
                'Insurance: returns $insuranceCoveragePercent% on every loss',
          ),
        if (insuranceActive && rollBackTimeActive) const SizedBox(height: 7),
        if (rollBackTimeActive)
          const _ActivePowerupIcon(
            key: Key('active-rollback'),
            icon: Icons.history,
            tooltip: 'Roll Back Time armed: reverts the next loss',
          ),
      ],
    );
  }
}

class _ActivePowerupIcon extends StatelessWidget {
  const _ActivePowerupIcon({
    super.key,
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xE6E5C782),
          border: Border.all(color: const Color(0xFF4B301D), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xA6000000),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF3D582A), size: 25),
        ),
      ),
    );
  }
}
