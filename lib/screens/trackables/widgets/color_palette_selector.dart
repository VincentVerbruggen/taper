import 'package:flutter/material.dart';

import 'package:taper/data/database.dart';

/// A row of tappable color circles from `trackableColorPalette`.
///
/// Renders the 10 palette colors as circular swatches in a Wrap layout.
/// The selected color shows a check icon overlay and an outline border.
///
/// Like a color picker component in a web app, but simpler —
/// no free-form color wheel, just a fixed palette.
///
/// Props pattern is like a Vue component's props:
///   - `selectedColor`: the currently selected ARGB int
///   - `onColorSelected`: callback when a new color is tapped
class ColorPaletteSelector extends StatelessWidget {
  /// Currently selected color as ARGB int.
  final int selectedColor;

  /// Called when a color circle is tapped.
  /// Like @update:modelValue in Vue v-model.
  final ValueChanged<int> onColorSelected;

  const ColorPaletteSelector({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap = CSS flexbox with wrapping. If the 10 circles don't fit on
    // one line, they wrap to the next row automatically.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: trackableColorPalette.map((colorInt) {
        final isSelected = colorInt == selectedColor;
        final color = Color(colorInt);

        return GestureDetector(
          onTap: () => onColorSelected(colorInt),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              // Selected color gets a white outline border to stand out.
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2.5,
                    )
                  : null,
            ),
            // Check icon overlay on the selected color.
            // Centered with Stack + Center, similar to an absolute-positioned
            // SVG overlay in CSS.
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 20,
                    // Use a contrasting color for visibility on any background.
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
