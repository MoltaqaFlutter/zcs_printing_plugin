import 'package:flutter_test/flutter_test.dart';
import 'package:zcs_printing/zcs_printing.dart';

void main() {
  group('BitmapPrintOptions', () {
    test('uses tuned defaults', () {
      const options = BitmapPrintOptions();
      expect(options.renderScale, 2.5);
      expect(options.binarizationThreshold, isNull);
      expect(options.printGray, 3);
      expect(options.useMonochromeConversion, isTrue);
    });

    test('toMap omits null threshold and includes set fields', () {
      const options = BitmapPrintOptions(
        renderScale: 3.0,
        binarizationThreshold: 140,
        printGray: 4,
        useMonochromeConversion: false,
      );

      expect(options.toMap(), {
        'renderScale': 3.0,
        'binarizationThreshold': 140,
        'printGray': 4,
        'useMonochromeConversion': false,
      });
    });

    test('copyWith can clear threshold', () {
      const options = BitmapPrintOptions(binarizationThreshold: 160);
      final cleared = options.copyWith(clearBinarizationThreshold: true);
      expect(cleared.binarizationThreshold, isNull);
    });
  });
}
