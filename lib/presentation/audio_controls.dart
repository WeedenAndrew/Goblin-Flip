part of '../goblin_flip_app.dart';

class _AudioMuteButton extends StatelessWidget {
  const _AudioMuteButton({
    required this.muted,
    required this.enabled,
    required this.onPressed,
  });

  final bool muted;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = muted
        ? 'Unmute forest music and goblin voice'
        : 'Mute forest music and goblin voice';
    return Semantics(
      label: label,
      button: true,
      toggled: muted,
      child: IconButton(
        key: const Key('audio-mute-toggle'),
        tooltip: label,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xD934322C),
          foregroundColor: const Color(0xFFF1D895),
          disabledBackgroundColor: const Color(0x9934322C),
          disabledForegroundColor: const Color(0x998F8264),
          side: const BorderSide(color: Color(0xFF8A7143), width: 1.4),
          minimumSize: const Size.square(44),
          shadowColor: Colors.black,
          elevation: 4,
        ),
        icon: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: 24,
        ),
      ),
    );
  }
}
