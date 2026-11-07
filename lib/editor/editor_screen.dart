import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/cutcap_tokens.dart';
import 'editor_view_state.dart';
import 'widgets/editor_controls.dart';
import 'widgets/empty_workspace.dart';
import 'widgets/position_readout.dart';
import 'widgets/preview_field.dart';
import 'widgets/status_area.dart';
import 'widgets/timeline_view.dart';
import 'widgets/top_bar.dart';

/// The single editor screen: black preview field on top, the paper
/// workspace with the headline timecode, ruler and track below.
///
/// Renders [state] and reports intent through [actions]. [preview] is the
/// player surface; the field stays black without one and collapses while
/// there are no clips. Windows narrower than [phoneBreakpoint] get the
/// one-handed phone layout.
class EditorScreen extends StatelessWidget {
  const EditorScreen({
    required this.state,
    required this.actions,
    this.preview,
    super.key,
  });

  final EditorViewState state;
  final EditorActions actions;
  final Widget? preview;

  static const phoneBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final touch = constraints.maxWidth < phoneBreakpoint;
        final controls = EditorControls(
          context,
          state: state,
          actions: actions,
          touch: touch,
        );
        return touch
            ? _PhoneLayout(state, actions, controls, preview)
            : _DesktopLayout(state, actions, controls, preview);
      },
    ),
  );
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout(this.state, this.actions, this.controls, this.preview);

  final EditorViewState state;
  final EditorActions actions;
  final EditorControls controls;
  final Widget? preview;

  /// Share of the window height taken by the black field, bar included.
  static const _blackShare = 0.58;

  @override
  Widget build(BuildContext context) {
    final space = CutcapTokens.space;
    final bar = ColoredBox(
      color: CutcapTokens.preview,
      child: EditorTopBar(controls: controls, showAddVideo: !state.isEmpty),
    );

    if (state.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(space.xxl),
              child: EmptyWorkspace(
                controls: controls,
                acceptsFileDrop: state.acceptsFileDrop,
              ),
            ),
          ),
        ],
      );
    }

    final drop = PositionReadout.baselineDrop(context, compact: false);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          // The workspace takes the height its content needs; the preview
          // gets the rest, up to its share of the window.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    constraints.maxHeight * _blackShare -
                    EditorTopBar.desktopHeight,
              ),
              child: PreviewField(child: preview),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(space.xxl, space.xl, space.xxl, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeadlineRow(state, controls, baselineDrop: drop),
                TimelineView(
                  state: state,
                  actions: actions,
                  compact: false,
                  playheadLead: drop,
                ),
                SizedBox(height: space.l),
                StatusArea(state: state, actions: actions, compact: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 12-column row above the ruler: timecode over six columns, transport
/// from column seven, edit tools flush right over the last four. Controls
/// stand on the timecode's baseline.
class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow(this.state, this.controls, {required this.baselineDrop});

  final EditorViewState state;
  final EditorControls controls;
  final double baselineDrop;

  static const _transportWidth = 176.0;

  /// Width of the tool row with Split and Delete spelled out: two labelled
  /// buttons (14 px padding, 20 px icon, 8 px gap), two icon buttons, gaps.
  static double _labelledToolsWidth(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width + 2 * 14 + 20 + 8;
    }

    return labelWidth(l10n.split) +
        labelWidth(l10n.deleteClip) +
        2 * 48 +
        3 * 8;
  }

  @override
  Widget build(BuildContext context) {
    final gutter = CutcapTokens.space.gutter;
    final gap = CutcapTokens.space.s;
    final onBaseline = EdgeInsets.only(bottom: baselineDrop);
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - 11 * gutter) / 12;
        final transportSpan = math.max(2 * column + gutter, _transportWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 6,
              child: PositionReadout(state: state, compact: false),
            ),
            SizedBox(width: gutter),
            SizedBox(
              width: transportSpan,
              child: Padding(
                padding: onBaseline,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    controls.stepBackward(),
                    SizedBox(width: gap),
                    controls.playPause(),
                    SizedBox(width: gap),
                    controls.stepForward(),
                  ],
                ),
              ),
            ),
            SizedBox(width: gutter),
            Expanded(
              flex: 4,
              child: Padding(
                padding: onBaseline,
                child: LayoutBuilder(
                  builder: (context, tools) {
                    final labelled =
                        tools.maxWidth >= _labelledToolsWidth(context);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        controls.split(showLabel: labelled),
                        SizedBox(width: gap),
                        controls.delete(showLabel: labelled),
                        SizedBox(width: gap),
                        controls.undo(),
                        SizedBox(width: gap),
                        controls.redo(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout(this.state, this.actions, this.controls, this.preview);

  final EditorViewState state;
  final EditorActions actions;
  final EditorControls controls;
  final Widget? preview;

  static const _minPreview = 120.0;

  @override
  Widget build(BuildContext context) {
    final space = CutcapTokens.space;
    final inset = EdgeInsets.symmetric(horizontal: space.l);
    final bar = ColoredBox(
      color: CutcapTokens.preview,
      child: SafeArea(bottom: false, child: EditorTopBar(controls: controls)),
    );

    if (state.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.only(bottom: space.l),
              child: Padding(
                padding: inset.copyWith(top: space.xl),
                child: EmptyWorkspace(
                  controls: controls,
                  acceptsFileDrop: false,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final drop = PositionReadout.baselineDrop(context, compact: true);
    final readoutGap = space.m;
    final workspace = Padding(
      padding: inset.copyWith(top: space.l, bottom: space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PositionReadout(state: state, compact: true),
          SizedBox(height: readoutGap),
          TimelineView(
            state: state,
            actions: actions,
            compact: true,
            playheadLead: readoutGap + drop,
          ),
          SizedBox(height: space.l),
          StatusArea(state: state, actions: actions, compact: true),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = _previewHeight(
                context,
                width: constraints.maxWidth,
                available: constraints.maxHeight,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: previewHeight,
                    child: PreviewField(child: preview),
                  ),
                  // Bottom-anchored: the track stays in thumb reach, and a
                  // large system font scrolls instead of clipping.
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true,
                      child: workspace,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _PhoneActionBar(controls),
      ],
    );
  }

  /// The frame's own height at full width plus a margin, no more than the
  /// workspace leaves free.
  double _previewHeight(
    BuildContext context, {
    required double width,
    required double available,
  }) {
    final space = CutcapTokens.space;
    final size = state.outputSize;
    final aspect = size == null || size.height == 0
        ? 16 / 9
        : size.width / size.height;
    final frame = width / aspect + 2 * space.l;
    final scaler = MediaQuery.textScalerOf(context);
    final readout = scaler.scale(44);
    final status = state.export is ExportIdle
        ? 0
        : 2 * space.m + space.m + 48 + 2 * scaler.scale(14 * 1.2) + space.m;
    final workspace =
        space.l * 3 +
        readout +
        space.m +
        TimelineView.heightOf(context) +
        status;
    return math.max(_minPreview, math.min(frame, available - workspace));
  }
}

/// Bottom bar within thumb reach: frame back, play, frame forward on the
/// left, Split and Delete on the right, all 48 dp.
class _PhoneActionBar extends StatelessWidget {
  const _PhoneActionBar(this.controls);

  final EditorControls controls;

  @override
  Widget build(BuildContext context) {
    final space = CutcapTokens.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: CutcapTokens.of(context).ink)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.l, vertical: space.s),
          child: Row(
            children: [
              controls.stepBackward(),
              SizedBox(width: space.s),
              controls.playPause(),
              SizedBox(width: space.s),
              controls.stepForward(),
              const Spacer(),
              controls.split(),
              SizedBox(width: space.s),
              controls.delete(),
            ],
          ),
        ),
      ),
    );
  }
}
