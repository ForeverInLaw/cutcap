import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// player surface; the field stays black without one. Windows narrower than
/// [phoneBreakpoint] get the one-handed phone layout.
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

  /// Height the workspace needs below the preview.
  static const _workspaceMin = 400.0;

  @override
  Widget build(BuildContext context) {
    final space = CutcapTokens.space;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final previewHeight = math.max(
          120.0,
          math.min(
            height * _blackShare - EditorTopBar.desktopHeight,
            height - EditorTopBar.desktopHeight - _workspaceMin,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: CutcapTokens.preview,
              child: EditorTopBar(controls: controls),
            ),
            SizedBox(
              height: previewHeight,
              child: PreviewField(child: preview),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  space.xxl,
                  state.isEmpty ? space.xxl : space.xl,
                  space.xxl,
                  0,
                ),
                child: state.isEmpty
                    ? Align(
                        alignment: AlignmentDirectional.topStart,
                        child: EmptyWorkspace(
                          controls: controls,
                          acceptsFileDrop: state.acceptsFileDrop,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeadlineRow(state, controls),
                          TimelineView(
                            state: state,
                            actions: actions,
                            compact: false,
                          ),
                          const Spacer(),
                          StatusArea(
                            state: state,
                            actions: actions,
                            compact: false,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The 12-column row above the ruler: timecode over six columns, transport
/// from column seven, edit tools flush right over the last four.
class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow(this.state, this.controls);

  final EditorViewState state;
  final EditorControls controls;

  static const _transportWidth = 176.0;
  static const _labelledToolsWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final gutter = CutcapTokens.space.gutter;
    final gap = CutcapTokens.space.s;
    return SizedBox(
      height: 88,
      child: LayoutBuilder(
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
                  padding: EdgeInsets.only(bottom: gap),
                  child: Row(
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
                  padding: EdgeInsets.only(bottom: CutcapTokens.space.m),
                  child: LayoutBuilder(
                    builder: (context, tools) {
                      final labelled = tools.maxWidth >= _labelledToolsWidth;
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
      ),
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout(this.state, this.actions, this.controls, this.preview);

  final EditorViewState state;
  final EditorActions actions;
  final EditorControls controls;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final space = CutcapTokens.space;
    final inset = EdgeInsets.symmetric(horizontal: space.l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: CutcapTokens.preview,
          child: SafeArea(
            bottom: false,
            child: EditorTopBar(controls: controls),
          ),
        ),
        Expanded(child: PreviewField(child: preview)),
        if (state.isEmpty)
          SafeArea(
            top: false,
            minimum: EdgeInsets.only(bottom: space.l),
            child: Padding(
              padding: inset.copyWith(top: space.xl),
              child: EmptyWorkspace(controls: controls, acceptsFileDrop: false),
            ),
          )
        else ...[
          Padding(
            padding: inset.copyWith(top: space.l),
            child: PositionReadout(state: state, compact: true),
          ),
          Padding(
            padding: inset.copyWith(top: space.m, bottom: space.l),
            child: TimelineView(state: state, actions: actions, compact: true),
          ),
          Padding(
            padding: inset,
            child: StatusArea(state: state, actions: actions, compact: true),
          ),
          _PhoneActionBar(controls),
        ],
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
