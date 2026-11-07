import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'control_button.dart';
import 'timecode_text.dart';

/// The line under the track. At rest it summarises the sequence (desktop
/// only); during and after an export it becomes the export panel, so the
/// edit above stays visible and readable throughout.
class StatusArea extends StatelessWidget {
  const StatusArea({
    required this.state,
    required this.actions,
    required this.compact,
    super.key,
  });

  final EditorViewState state;
  final EditorActions actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final motion = CutcapTokens.motion;
    final size = compact ? 48.0 : 40.0;
    final close = ControlButton(
      icon: Icons.close_sharp,
      label: l10n.dismiss,
      onPressed: actions.onDismissExport,
      kind: ControlKind.plain,
      size: size,
    );

    final Widget content = switch (state.export) {
      ExportIdle() when compact => const SizedBox.shrink(),
      ExportIdle() => _Summary(state),
      ExportRunning(:final progress) => _ExportPanel(
        key: const ValueKey(ExportRunning),
        compact: compact,
        message: l10n.exportProgress((progress * 100).floor()),
        progress: progress,
        buttons: [
          ControlButton(
            label: l10n.cancelExport,
            onPressed: actions.onCancelExport,
            showLabel: true,
            size: size,
          ),
        ],
      ),
      ExportDone(:final fileName, :final canShare) => _ExportPanel(
        key: const ValueKey(ExportDone),
        compact: compact,
        icon: Icons.check_sharp,
        message: l10n.exportDone(fileName),
        buttons: [
          ControlButton(
            icon: Icons.open_in_new_sharp,
            label: l10n.openExport,
            onPressed: actions.onOpenExport,
            kind: ControlKind.filled,
            showLabel: true,
            size: size,
          ),
          if (canShare)
            ControlButton(
              icon: Icons.share_sharp,
              label: l10n.shareExport,
              onPressed: actions.onShareExport,
              showLabel: true,
              size: size,
            ),
          close,
        ],
      ),
      ExportFailed(:final reason) => _ExportPanel(
        key: const ValueKey(ExportFailed),
        compact: compact,
        icon: Icons.error_outline_sharp,
        message: l10n.exportFailed(reason),
        detail: l10n.editIntact,
        buttons: [
          ControlButton(
            icon: Icons.refresh_sharp,
            label: l10n.retryExport,
            onPressed: actions.onRetryExport,
            kind: ControlKind.filled,
            showLabel: true,
            size: size,
          ),
          close,
        ],
      ),
    };

    return AnimatedSize(
      duration: motion.of(context, motion.standard),
      curve: motion.curve,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: motion.of(context, motion.short),
        child: content,
      ),
    );
  }
}

/// "4 clips · 03:40.00 · 1920×1080 · 30 fps"
class _Summary extends StatelessWidget {
  const _Summary(this.state);

  final EditorViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = CutcapTokens.of(context);
    final size = state.outputSize;
    final rate = state.frameRate.perSecond;
    final parts = [
      l10n.clipCount(state.clips.length),
      Timecode.full(state.duration, state.frameRate),
      if (size != null) '${size.width.round()}×${size.height.round()}',
      l10n.framesPerSecond(
        rate == rate.roundToDouble()
            ? rate.round().toString()
            : rate.toStringAsFixed(2),
      ),
    ];
    return _Ruled(
      height: 36,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TimecodeText(
          parts.join('  ·  '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.inkSecondary),
        ),
      ),
    );
  }
}

/// Export progress or outcome: an icon and message in words, an optional
/// progress line, and the actions. One row on desktop; stacked on the
/// phone so long messages wrap instead of squeezing the buttons.
class _ExportPanel extends StatelessWidget {
  const _ExportPanel({
    required this.compact,
    required this.message,
    required this.buttons,
    this.icon,
    this.detail,
    this.progress,
    super.key,
  });

  final bool compact;
  final IconData? icon;
  final String message;
  final String? detail;

  /// 0 to 1 while running.
  final double? progress;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final text = Theme.of(context).textTheme;
    final space = CutcapTokens.space;
    final value = progress;
    final bar = value == null ? null : LinearProgressIndicator(value: value);
    final glyph = icon;
    final detailText = detail;

    final messageBlock = Semantics(
      // Announce outcomes, not every progress step.
      liveRegion: value == null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 20, color: tokens.ink),
            SizedBox(width: space.s),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: text.labelLarge?.copyWith(
                    fontFeatures: TimecodeText.tabular,
                  ),
                ),
                if (detailText != null)
                  Text(
                    detailText,
                    style: text.bodySmall?.copyWith(color: tokens.inkSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) SizedBox(width: space.s),
          button,
        ],
      ],
    );

    if (compact) {
      return _Ruled(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              messageBlock,
              if (bar != null) ...[SizedBox(height: space.m), bar],
              SizedBox(height: space.m),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: actionRow,
              ),
            ],
          ),
        ),
      );
    }

    return _Ruled(
      height: 64,
      child: Row(
        children: [
          if (bar != null) ...[
            SizedBox(width: 168, child: messageBlock),
            Expanded(child: bar),
          ] else
            Expanded(child: messageBlock),
          SizedBox(width: space.xl),
          actionRow,
        ],
      ),
    );
  }
}

/// A band under a hairline ink rule.
class _Ruled extends StatelessWidget {
  const _Ruled({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: CutcapTokens.of(context).ink)),
    ),
    child: SizedBox(height: height, width: double.infinity, child: child),
  );
}
