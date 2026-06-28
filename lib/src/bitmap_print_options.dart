/// Options for PDF and bitmap thermal print quality on Android.
///
/// Defaults are tuned for sharp text on 58mm/80mm rolls. Override per job
/// when you need to tune output on a specific device or paper type.
class BitmapPrintOptions {
  /// Supersampling factor for PDF rendering (1.0–4.0). Higher values can
  /// improve text sharpness at the cost of memory and processing time.
  final double renderScale;

  /// Manual black/white threshold (0–255). When null, Otsu's method is used.
  final int? binarizationThreshold;

  /// Thermal print density (0 = lightest, 5 = darkest). Maps to ZCS setPrintGray.
  final int printGray;

  /// When false, skips plugin binarization and sends grayscale to the SDK.
  final bool useMonochromeConversion;

  const BitmapPrintOptions({
    this.renderScale = 2.5,
    this.binarizationThreshold,
    this.printGray = 3,
    this.useMonochromeConversion = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'renderScale': renderScale,
      if (binarizationThreshold != null)
        'binarizationThreshold': binarizationThreshold,
      'printGray': printGray,
      'useMonochromeConversion': useMonochromeConversion,
    };
  }

  BitmapPrintOptions copyWith({
    double? renderScale,
    int? binarizationThreshold,
    bool clearBinarizationThreshold = false,
    int? printGray,
    bool? useMonochromeConversion,
  }) {
    return BitmapPrintOptions(
      renderScale: renderScale ?? this.renderScale,
      binarizationThreshold: clearBinarizationThreshold
          ? null
          : (binarizationThreshold ?? this.binarizationThreshold),
      printGray: printGray ?? this.printGray,
      useMonochromeConversion:
          useMonochromeConversion ?? this.useMonochromeConversion,
    );
  }
}
