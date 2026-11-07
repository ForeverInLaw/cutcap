---
version: 1
slug: "lib-editor"
primary_target: "lib/editor"
related_targets: []
---

# Editor screen

Scope: the single editor screen of cutcap (Windows desktop window and Android phone portrait). Visitor mode: Operate.

Audience and job: the owner cuts, removes, joins and reorders clips on one track and exports an mp4, on a phone one-handed or on a PC with mouse and keyboard. Content: preview, playhead time, one track of clips with filmstrips, edit tools, export flow. Constraints: exact seeks can lag up to ~1 s, so scrubbing never blocks on the frame; Russian and English labels; 48 dp targets; visible keyboard focus.

Anti-references from the owner: a dense "pro" NLE look (Premiere/DaVinci) and dark glow/neon.

Chosen direction: Swiss grid. Memorable moment: the playhead time set as the screen's headline, tied to the frame by one red rule.

Unresolved: dark-scheme workspace tone is decided in the build; Android seek fallback may swap the preview engine without changing the screen.

## Direction contract

THESIS: The editor is set like an International Typographic Style poster: a strict modular grid, one grotesk, flat black and paper-white fields and one signal red that marks only time and cuts. It refuses the category default of a dark grey NLE with rounded tiles and a blue accent.

OWN-WORLD: Preview is a solid black #111111 field; the workspace a solid paper #F4F4F1 field with black ink, grey #8C8C88 secondary and signal red #E2001A reserved for the playhead, cut points and the just-edited clip. Golos Text with tabular figures, hairline black rules, 0–2 px radii, no shadows or gradients. Dark system theme inverts the workspace to near-black with paper ink; preview and red stay.

STORY: The visitor sees the frame, reads exactly where they are in time, and cuts, deletes, trims or drags clips with standard controls; every edit is visibly marked and undoable; export reports progress and ends in Open/Share.

FIRST VIEWPORT: Desktop: 56 px bar on black (lowercase "cutcap", Add video, Export), black preview field ~58 % high with the letterboxed frame; on paper below, a 12-column grid: left the headline timecode (~80 px, weight 700) with grey total, centre frame-back/play/frame-forward, right Split, Delete, Undo, Redo; then the ruler with guide words naming the first and last time in view; then the single track of filmstrip clips with 4 px paper gutters and an add tile at the end; a 2 px red playhead rule runs from the ruler through the track. Phone: bar with wordmark, Undo, Redo, Export; preview; headline timecode ~44 px; ruler; track; a bottom action bar with frame-back, play, frame-forward, Split, Delete, all 48 dp.

FORM: Swiss International Typographic Style, candidate 7 of 7 on the ordered list, assigned by the roll and kept by the owner. seed:4ff3f30fe9114dc8. Signature interaction: the headline timecode and the red playhead rule move as one; digits sit in fixed tabular cells and change in place. Raises: region-scale colour (zoo map), reorder that moves clips in place and holds a red marker on the edited clip (gate board), one timecode form at three sizes (bitmap specimen), ruler guide words (lexicon), fixed digit cells (split-flap). Motion grammar: 150–200 ms standard easing for reorder, ripple and state changes; none under reduce-motion.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
