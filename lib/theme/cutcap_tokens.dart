import 'package:flutter/material.dart';

/// cutcap's design tokens: the Swiss-grid palette, spacing grid, radii and
/// motion. Read with `CutcapTokens.of(context)`; Material components get the
/// same values through the `ThemeData` built in `cutcap_theme.dart`.
@immutable
final class CutcapTokens extends ThemeExtension<CutcapTokens> {
  const CutcapTokens({
    required this.workspace,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.frame,
  });

  /// Paper workspace with black ink.
  static const light = CutcapTokens(
    workspace: Color(0xFFF4F4F1),
    ink: Color(0xFF111111),
    inkSecondary: Color(0xFF6B6B66),
    inkMuted: Color(0xFF8C8C88),
    frame: Color(0xFFDCDCD7),
  );

  /// The workspace inverted to near-black with paper ink. It sits one step
  /// above the preview black so the two fields stay distinct.
  static const dark = CutcapTokens(
    workspace: Color(0xFF1F1F1D),
    ink: Color(0xFFF4F4F1),
    inkSecondary: Color(0xFFA3A39E),
    inkMuted: Color(0xFF8C8C88),
    frame: Color(0xFF363633),
  );

  /// The preview field and top bar, black in both schemes.
  static const preview = Color(0xFF111111);
  static const onPreview = Color(0xFFFFFFFF);

  /// Signal red, reserved for the playhead, cut points and the just-edited
  /// clip. Never for errors or decoration.
  static const signal = Color(0xFFE2001A);

  final Color workspace;
  final Color ink;

  /// Small secondary text (AA on the workspace).
  final Color inkSecondary;

  /// Large secondary text and inactive marks only: below 4.5:1 on paper.
  final Color inkMuted;

  /// Filmstrip frames while thumbnails are not available.
  final Color frame;

  static const space = CutcapSpace._();
  static const radius = CutcapRadius._();
  static const motion = CutcapMotion._();

  static CutcapTokens of(BuildContext context) =>
      Theme.of(context).extension<CutcapTokens>()!;

  @override
  CutcapTokens copyWith({
    Color? workspace,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? frame,
  }) => CutcapTokens(
    workspace: workspace ?? this.workspace,
    ink: ink ?? this.ink,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkMuted: inkMuted ?? this.inkMuted,
    frame: frame ?? this.frame,
  );

  @override
  CutcapTokens lerp(CutcapTokens? other, double t) {
    if (other == null) return this;
    return CutcapTokens(
      workspace: Color.lerp(workspace, other.workspace, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      frame: Color.lerp(frame, other.frame, t)!,
    );
  }
}

/// The 4 dp spacing grid.
final class CutcapSpace {
  const CutcapSpace._();

  /// Gutter between clips on the track.
  final double xs = 4;
  final double s = 8;
  final double m = 12;
  final double l = 16;
  final double xl = 24;
  final double xxl = 32;

  /// Desktop column gutter of the 12-column grid.
  double get gutter => xl;
}

/// Corner radii: the Swiss grid allows 0–2 px.
final class CutcapRadius {
  const CutcapRadius._();

  final double control = 2;

  BorderRadius get controlRadius => BorderRadius.circular(control);
}

/// Motion: 150–200 ms standard easing for reorder, ripple and state changes,
/// none at all when the system asks to reduce motion.
final class CutcapMotion {
  const CutcapMotion._();

  final Duration short = const Duration(milliseconds: 150);
  final Duration standard = const Duration(milliseconds: 200);
  final Curve curve = Easing.standard;

  /// [duration], or zero under the system reduce-motion setting.
  Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
