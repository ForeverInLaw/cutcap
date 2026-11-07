---
name: cutcap
description: A frame-accurate video cutter set like a Swiss typographic poster, one dark graphite scheme.
colors:
  signal: "#E2001A"
  preview: "#111111"
  on-preview: "#FFFFFF"
  workspace: "#262624"
  ink: "#F4F4F1"
  ink-secondary: "#A3A39E"
  ink-muted: "#8C8C88"
  frame: "#41413E"
typography:
  display-desktop:
    fontFamily: "Golos Text"
    fontSize: "80px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-3.2px"
    fontFeature: "\"tnum\""
  display-phone:
    fontFamily: "Golos Text"
    fontSize: "44px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-1.3px"
    fontFeature: "\"tnum\""
  headline:
    fontFamily: "Golos Text"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.8px"
  headline-phone:
    fontFamily: "Golos Text"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.5px"
  total:
    fontFamily: "Golos Text"
    fontSize: "28px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "-0.6px"
    fontFeature: "\"tnum\""
  wordmark:
    fontFamily: "Golos Text"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.66px"
  body-large:
    fontFamily: "Golos Text"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.4
  body:
    fontFamily: "Golos Text"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.35
  body-small:
    fontFamily: "Golos Text"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
  label:
    fontFamily: "Golos Text"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.2
  label-guide:
    fontFamily: "Golos Text"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.2
    fontFeature: "\"tnum\""
  label-small:
    fontFamily: "Golos Text"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "0.4px"
rounded:
  none: "0px"
  control: "2px"
spacing:
  xs: "4px"
  s: "8px"
  m: "12px"
  l: "16px"
  xl: "24px"
  xxl: "32px"
  gutter: "24px"
components:
  button-filled:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.workspace}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 20px"
    height: "48px"
  button-outlined:
    backgroundColor: "{colors.workspace}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 14px"
    height: "48px"
  button-plain:
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "48px"
  button-icon:
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    size: "48px"
  button-play-desktop:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.workspace}"
    rounded: "{rounded.control}"
    size: "64px"
  top-bar:
    backgroundColor: "{colors.preview}"
    textColor: "{colors.on-preview}"
    typography: "{typography.wordmark}"
    padding: "0 32px"
    height: "56px"
  top-bar-phone:
    backgroundColor: "{colors.preview}"
    textColor: "{colors.on-preview}"
    padding: "0 8px 0 16px"
    height: "64px"
  clip-tile:
    backgroundColor: "{colors.frame}"
    textColor: "{colors.ink}"
    typography: "{typography.label-small}"
    rounded: "{rounded.none}"
    height: "110px"
  add-tile:
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    width: "56px"
    height: "110px"
  missing-chip:
    backgroundColor: "{colors.workspace}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "4px 12px"
  status-band:
    textColor: "{colors.ink-secondary}"
    typography: "{typography.body-small}"
    height: "64px"
  tooltip:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.workspace}"
    typography: "{typography.body-small}"
    rounded: "{rounded.control}"
---

# Design System: cutcap

## Overview

**Creative North Star: "The Timecode Poster"**

The editor is set like an International Typographic Style poster: a strict modular grid, one grotesk, two flat fields and one signal colour. The black preview field holds the frame; the graphite workspace beneath it holds the time, the tools and the single track, all drawn in paper-white ink. The playhead time is the screen's headline, set at poster scale in fixed tabular cells, and one red rule ties that headline to the playhead running through the ruler and the track. Time and rule move as one stroke.

Density is deliberately low for an editor. There is one track, one row of tools and one status line; nothing is stacked in panels or docked in sidebars. Structure comes from hairline ink rules and alignment to the 12-column grid, never from boxes, tints or depth. Every control is a standard Material 3 button with square corners and a hairline outline, so the editor reads as typography first and machinery second.

There is one scheme, dark graphite, whatever the system theme. The owner's anti-references are confirmed: no dense "pro" NLE look (Premiere, DaVinci) and no dark glow or neon. The category default of a grey NLE with rounded tiles and a blue accent is rejected.

**Key Characteristics:**
- Two flat fields: black preview (bar included) over graphite workspace; no third surface.
- Paper ink for all text, rules, outlines and focus; red only for time and cuts.
- Golos Text in three weights, tabular figures on every time.
- Hairline 1 px ink rules divide bands; 2 px is the only heavier stroke.
- Corners 0 to 2 px; no shadows, gradients, tints or glow.
- 48 dp targets and a visible keyboard focus ring on every control.

## Colors

A near-monochrome graphite-and-paper palette with a single saturated red that is spent only on time.

### Primary
- **Signal Red** (signal): the playhead (2 px rule, 10 px square head on the ruler, the underline under the headline timecode and the 1 px carrier line between them), and the 3 px base line on the just-edited clip. Nothing else, ever.

### Neutral
- **Preview Black** (preview): the preview field and the top bar that sits on it; letterboxing around the frame.
- **On-Preview White** (on-preview): the wordmark on the black bar.
- **Graphite Workspace** (workspace): the scaffold, every band below the preview, the fill of outlined buttons, ruler label knockouts, the text colour on filled buttons and tooltips.
- **Paper Ink** (ink): all primary text, hairline rules, button outlines, the selected-clip frame, hatching on a missing clip, focus rings, the fill of filled buttons and tooltips, and error icons.
- **Ink Secondary** (ink-secondary): small secondary text (clip lengths, ruler tick labels, the status summary, export detail lines, empty-state body). 6:1 on graphite.
- **Ink Muted** (ink-muted): large secondary text (the desktop sequence total at 28 px) and inactive marks only. 4.5:1 on graphite; never for small text.
- **Frame Grey** (frame): placeholder filmstrip frames while thumbnails load.

State overlays derive from ink by opacity, not new hues: hover 6 %, focus 10 %, disabled text and icons 38 %, disabled outline 20 %, progress track ink-muted at 35 %.

### Named Rules
**The Red Reservation Rule.** Signal red marks only time and cuts: the playhead and its tie to the headline timecode, cut points, and the just-edited clip. It is never used for errors, warnings, destructive actions, selection, hover, focus or decoration. Errors are told in words with an ink icon; Delete is an ordinary outlined button.

**The Two Fields Rule.** The screen has exactly two surfaces: preview black and graphite workspace. Every Material surface-container role resolves to workspace; there are no raised cards, panels or tinted containers.

**The One Scheme Rule.** cutcap ships one dark graphite scheme regardless of the system theme. There is no light theme to keep in sync.

## Typography

**Display Font:** Golos Text (bundled as GolosText: Regular 400, Medium 500, Bold 700)
**Body Font:** Golos Text
**Label/Mono Font:** Golos Text with tabular figures; there is no mono face.

**Character:** One Cyrillic-capable grotesk carries everything, from the 80 px timecode to 11 px clip labels. Hierarchy comes from size and weight jumps, tight negative tracking at display sizes, and colour steps of ink, never from a second family.

### Hierarchy
- **Display, desktop** (700, 80 px, line-height 1, -3.2 px): the headline playhead timecode.
- **Display, phone** (700, 44 px, line-height 1, -1.3 px): the same timecode on the phone.
- **Total** (400, 28 px, line-height 1, -0.6 px): "/ total" beside the desktop timecode, on its baseline, in ink-muted. On the phone the total uses Body Large in ink-secondary.
- **Headline** (700, 32 px, 1.15, -0.8 px): the empty-state heading on desktop; **Headline, phone** (700, 24 px, 1.2, -0.5 px) on the phone.
- **Wordmark** (700, 22 px, line-height 1, -0.66 px): lowercase "cutcap" in the top bar.
- **Body Large** (400, 16 px, 1.4): the empty-state explanation, capped at 560 px wide.
- **Body** (400, 14 px, 1.35): the drop hint.
- **Body Small** (400, 12 px, 1.3): the status summary, export detail lines, tooltips.
- **Label** (500, 14 px, 1.2): button labels (700 on filled buttons) and export messages.
- **Label Guide** (700, 12 px, 1.2, tabular): ruler guide words naming the first and last time in view; tick labels use the same size at 400 in ink-secondary.
- **Label Small** (500, 11 px, 1.2, +0.4 px): clip names; clip lengths at 400 in ink-secondary.

### Named Rules
**The Fixed Cell Rule.** Every time on screen (timecode, total, ruler labels, clip lengths, status summary, export progress) is set with tabular figures, so digits change in place and never jitter sideways.

**The One Timecode Rule.** Time has one form, `HH:MM:SS.FF`, shown at three sizes (80/44 px headline, 12 px ruler, 11 px clip label). Never abbreviate it differently per place.

**The Shrink Whole Rule.** When the headline timecode and total do not fit their columns (narrow window, large system text), the pair scales down as one unit; it never wraps, truncates or reflows.

## Layout

The breakpoint is 720 px of window width: below it the phone layout, at or above it the desktop layout. Spacing runs on a 4 px grid (xs 4, s 8, m 12, l 16, xl 24, xxl 32).

**Desktop.** A 56 px black bar, then the black preview field taking up to 58 % of the window height (bar included); the workspace below takes the height its content needs and the preview gives way. The workspace has 32 px side margins and 24 px top padding. Its headline row sits on a 12-column grid with 24 px gutters: the timecode over six columns, the transport (frame back, play, frame forward) from column seven at two columns and never under 176 px, the edit tools (Split, Delete, Undo, Redo) flush right. Transport and tools stand on the timecode's baseline. Split and Delete spell out their labels only when the tool column is wide enough; otherwise they drop to icons. Below: the timeline (hairline top rule, ruler, 8 px gap, track), 16 px, then the status band (64 px minimum, hairline top rule).

**Phone.** A 64 px black bar (wordmark, Undo, Redo, Export), the preview, then the workspace with 16 px insets: headline timecode, 12 px, ruler (stretched to 56 px for scrubbing), track, status. A bottom action bar under a hairline rule carries frame back, play, frame forward on the left and Split, Delete on the right, 8 px apart. The track takes its height first (film may grow up to 40 px when there is room); the preview fills the rest and never drops below 120 px; when it would, the workspace scrolls instead.

**Track.** Clips sit back to back by time across the visible window with 4 px gutters; film height 110 px by default. An add tile (56 px wide desktop, 48 px phone) is fixed at the track's end. Label rows grow with the system text size.

### Named Rules
**The Baseline Rule.** Controls in the headline row stand on the timecode's alphabetic baseline, not centred on it.

**The Grow-With-Text Rule.** Label rows, ruler height and band heights are measured from the system text scale; nothing is clipped at 130 % text.

## Elevation & Depth

The system is completely flat. ThemeData sets the shadow colour and surface tint to transparent; no widget draws a shadow, gradient or glow. Depth is replaced by two devices: field contrast (black preview against graphite workspace) and hairline 1 px ink rules that start each band (timeline, status, phone action bar). Overlap is used only for the playhead, which runs over the track and under the ruler labels; each label sits on a workspace-coloured knockout so the red rule visibly stops above a time and resumes below it.

### Named Rules
**The No-Depth Rule.** No shadows, gradients, tints, blurs or glow anywhere. If something needs separating, give it a hairline rule or a field change.

## Shapes

Corners run 0 to 2 px. Every button, the add tile and the tooltip use the 2 px control radius; clip tiles, filmstrip frames, the missing-file chip, rules, the playhead and the progress bar are square (0 px). The keyboard focus ring follows the control radius plus its gap (4 px). Strokes come in two weights: 1 px hairlines (rules, outlines, ticks, hatching, the empty-state drop target) and 2 px marks (the playhead, the selected-clip frame, the focus ring, the progress bar); the just-edited base line is 3 px. Filmstrip frames sit 1 px apart and keep the source aspect ratio.

## Components

Controls are standard Material 3 buttons restyled flat and square; the signature is in the timecode, ruler and track.

### Buttons
- **Shape:** gently squared (2 px radius), 48 px tall minimum, icons 20 px in labelled buttons and 22 px in icon buttons.
- **Filled (primary):** ink fill, graphite text, label weight 700, 20 px side padding. Used for Export, Play/Pause, Add video in the empty state, Open after export, Retry after failure. Desktop Play is a 64 px square with a 32 px icon; phone Play is 48 px with a 26 px icon.
- **Outlined (default):** 1 px ink outline on graphite, ink text, 14 px side padding. Frame back/forward, Split, Delete, Undo, Redo, Cancel export, Share, the add tile. Disabled: outline at 20 % ink, content at 38 %.
- **Plain:** no outline, ink text, 12 px side padding. Add video in the desktop bar, Undo/Redo in the phone bar, Dismiss (close) on export results.
- **Hover / Focus:** ink overlay at 6 % (hover) and 10 % (focus) with the standard ink ripple; keyboard focus adds the focus ring.
- **Tooltips:** every control has one, ink fill with graphite 12 px text after 500 ms; on desktop it names the shortcut (S, Delete, Space, arrows, Ctrl+Z, Ctrl+Shift+Z). The shortcut never enters the accessible name.

### Top Bar
Paper on black. Lowercase "cutcap" wordmark left, controls right. Desktop 56 px with 32 px side padding and 40 px word buttons (Add video plain, Export filled); phone 64 px so its 48 dp targets clear the edges.

### Headline Timecode (signature)
The playhead time at 80 px (44 px phone), weight 700, tabular, with "/ total" on the same baseline. A 2 px red underline spans the time's width just under it; when the playhead is to the right of the time, a 1 px red line carries the underline across to the playhead rule, so the headline and the rule read as one stroke wherever the playhead stands.

### Ruler (signature)
Ink ticks along the bottom (major 14 px, minor 5 px, 1 px). Guide words in 12 px bold ink name the first and last time in view at the two ends; labelled major ticks between them are 12 px regular ink-secondary. The 10 px red square playhead head sits at the top. Pressing or dragging seeks immediately (column-resize cursor) and never waits for the frame; assistive tech gets a slider stepped one frame at a time.

### Clip Tile
Name (11 px medium ink) and length (11 px regular ink-secondary, tabular) on one line joined by " · " on desktop, stacked on the phone; parts that do not fit are dropped whole rather than cut, and names ellipsize only while they keep a minimum number of characters. Beneath, 6 px down, the filmstrip: evenly sampled thumbnails 1 px apart, frame-grey placeholders until they load. The tile is square-cornered and has no outline at rest.

### Add Tile
An outlined icon button with a plus, as tall as the film, fixed at the end of the track.

### Status Band
Under a hairline ink rule, 64 px minimum on desktop. At rest (desktop only) it is a one-line summary in 12 px ink-secondary: clip count · total · frame size · frame rate. During and after an export it becomes the export panel, so the edit above stays visible. One row on desktop (message 168 px, progress bar, actions); stacked on the phone (message, bar, actions right-aligned). Height changes animate at 200 ms; content cross-fades at 150 ms.

### States
- **Empty:** the preview collapses; only the black bar remains. Desktop: a 32 px bold heading, a 16 px ink-secondary explanation (max 560 px), then a 1 px ink-outlined drop target filling the workspace with a filled Add video and the drop hint. Phone: 24 px heading and body at the top, a full-width filled Add video at the bottom within thumb reach. The bar hides its own Add video while the empty state shows one.
- **Exporting:** status band shows "Export n %" (tabular) and a 2 px square ink progress bar on an ink-muted 35 % track, with an outlined Cancel. Progress is not announced step by step. The track is locked until the export ends: adding, clearing and every edit tool are disabled (so the file matches what is on screen), while scrubbing and playback keep working. Cancel returns the band to rest.
- **Export done:** ink check icon (20 px), message naming the file, filled Open, outlined Share (when sharing exists), plain close. Announced as a live region.
- **Export failed:** ink error-outline icon (20 px), the reason in words, then in 12 px ink-secondary a line saying the edit is intact and the exporter's own technical message (ffmpeg's last lines, untranslated), filled Retry, plain close. No red.
- **File not found clip:** the film area becomes 1 px ink diagonal hatching (45°, 7 px pitch) inside a 1 px ink border, with a centred graphite chip holding a link-off icon (14 px) and "File not found" in 12 px medium; when the clip is too narrow the chip shows the icon alone. The name and length stay above.
- **Selected:** a 2 px ink frame around the film, fading in at 150 ms.
- **Just edited:** a 3 px signal-red line along the film's base, fading in at 150 ms; it can coexist with the selected frame.
- **Disabled controls:** 38 % ink content, 20 % ink outline; they keep their place so the row never reflows.

### Touch Targets and Keyboard Focus
- Every control is at least 48 × 48 dp. The one exception is the desktop top bar, whose word buttons are 40 px tall inside the 56 px bar (desktop pointer only; the phone bar uses 48).
- The phone ruler is stretched to 56 px so scrubbing is a comfortable target.
- Keyboard focus draws a 2 px ring, 2 px clear of the control's edge, in the ambient on-surface colour (paper on the black bar, ink on the workspace). Pointer and touch focus draw no ring. Clip tiles carry the same ring and are never clipped by the track.

### Motion
150 ms (short) for fades and switches, 200 ms (standard) for size changes, reorder and ripple, on Material 3 standard easing. Under the system reduce-motion setting every duration becomes zero.

## Do's and Don'ts

### Do:
- **Do** keep signal red (#E2001A) to the playhead, its tie to the headline timecode, cut points and the just-edited clip.
- **Do** tell errors in words with an ink icon and a retry, never in colour.
- **Do** set every time with tabular figures in the one `HH:MM:SS.FF` form.
- **Do** separate bands with 1 px ink hairlines and alignment to the 12-column grid with 24 px gutters.
- **Do** use stock Material 3 buttons through the theme: filled for the one main action in a group, outlined by default, plain inside bars and for dismiss.
- **Do** give every control a 48 dp target, a tooltip, and the 2 px keyboard focus ring.
- **Do** zero all motion under reduce-motion.

### Don't:
- **Don't** add a light theme or follow the system brightness; cutcap has one graphite scheme.
- **Don't** use red for errors, warnings, Delete, selection, hover or focus.
- **Don't** use shadows, gradients, tinted containers, blur, glow or neon.
- **Don't** round corners past 2 px or build rounded tiles.
- **Don't** introduce a second typeface, a blue or any second accent colour, or a third surface colour.
- **Don't** pack the screen like a pro NLE (Premiere, DaVinci): no extra tracks, panels, sidebars or docked inspectors.
- **Don't** use ink-muted (#8C8C88) for text smaller than the 28 px total.
