part of '../goblin_flip_app.dart';

/// Artwork and layout are deliberately separate from interaction logic.
///
/// To replace a procedural surface with a PNG asset, add the image under
/// assets/ui/skins and set [assetPath]. The existing child widgets, semantics,
/// hit boxes, and game callbacks remain unchanged.
@immutable
class _SurfaceArtwork {
  const _SurfaceArtwork({
    this.assetPath,
    this.fit = BoxFit.fill,
    this.alignment = Alignment.center,
    this.centerSlice,
  });

  final String? assetPath;
  final BoxFit fit;
  final Alignment alignment;
  final Rect? centerSlice;
}

class _SkinnableSurface extends StatelessWidget {
  const _SkinnableSurface({
    super.key,
    required this.artwork,
    required this.child,
    this.proceduralPainter,
  });

  final _SurfaceArtwork artwork;
  final CustomPainter? proceduralPainter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final assetPath = artwork.assetPath;
    if (assetPath == null) {
      return CustomPaint(painter: proceduralPainter, child: child);
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Image.asset(
            assetPath,
            fit: artwork.fit,
            alignment: artwork.alignment,
            centerSlice: artwork.centerSlice,
            filterQuality: FilterQuality.high,
          ),
        ),
        child,
      ],
    );
  }
}

@immutable
class _ScrollPanelSkin {
  const _ScrollPanelSkin({
    required this.artwork,
    required this.contentPadding,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.titleFontSize,
  });

  final _SurfaceArtwork artwork;
  final EdgeInsets contentPadding;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final double titleFontSize;
}

@immutable
class _CounterScrollSkin {
  const _CounterScrollSkin({
    required this.artwork,
    required this.width,
    required this.height,
    required this.contentPadding,
    required this.textColor,
    required this.fontSize,
  });

  final _SurfaceArtwork artwork;
  final double width;
  final double height;
  final EdgeInsets contentPadding;
  final Color textColor;
  final double fontSize;
}

@immutable
class _QuickBetRailSkin {
  const _QuickBetRailSkin({
    required this.artwork,
    required this.height,
    required this.backdropColor,
    required this.labelPadding,
    required this.labelColor,
    required this.selectedLabelColor,
    required this.labelFontSize,
    required this.allInFontSize,
    required this.selectionTop,
  });

  final _SurfaceArtwork artwork;
  final double height;
  final Color backdropColor;
  final EdgeInsets labelPadding;
  final Color labelColor;
  final Color selectedLabelColor;
  final double labelFontSize;
  final double allInFontSize;
  final double selectionTop;
}

/// Single edit point for future scroll and brick artwork.
///
/// `assetPath: null` keeps today's procedural art. Set a path under
/// `assets/ui/skins/` to swap only the artwork. Insets and text colors can be
/// tuned here to fit the safe writing area of the replacement image.
abstract final class _GameVisualSkins {
  static const counterScroll = _CounterScrollSkin(
    artwork: _SurfaceArtwork(),
    width: 250,
    height: 72,
    contentPadding: EdgeInsets.fromLTRB(38, 14, 38, 15),
    textColor: Color(0xFF302016),
    fontSize: 32,
  );

  static const wagerScroll = _ScrollPanelSkin(
    artwork: _SurfaceArtwork(),
    contentPadding: EdgeInsets.fromLTRB(34, 46, 34, 52),
    primaryTextColor: Color(0xFF342012),
    secondaryTextColor: Color(0xFF382416),
    titleFontSize: 21,
  );

  static const wizardScroll = _ScrollPanelSkin(
    artwork: _SurfaceArtwork(),
    contentPadding: EdgeInsets.fromLTRB(30, 46, 30, 50),
    primaryTextColor: Color(0xFF342012),
    secondaryTextColor: Color(0xFF2F3831),
    titleFontSize: 19,
  );

  static const quickBetRail = _QuickBetRailSkin(
    artwork: _SurfaceArtwork(),
    height: 70,
    backdropColor: Color(0xFF1E1C18),
    labelPadding: EdgeInsets.only(top: 14),
    labelColor: Color(0xFFE2D4B4),
    selectedLabelColor: Color(0xFFFFE3A0),
    labelFontSize: 15,
    allInFontSize: 12,
    selectionTop: 14,
  );

  static _ScrollPanelSkin openScroll(_OpenScrollStyle style) {
    return switch (style) {
      _OpenScrollStyle.wizard => wizardScroll,
      _OpenScrollStyle.wager => wagerScroll,
    };
  }
}
