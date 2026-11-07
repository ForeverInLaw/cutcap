import 'package:cutcap/domain/edit_list.dart';
import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/domain/source.dart';
import 'package:cutcap/export/export_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

Source source(
  String id, {
  Resolution resolution = (width: 1920, height: 1080),
  int rotation = 0,
  FrameRate rate = const FrameRate(30, 1),
  FrameRate? averageRate,
  bool hasAudio = true,
  int? videoBitRate = 8000000,
}) => Source(
  id: SourceId(id),
  path: 'C:/videos/$id.mp4',
  duration: const Duration(seconds: 60),
  resolution: resolution,
  rotation: rotation,
  frameRate: rate,
  hasAudio: hasAudio,
  averageFrameRate: averageRate,
  videoBitRate: videoBitRate,
);

/// An edit list of (source, in ms, out ms) clips.
EditList edit(List<(Source, int, int)> spans) => EditList(
  clips: [
    for (final (index, (source, inMs, outMs)) in spans.indexed)
      Clip(
        id: ClipId(index),
        sourceId: source.id,
        inPoint: ms(inMs),
        outPoint: ms(outMs),
      ),
  ],
  sources: {for (final (source, _, _) in spans) source.id: source},
);

void main() {
  group('output format', () {
    test('takes size and rate from the first clip', () {
      final plan = ExportPlan.of(
        edit([
          (source('a', resolution: (width: 1280, height: 720)), 0, 1000),
          (
            source(
              'b',
              resolution: (width: 640, height: 480),
              rate: const FrameRate(25, 1),
            ),
            0,
            1000,
          ),
        ]),
      )!;

      expect(plan.size, (width: 1280, height: 720));
      expect(plan.frameRate, const FrameRate(30, 1));
    });

    test('uses the upright size of a rotated first clip', () {
      ExportPlan planFor(int rotation) => ExportPlan.of(
        edit([
          (
            source(
              'phone',
              resolution: (width: 1920, height: 1080),
              rotation: rotation,
            ),
            0,
            1000,
          ),
        ]),
      )!;

      expect(planFor(90).size, (width: 1080, height: 1920));
      expect(planFor(270).size, (width: 1080, height: 1920));
      expect(planFor(180).size, (width: 1920, height: 1080));
    });

    FrameRate rateFor(FrameRate nominal, FrameRate average) => ExportPlan.of(
      edit([(source('a', rate: nominal, averageRate: average), 0, 1000)]),
    )!.frameRate;

    test('rounds a variable first clip to the nearest standard rate', () {
      // ADR 0002 fixture: 30 fps then 20 fps, r_frame_rate 60, avg 25.28.
      expect(
        rateFor(const FrameRate(60, 1), const FrameRate(2250, 89)),
        const FrameRate(25, 1),
      );
      expect(
        rateFor(const FrameRate(90000, 1), const FrameRate(47, 1)),
        const FrameRate(50, 1),
      );
      expect(
        rateFor(const FrameRate(120, 1), const FrameRate(1000, 41)),
        const FrameRate(24, 1),
      );
    });

    test('keeps the nominal rate when the average is within 0.1 %', () {
      expect(
        rateFor(const FrameRate(30000, 1001), const FrameRate(2997, 100)),
        const FrameRate(30000, 1001),
      );
    });
  });
  group('video bitrate', () {
    int bitRateFor(int? sourceBitRate) => ExportPlan.of(
      edit([(source('a', videoBitRate: sourceBitRate), 0, 1000)]),
    )!.videoBitRate;

    test("follows the first clip's video bitrate", () {
      expect(bitRateFor(12000000), 12000000);
    });

    test('stays within 1 to 50 Mb/s', () {
      expect(bitRateFor(300000), 1000000);
      expect(bitRateFor(120000000), 50000000);
    });

    test('is estimated at 0.1 bit per pixel when the source does not say', () {
      // 1920 × 1080 × 30 fps × 0.1.
      expect(bitRateFor(null), 6220800);
    });
  });
  group('clips', () {
    test(
      'skip missing sources, and the first present clip sets the format',
      () {
        final gone = source('gone', resolution: (width: 640, height: 480));
        final kept = source('kept', resolution: (width: 1280, height: 720));
        final plan = ExportPlan.of(
          edit([(gone, 0, 1000), (kept, 0, 2000), (gone, 0, 3000)]),
          missingSources: {gone.id},
        )!;

        expect(plan.clips.map((clip) => clip.path), [kept.path]);
        expect(plan.size, (width: 1280, height: 720));
        expect(plan.duration, ms(2000));
      },
    );

    test('there is nothing to export when every source is missing', () {
      final gone = source('gone');
      expect(
        ExportPlan.of(edit([(gone, 0, 1000)]), missingSources: {gone.id}),
        isNull,
      );
      expect(ExportPlan.of(const EditList()), isNull);
    });

    test('seek half a source frame before the in point', () {
      // Frame 61 at 30 fps starts at 2.033333 s (ADR 0002).
      final a = source('a');
      final plan = ExportPlan.of(
        EditList(
          clips: [
            Clip(
              id: const ClipId(0),
              sourceId: a.id,
              inPoint: const Duration(microseconds: 2033333),
              outPoint: const Duration(seconds: 5),
            ),
          ],
          sources: {a.id: a},
        ),
      )!;

      expect(plan.clips.single.seek, const Duration(microseconds: 2016667));
      expect(plan.clips.single.duration, const Duration(microseconds: 2966667));
    });

    test('each last a whole number of output frames', () {
      final plan = ExportPlan.of(
        edit([
          (source('a'), 0, 1000),
          (source('b', rate: const FrameRate(25, 1)), 400, 1420),
        ]),
      )!;

      // 1.02 s at 30 fps is 30.6 frames, rounded to 31.
      expect(plan.clips.map((clip) => clip.frames), [30, 31]);
      expect(plan.duration, const Duration(microseconds: 2033333));
    });

    test('get audio samples that never drift from the video', () {
      const ntsc = FrameRate(30000, 1001);
      final a = source('a', rate: ntsc);
      // One frame at 29.97 fps is 1601.6 samples at 48 kHz.
      final plan = ExportPlan.of(
        EditList(
          clips: [
            for (var i = 0; i < 3; i++)
              Clip(
                id: ClipId(i),
                sourceId: a.id,
                inPoint: ntsc.frameStart(i),
                outPoint: ntsc.frameStart(i + 1),
              ),
          ],
          sources: {a.id: a},
        ),
      )!;

      expect(plan.clips.map((clip) => clip.frames), [1, 1, 1]);
      expect(plan.clips.map((clip) => clip.audioSamples), [1602, 1601, 1602]);
    });

    test('carry whether their source has audio', () {
      final plan = ExportPlan.of(
        edit([(source('a'), 0, 1000), (source('b', hasAudio: false), 0, 1000)]),
      )!;

      expect(plan.clips.map((clip) => clip.hasAudio), [true, false]);
    });
  });
}
