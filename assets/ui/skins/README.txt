Goblin Flip swappable UI artwork

Put replacement PNG scroll or brick artwork in this folder, then set its path in:
lib/presentation/visual_skins.dart

The registry keeps artwork separate from text, hit boxes, accessibility labels,
and game callbacks. Adjust the matching contentPadding, text colors, and font
sizes in that one file to fit the replacement art.

Recommended assets:
- Transparent PNG.
- No baked-in words, numbers, or button labels.
- Scroll art should leave a clear central writing area.
- The quick-bet rail should contain five equal-width brick faces.
- Use a nine-slice centerSlice in _SurfaceArtwork when a panel must stretch
  without distorting its border. Leave centerSlice null for fixed-size art.
