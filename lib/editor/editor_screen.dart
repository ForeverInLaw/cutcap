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

    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _Grid(constraints.maxWidth - 2 * space.xxl);
        final geometry = PositionReadout.measure(
          context,
          state: state,
          compact: false,
          maxWidth: grid.readoutWidth,
        );
        return Column(
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
                  _HeadlineRow(state, controls, grid: grid, geometry: geometry),
                  TimelineView(
                    state: state,
                    actions: actions,
                    compact: false,
                    tie: PlayheadTie(
                      rise: geometry.baselineDrop / 2,
                      timeWidth: geometry.timeWidth,
                    ),
                  ),
                  SizedBox(height: space.l),
                  StatusArea(state: state, actions: actions, compact: false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The desktop 12-column grid across [width]: the readout spans six
/// columns, the transport two (never narrower than its buttons), the tools
/// the remaining four.
final class _Grid {
  _Grid(this.width);

  final double width;

  static const _transportMin = 176.0;
  static double get gutter => CutcapTokens.space.gutter;

  double get _column => (width - 11 * gutter) / 12;

  double get transportWidth => math.max(2 * _column + gutter, _transportMin);

  double get _flexible => width - transportWidth - 2 * gutter;

  double get readoutWidth => _flexible * 6 / 10;
  double get toolsWidth => _flexible * 4 / 10;
}

/// The 12-column row above the ruler: timecode over six columns, transport
/// from column seven, edit tools flush right over the last four. Controls
/// stand on the timecode's baseline.
class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow(
    this.state,
    this.controls, {
    required this.grid,
    required this.geometry,
  });

  final EditorViewState state;
  final EditorControls controls;
  final _Grid grid;
  final ReadoutGeometry geometry;

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
    final gap = CutcapTokens.space.s;
    final onBaseline = EdgeInsets.only(bottom: geometry.baselineDrop);
    final labelled = grid.toolsWidth >= _labelledToolsWidth(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: grid.readoutWidth,
          child: PositionReadout(
            state: state,
            compact: false,
            geometry: geometry,
          ),
        ),
        SizedBox(width: _Grid.gutter),
        SizedBox(
          width: grid.transportWidth,
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
        SizedBox(width: _Grid.gutter),
        SizedBox(
          width: grid.toolsWidth,
          child: Padding(
            padding: onBaseline,
            child: Row(
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
            ),
          ),
        ),
      ],
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

  /// Room the film may grow by when the screen has height to spare.
  static const _filmGrowth = 40.0;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => _body(
              context,
              width: constraints.maxWidth,
              available: constraints.maxHeight,
            ),
          ),
        ),
        _PhoneActionBar(controls),
      ],
    );
  }

  /// Preview over the workspace. The track takes what it needs first (and
  /// up to [_filmGrowth] more film when there is room); the preview fills
  /// the rest, so no empty band opens between them. When even that leaves
  /// the preview too short, the workspace scrolls instead.
  Widget _body(
    BuildContext context, {
    required double width,
    required double available,
  }) {
    final space = CutcapTokens.space;
    final readoutGap = space.m;
    final geometry = PositionReadout.measure(
      context,
      state: state,
      compact: true,
      maxWidth: width - 2 * space.l,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final status = state.export is ExportIdle
        ? 0.0
        : space.l + 3 * space.m + 48 + 2 * scaler.scale(14 * 1.3);
    double workspaceHeight(double film) =>
        2 * space.l +
        geometry.height +
        readoutGap +
        TimelineView.heightOf(context, compact: true, filmHeight: film) +
        status;

    final size = state.outputSize;
    final aspect = size == null || size.height == 0
        ? 16 / 9
        : size.width / size.height;
    final frame = width / aspect + 2 * space.l;
    const base = TimelineView.defaultFilmHeight;
    final spare = available - frame - workspaceHeight(base);
    final film = base + spare.clamp(0.0, _filmGrowth);
    final fits = available - workspaceHeight(film) >= _minPreview;

    final workspace = Padding(
      padding: EdgeInsets.all(space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PositionReadout(state: state, compact: true, geometry: geometry),
          SizedBox(height: readoutGap),
          TimelineView(
            state: state,
            actions: actions,
            compact: true,
            filmHeight: film,
            tie: PlayheadTie(
              rise: (readoutGap + geometry.baselineDrop) / 2,
              timeWidth: geometry.timeWidth,
            ),
          ),
          if (state.export is! ExportIdle) SizedBox(height: space.l),
          StatusArea(state: state, actions: actions, compact: true),
        ],
      ),
    );

    final previewField = PreviewField(child: preview);
    if (fits) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: previewField),
          workspace,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _minPreview, child: previewField),
        Expanded(child: SingleChildScrollView(reverse: true, child: workspace)),
      ],
    );
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
