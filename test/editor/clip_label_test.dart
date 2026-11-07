import 'package:cutcap/editor/clip_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Widths in px: a name that needs 120 whole and 60 for its first eight
  // characters plus an ellipsis; a length that needs 62; " · " needs 10.
  ClipLabelParts fit(double width, {required bool stacked}) => ClipLabel.fit(
    width: width,
    nameWidth: 120,
    nameMinWidth: 60,
    lengthWidth: 62,
    separatorWidth: 10,
    stacked: stacked,
  );

  group('stacked (phone)', () {
    test('keeps both lines when each fits on its own', () {
      expect(fit(70, stacked: true), (name: true, length: true));
    });

    test('drops a length that would be cut instead of truncating it', () {
      expect(fit(61, stacked: true), (name: true, length: false));
    });

    test('drops a name that would show fewer than eight characters', () {
      expect(fit(59, stacked: true), (name: false, length: false));
    });
  });

  group('inline (desktop)', () {
    test('keeps both while the name can still show eight characters', () {
      expect(fit(132, stacked: false), (name: true, length: true));
    });

    test('gives up the length first, then the name', () {
      expect(fit(131, stacked: false), (name: true, length: false));
      expect(fit(59, stacked: false), (name: false, length: false));
    });

    test('keeps the length alone when the name has no room', () {
      expect(
        ClipLabel.fit(
          width: 64,
          nameWidth: 200,
          nameMinWidth: 70,
          lengthWidth: 62,
          separatorWidth: 10,
          stacked: false,
        ),
        (name: false, length: true),
      );
    });
  });
}
