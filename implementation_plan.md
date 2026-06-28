# ZCS Printer Plugin — Rebuild & PDF Quality Fix

## Background

You already have a working `zcs_printing` plugin at [MoltaqaFlutter/zcs_printing_plugin](https://github.com/MoltaqaFlutter/zcs_printing_plugin.git) (v1.0.2+3), currently consumed as a git dependency in the **Modo** app. The plugin wraps the ZCS SmartPos SDK (`SmartPos_2.0.1_R251024.aar`) with a `MethodChannel` bridge, supporting:

- Text / column / QR / barcode / bitmap buffer-based printing
- PDF printing (render → bitmap → print)
- System print dialog (Android PrintHelper + iOS UIPrintInteractionController)
- Label printing, cash drawer, paper cutter

**The core problem being solved:** PDF pages printed on ZCS thermal printers come out **fuzzy / muddy / washed-out** because the current pipeline does a simple `Bitmap.createScaledBitmap()` with bilinear filtering on an ARGB_8888 bitmap. Thermal printers are **1-bit binary** devices — every pixel is either ink or no-ink. Without proper monochrome conversion (thresholding or dithering), the driver or print-head interprets gray anti-aliased pixels as half-tones, producing a muddy result.

---

## Proposed Changes

### Component 1: Image Processing Engine (Android/Kotlin)

> A new `PdfImageProcessor` class that sits between `PdfRenderer` and the ZCS SDK.

#### [NEW] `PdfImageProcessor.kt`
**Path:** `android/src/main/kotlin/com/example/zcs_printing/PdfImageProcessor.kt`

Responsibilities:
- **High-DPI PDF rendering**: Render PDF pages at **3× the target paper width** (e.g., 384×3 = 1152 px wide for 58mm), then downscale. This gives the thresholding algorithm much more detail to work with.
- **Grayscale conversion**: Convert ARGB_8888 → grayscale using luminance formula: `L = 0.299R + 0.587G + 0.114B`
- **Gamma correction**: Apply configurable gamma (default ~1.4 for thermal paper) to lighten midtones before thresholding.
- **Background cleanup**: Detect near-white pixels (> 240 luminance) and force to pure white. This removes scanner artifacts and PDF background noise.
- **Monochrome conversion** (3 modes):
  - `SIMPLE_THRESHOLD`: Fixed threshold (default 128). Fast, good for clean vector PDFs.
  - `ADAPTIVE_THRESHOLD`: Per-block adaptive threshold (like OpenCV's `adaptiveThreshold`). Best for text-heavy receipts with varying contrast.  **(Recommended default)**
  - `FLOYD_STEINBERG`: Error-diffusion dithering. Best for images with gradients/photos. Slower.
- **Downscale to paper width**: After monochrome conversion, scale to exact `paperWidthPx` using nearest-neighbor (no interpolation — preserves sharp 1-bit edges).
- **Memory management**: Process one page at a time, recycle bitmaps immediately.

Key algorithm — **Adaptive Threshold** (simplified):
```
For each pixel (x, y):
  1. Compute mean of surrounding NxN block (N = 15..31)
  2. If pixel_value < (block_mean - C):  set BLACK
     Else: set WHITE
  (C is a small constant offset, typically 5-10)
```

Key algorithm — **Floyd-Steinberg Dithering**:
```
For each pixel (x, y) in raster order:
  old_pixel = image[x][y]
  new_pixel = (old_pixel > 128) ? 255 : 0
  error = old_pixel - new_pixel
  image[x][y] = new_pixel
  image[x+1][y]   += error * 7/16
  image[x-1][y+1] += error * 3/16
  image[x  ][y+1] += error * 5/16
  image[x+1][y+1] += error * 1/16
```

---

#### [MODIFY] [ZcsPrintingPlugin.kt](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/android/src/main/kotlin/com/example/zcs_printing/ZcsPrintingPlugin.kt)

Changes to the `printPdf` handler:
- Replace the current render → scale pipeline with `PdfImageProcessor`
- Accept new `imageMode` parameter (`"threshold"`, `"adaptive"`, `"dither"`) — maps to the 3 processing modes
- Accept new `threshold` parameter (0–255, default 128) for manual threshold control
- Accept new `gamma` parameter (0.5–3.0, default 1.4) for thermal correction
- Accept new `renderScale` parameter (1–5, default 3) to control render DPI multiplier
- The `scaleBitmapToPrinterWidth()` method remains but uses **nearest-neighbor** (`filter=false`) when working with already-monochrome bitmaps

Changes to the `appendBitmap` handler:
- Also route through `PdfImageProcessor` for optional monochrome conversion (controlled by a `convertToMonochrome` flag, default `false` to preserve backward compatibility)

---

### Component 2: Dart API Extensions

#### [MODIFY] [printing_service_interface.dart](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/lib/src/printing_service_interface.dart)

Add new parameters to `printPdf()`:
```dart
Future<bool> printPdf(
  Uint8List pdfBytes, {
  int copies = 1,
  bool cutAfterEachCopy = false,
  bool cutBetweenPages = false,
  int spacingBetweenCopies = 0,
  PaperWidth paperWidth = PaperWidth.width58mm,
  // NEW: Image processing parameters
  ImageProcessingMode imageMode = ImageProcessingMode.adaptiveThreshold,
  int threshold = 128,        // For SIMPLE_THRESHOLD mode
  double gamma = 1.4,         // Gamma correction for thermal paper
  int renderScale = 3,        // PDF render DPI multiplier (1-5)
});
```

#### [NEW] `image_processing_mode.dart`
**Path:** `lib/src/image_processing_mode.dart`

```dart
/// Controls how PDF pages are converted to monochrome for thermal printing.
enum ImageProcessingMode {
  /// Fixed threshold. Fast. Best for clean vector PDFs.
  simpleThreshold,

  /// Adaptive per-block threshold. Best for text-heavy receipts. (Default)
  adaptiveThreshold,

  /// Floyd-Steinberg error-diffusion dithering. Best for images with gradients/photos.
  floydSteinberg,

  /// No processing — send the bitmap as-is (current legacy behavior).
  /// WARNING: This will produce fuzzy output on thermal printers.
  none,
}
```

#### [MODIFY] [printer_plugin.dart](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/lib/src/printer_plugin.dart)

- Add the new parameters to the `printPdf()` implementation
- Pass `imageMode`, `threshold`, `gamma`, `renderScale` through the MethodChannel

#### [MODIFY] [zcs_printing.dart](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/lib/zcs_printing.dart)

- Add export for `image_processing_mode.dart`

---

### Component 3: Code Quality & Architecture Cleanup

#### [MODIFY] [ZcsPrintingPlugin.kt](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/android/src/main/kotlin/com/example/zcs_printing/ZcsPrintingPlugin.kt)

- **Extract method handlers** from the monolithic `onMethodCall()` into separate private methods (e.g., `handlePrintPdf()`, `handleAppendText()`, `handleAppendBitmap()`)
- **Fix thread-safety issue**: `result.success()` / `result.error()` are called from the executor thread — these must be posted back to the main thread via `activity?.runOnUiThread {}` or a `Handler(Looper.getMainLooper())`
- **Add proper bitmap recycling**: Call `bitmap.recycle()` after each page is printed to prevent OOM on multi-page PDFs
- **Add logging**: Use Android `Log.d(TAG, ...)` for debugging print pipeline issues (guarded by a debug flag)

#### [NEW] `MethodResultWrapper.kt`
**Path:** `android/src/main/kotlin/com/example/zcs_printing/MethodResultWrapper.kt`

A thread-safe wrapper around `MethodChannel.Result` that ensures responses are always posted back to the main thread. Prevents the "Reply already submitted" crash.

---

### Component 4: iOS Improvements

#### [MODIFY] [ZcsPrintingPlugin.swift](file:///Users/hossammo-dev/Desktop/Scond%20Brain/moltaqa_projects/zcs_printing_plugin/ios/Classes/ZcsPrintingPlugin.swift)

- Handle `printPdf` → convert PDF bytes to images using `CGPDFDocument` + `UIGraphicsImageRenderer`, then present via `UIPrintInteractionController` with PDF-native data (using `printingItem = pdfData` instead of converting to image)
- This gives iOS users the ability to use `printPdf()` with the system dialog instead of needing to pre-convert to image bytes

---

## Proposed File Structure (After Changes)

```
zcs_printing_plugin/
├── lib/
│   ├── zcs_printing.dart                     # [MODIFY] Add new export
│   └── src/
│       ├── printing_service_interface.dart    # [MODIFY] New params on printPdf
│       ├── printer_plugin.dart               # [MODIFY] Pass new params
│       ├── printer_error.dart                # (unchanged)
│       ├── printer_status.dart               # (unchanged)
│       ├── paper_width.dart                  # (unchanged)
│       ├── prn_str_format.dart               # (unchanged)
│       ├── print_formats.dart                # (unchanged)
│       └── image_processing_mode.dart        # [NEW]
├── android/
│   ├── build.gradle                          # (unchanged)
│   ├── libs/
│   │   └── SmartPos_2.0.1_R251024.aar        # (unchanged)
│   └── src/main/kotlin/com/example/zcs_printing/
│       ├── ZcsPrintingPlugin.kt              # [MODIFY] Refactored + new pipeline
│       ├── PdfImageProcessor.kt              # [NEW] Core image processing engine
│       └── MethodResultWrapper.kt            # [NEW] Thread-safe result wrapper
├── ios/
│   └── Classes/
│       └── ZcsPrintingPlugin.swift           # [MODIFY] PDF printing via system
└── pubspec.yaml                              # [MODIFY] Version bump to 2.0.0
```

---

## Verification Plan

### Automated Tests
- Unit tests for `PdfImageProcessor` — test each processing mode on a synthetic gradient bitmap and verify:
  - `simpleThreshold`: all output pixels are 0x000000 or 0xFFFFFF
  - `adaptiveThreshold`: same binary constraint + text edges are sharper than simple
  - `floydSteinberg`: binary constraint + visual pattern check
- Integration test: call `printPdf()` with a sample PDF on an emulator (verify no crash, correct page count)

### Manual Verification
- **Critical**: Print a real receipt PDF on a ZCS terminal with each `ImageProcessingMode` and visually compare:
  - Text legibility (especially small Arabic text)
  - Barcode/QR scannability
  - Logo/image quality
  - Overall contrast and sharpness
- Compare with the old `none` mode to confirm improvement
- Test multi-page and multi-copy scenarios
- Test paper cutter between copies
- Test on both 58mm and 80mm paper if available
