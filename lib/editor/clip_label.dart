/// Which parts of a clip's label a tile shows.
typedef ClipLabelParts = ({bool name, bool length});

/// Decides what of a clip label fits a tile. A length is shown whole or not
/// at all; a name may ellipsize but only while [minNameChars] characters
/// stay visible. Whatever is dropped is still announced by the clip's
/// accessibility label.
abstract final class ClipLabel {
  /// Characters a shortened name must keep to still be recognisable.
  static const minNameChars = 8;

  /// [nameMinWidth] is the width of the name's first [minNameChars]
  /// characters plus an ellipsis (or the whole name when shorter).
  /// [stacked] puts the name and length on separate lines (phone);
  /// otherwise they share one line joined by a separator [separatorWidth]
  /// wide, and the length goes first when space runs out.
  static ClipLabelParts fit({
    required double width,
    required double nameWidth,
    required double nameMinWidth,
    required double lengthWidth,
    required double separatorWidth,
    required bool stacked,
  }) {
    final nameFits = nameWidth <= width || nameMinWidth <= width;
    final lengthFits = lengthWidth <= width;
    if (stacked) return (name: nameFits, length: lengthFits);

    final shortest = (nameWidth < nameMinWidth ? nameWidth : nameMinWidth);
    if (shortest + separatorWidth + lengthWidth <= width) {
      return (name: true, length: true);
    }
    if (nameFits) return (name: true, length: false);
    return (name: false, length: lengthFits);
  }
}
