import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'focus_ring.dart';

enum ControlKind { outlined, filled, plain }

/// A Material button themed for the editor: square corners, a keyboard
/// focus ring, and a tooltip that names the keyboard shortcut on desktop.
///
/// Icon-only buttons are announced by [label]; the shortcut stays out of
/// the accessible name.
class ControlButton extends StatelessWidget {
  const ControlButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.shortcut,
    this.kind = ControlKind.outlined,
    this.showLabel = false,
    this.size = 48,
    this.width,
    this.iconSize,
    super.key,
  }) : assert(icon != null || showLabel, 'An icon-only button needs an icon');

  /// Optional on labelled buttons.
  final IconData? icon;
  final String label;

  /// Disabled when null.
  final VoidCallback? onPressed;

  /// Key hint for the tooltip, e.g. `S`; null on touch layouts.
  final String? shortcut;
  final ControlKind kind;
  final bool showLabel;

  /// Height, and width for icon-only buttons unless [width] is set.
  final double size;
  final double? width;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final hint = shortcut;
    return Tooltip(
      message: hint == null
          ? label
          : AppLocalizations.of(context).withShortcut(label, hint),
      excludeFromSemantics: true,
      child: FocusRing(
        child: showLabel ? _labelled(context) : _iconOnly(context),
      ),
    );
  }

  Widget _labelled(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, size)),
    );
    final glyph = icon;
    final iconWidget = glyph == null ? null : Icon(glyph, size: iconSize);
    final text = Text(label);
    return switch (kind) {
      ControlKind.outlined => OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: iconWidget,
        label: text,
      ),
      ControlKind.filled => FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: iconWidget,
        label: text,
      ),
      ControlKind.plain => TextButton.icon(
        onPressed: onPressed,
        style: style,
        icon: iconWidget,
        label: text,
      ),
    };
  }

  Widget _iconOnly(BuildContext context) {
    final theme = Theme.of(context);
    final style = IconButton.styleFrom(
      fixedSize: Size(width ?? size, size),
      minimumSize: Size(width ?? size, size),
      iconSize: iconSize,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
    final iconWidget = Icon(icon, semanticLabel: label);
    return switch (kind) {
      ControlKind.outlined => IconButton.outlined(
        onPressed: onPressed,
        style: style.copyWith(
          side: theme.outlinedButtonTheme.style?.side,
          foregroundColor: theme.outlinedButtonTheme.style?.foregroundColor,
        ),
        icon: iconWidget,
      ),
      ControlKind.filled => IconButton.filled(
        onPressed: onPressed,
        style: style,
        icon: iconWidget,
      ),
      ControlKind.plain => IconButton(
        onPressed: onPressed,
        style: style.copyWith(
          foregroundColor: theme.outlinedButtonTheme.style?.foregroundColor,
        ),
        icon: iconWidget,
      ),
    };
  }
}
