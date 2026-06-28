# zcs_printing

A Flutter plugin for ZCS/SmartPos printer integration: direct printer control, PDF printing, and Android system print support.

## What it's for

This plugin connects your Flutter app to **ZCS/SmartPos** thermal printers (typically Bluetooth or USB). Use it when you need to:

- **Print receipts** (sales, returns, orders) with text, tables, and totals
- **Print QR codes or barcodes** (tickets, loyalty, product codes)
- **Print images or logos** (receipt headers, promotions)
- **Print PDFs** (invoices, reports) by converting pages to images and sending to the printer
- **Use the system print dialog** on Android and iOS so users can choose any printer or save as PDF
- **Print labels** on label-capable devices
- **Open the cash drawer** when using a connected drawer

All of this is done through a single Dart API so you can build POS, kiosk, or retail apps in Flutter without writing Android/iOS native printing code yourself.

## Who benefits

- **Flutter developers** building POS, retail, or kiosk apps that need receipt or label printing on ZCS/SmartPos hardware
- **Teams** that already use ZCS SDK on Android and want a clean Flutter API instead of platform channels and native code
- **Enterprises** that standardize on ZCS devices and want one plugin for receipts, QR/barcodes, PDFs, and system print

You need the ZCS SDK (`.aar`) and compatible ZCS/SmartPos hardware; the plugin handles the rest from Dart.

## Features

- Direct ZCS printer control: text, QR codes, barcodes, bitmaps, labels
- PDF printing (converts PDF to bitmaps and prints)
- Android and iOS system print (PrintHelper / UIPrintInteractionController: choose printer or Save as PDF)
- Cancel current print (dismiss system print sheet on iOS when applicable)
- Multiple copies with optional cut and spacing between copies
- Type-safe API with enums and clear error handling
- Reusable format presets (`PrintFormats`) for common scenarios

## Platform support

| Platform | Support |
|----------|---------|
| Android  | Full (ZCS hardware + system print) |
| iOS      | System print only (`printWithSystem`); all other methods return `PrinterError.platformUnsupported` |

## Installation

### Step 1: Add the dependency

In your app’s **`pubspec.yaml`**, add `zcs_printing` using one of the options below.

**Option A — From pub.dev** (when the package is published):

```yaml
dependencies:
  zcs_printing: ^1.0.0
```

**Option B — From a Git repo** (e.g. private GitHub or GitHub Enterprise):

```yaml
dependencies:
  zcs_printing:
    git:
      url: https://github.com/MoltaqaFlutter/zcs_printing_plugin.git
      ref: main   # or a tag, e.g. v1.0.0
```

**Option C — From a local path** (e.g. you cloned the plugin repo next to your app):

```yaml
dependencies:
  zcs_printing:
    path: ../zcs_printing
```

- For Git: ensure the repo is cloneable (SSH key or HTTPS token if private).
- Then run: **`flutter pub get`**.

### Step 2: Platform-specific setup

- **iOS:** No extra setup. System print (`printWithSystem`) works out of the box.
- **Android:** Follow the [Android setup](#android-setup-required-for-android) below. Required if your app runs on Android and uses ZCS printing or system print.

---

## Android setup (required for Android)

Do these steps **only if** your app targets Android. They are required for ZCS hardware printing and for the Android system print dialog.

### 1. ZCS SDK AAR (so the plugin can compile and run)

The plugin provides the ZCS SDK to your app transitively. You must put the AAR file(s) **inside the plugin**, not in your app.

| Who you are | What to do |
|-------------|------------|
| **Using the plugin from path or Git** | Copy the AAR into the plugin’s **`android/libs/`** folder (the `libs` folder inside the `zcs_printing` package). |
| **Using the plugin from pub.dev** | The published package must already include the AAR in `android/libs/`. If it does not, use a path or Git dependency and add the AAR as above. |

**Important for Git dependency:** If other projects depend on this plugin via `git:` (e.g. `ref: main`), the AAR must be **committed** in the plugin repo’s `android/libs/`. Otherwise `flutter build apk` fails with `:zcs_printing:compileReleaseKotlin` (unresolved ZCS types). The plugin’s `.gitignore` does not exclude `android/libs/*.aar` for this reason.

**Files:**

- **Required:** `SmartPos_2.0.1_R251024.aar`
- **Optional:** `emv_2.0.1_R251023.aar` (EMV; not used by this plugin)

**You do not** add the AAR to your app’s `android/app/libs/` or add any ZCS dependency in your app’s `build.gradle`. The plugin supplies it.

### 2. Permissions (your app)

In **your app’s** `android/app/src/main/AndroidManifest.xml`, add these permissions inside the `<manifest>` tag (needed for Bluetooth printers, storage, and NFC):

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.NFC" />
```

### 3. Gradle (your app)

**No change needed.** Place the ZCS AAR file(s) in the plugin’s `android/libs/` folder (see step 1). The plugin compiles against them and adds them to your app automatically—do **not** add the AAR or a `fileTree` to your app’s `build.gradle`.

## Usage

### Import and create printer instance

```dart
import 'package:zcs_printing/zcs_printing.dart';

final IPrintingServiceInterface printer = PrinterPlugin();
```

### Check status and cutter support

```dart
PrinterStatus status = await printer.getPrinterStatus();
bool supportsCutter = await printer.isSupportCutter();

if (status == PrinterStatus.ok) {
  // Printer ready
} else if (status == PrinterStatus.paperOut) {
  // Handle paper out
}
```

### Print text and simple receipt

Build content with `appendText`, `appendStrings`, and `appendEmptyLines`, then call `startPrint`:

```dart
await printer.appendText('RECEIPT', PrintFormats.header);
await printer.appendEmptyLines(count: 1);
await printer.appendText('Date: ${DateTime.now()}', PrintFormats.normal);
await printer.appendEmptyLines(count: 1);

// Table header
await printer.appendStrings(
  ['Item', 'Qty', 'Price'],
  [2, 1, 1],
  [PrintFormats.normal, PrintFormats.normal, PrintFormats.rightAligned],
);
await printer.appendStrings(
  ['Apple', '2', '\$5.00'],
  [2, 1, 1],
  [PrintFormats.normal, PrintFormats.normal, PrintFormats.rightAligned],
);

await printer.appendEmptyLines(count: 1);
await printer.appendText('Total: \$5.00', PrintFormats.bold);
await printer.appendEmptyLines(count: 1);

bool success = await printer.startPrint(
  copies: 2,
  cutAfterEachCopy: supportsCutter,
  spacingBetweenCopies: 2,
);
```

### Print QR code

```dart
await printer.appendText('QR CODE', PrintFormats.header);
await printer.appendEmptyLines(count: 1);
await printer.appendQrCode(
  'https://example.com',
  width: 300,
  height: 300,
  alignment: 'center',
);
await printer.startPrint();
```

### Print barcode

```dart
await printer.appendText('BARCODE', PrintFormats.header);
await printer.appendBarcode(
  '6922711079066',
  format: 'CODE_128',
  width: 360,
  height: 100,
  showText: true,
  alignment: 'center',
);
await printer.startPrint();
```

### Print image (bytes or file path)

Images are scaled to fit paper width (same as PDF). Use [PaperWidth] to match your roll; default is 58mm.

```dart
// From bytes (default 58mm)
await printer.appendBitmap(
  imageBytes: imageBytes,
  alignment: 'center',
);
await printer.startPrint();

// From file path, 80mm paper
await printer.appendBitmap(
  imagePath: '/path/to/image.jpg',
  alignment: 'center',
  paperWidth: PaperWidth.width80mm,
);
await printer.startPrint();
```

### Print PDF

PDF pages are scaled to fit the paper width (small PDFs are enlarged, large ones shrunk). Use the [PaperWidth] enum for standard sizes; default is **58mm**. After the last page of each copy, a few blank lines are added to leave space for the cutter.

| Enum value | Paper width |
|------------|-------------|
| `PaperWidth.width55mm` | 55 mm (narrow rolls) |
| `PaperWidth.width58mm` | **58 mm (default)** |
| `PaperWidth.width80mm` | 80 mm (wide receipts/invoices) |

```dart
import 'package:zcs_printing/zcs_printing.dart';

// Default 58mm
bool success = await printer.printPdf(pdfBytes, cutAfterEachCopy: true);

// 80mm POS paper
bool success = await printer.printPdf(
  pdfBytes,
  copies: 1,
  cutAfterEachCopy: true,
  cutBetweenPages: false,
  paperWidth: PaperWidth.width80mm,
);

// Tune PDF/image thermal quality (Android)
bool tuned = await printer.printPdf(
  pdfBytes,
  options: BitmapPrintOptions(
    renderScale: 2.0,
    printGray: 3,
    binarizationThreshold: null, // null = auto (Otsu)
  ),
);
```

### Print quality (PDF and images)

PDF and image jobs are rasterized on Android before sending to the thermal printer. The plugin applies **2x supersampling**, **contrast normalization**, and **adaptive binarization (Otsu)** by default to reduce fuzzy or muddy text.

Optional tuning via [`BitmapPrintOptions`](lib/src/bitmap_print_options.dart):

| Option | Default | Description |
|--------|---------|-------------|
| `renderScale` | `2.0` | PDF supersampling factor (1.0–3.0) |
| `binarizationThreshold` | `null` (auto) | Manual B/W threshold 0–255, or null for Otsu |
| `printGray` | `3` | Thermal density (0–5), maps to ZCS `setPrintGray` |
| `useMonochromeConversion` | `true` | Set false to send grayscale to the SDK |

```dart
await printer.appendBitmap(
  imageBytes: imageBytes,
  options: BitmapPrintOptions(printGray: 4, renderScale: 2.0),
);
```

**Debug builds:** processed bitmaps are saved to the app cache as `print_preview_*.png` for before/after comparison on device.

**Tuning tip:** Use the example app's **Print Quality (Debug)** panel to adjust settings, re-print the same PDF, then copy optimal values into your app.

**Note:** Native text via `appendText` is not affected. For sharpest Arabic/Latin receipts, prefer `appendText` with a custom font over printing text as PDF when possible.

### System print (Android / iOS)

Shows the system print dialog so the user can pick a printer or Save as PDF. On Android uses PrintHelper; on iOS uses the system print sheet (UIPrintInteractionController).

```dart
bool success = await printer.printWithSystem(
  imageBytes,
  copies: 1,
  cutAfterEachCopy: false,
);
```

### Cancel print

Cancel the current printing operation if possible. On iOS, dismisses the system print sheet when it is open. On Android, the system print dialog cannot be dismissed programmatically (returns `false`).

```dart
bool cancelled = await printer.cancelPrint();
if (cancelled) {
  // Print sheet was dismissed (e.g. on iOS)
}
```

### Label mode

```dart
await printer.setPrintType('label');   // or 'label80mm'
await printer.setPrintLine(lines: 30);
await printer.printLabel(
  labelImageBytes,
  copies: 1,
  cutAfterEachCopy: true,
  spacingBetweenCopies: 0,
);
```

### Cash drawer and cut

```dart
await printer.openCashDrawer();
await printer.cutPaper();   // No-op if device has no cutter
```

### Error handling

```dart
try {
  await printer.startPrint();
} on PrinterError catch (e) {
  // e.code, e.message
  showError(e.message);
}
```

### Text format presets

| Preset            | Description              |
|-------------------|--------------------------|
| `PrintFormats.header`       | Large, centered, bold    |
| `PrintFormats.normal`       | Standard text            |
| `PrintFormats.rightAligned` | Right-aligned (e.g. prices) |
| `PrintFormats.center`       | Center-aligned           |
| `PrintFormats.bold`         | Bold                     |
| `PrintFormats.small`        | Small text               |

### Custom format

```dart
final format = PrnStrFormat(
  textSize: 30,
  alignment: 'center',
  style: 'bold',
  font: 'sansSerif',
  // font: 'custom', path: 'fonts/CustomFont.ttf',
);
await printer.appendText('Custom', format);
```

## API reference

| Type                      | Description |
|---------------------------|-------------|
| `IPrintingServiceInterface` | Interface for all printing operations |
| `PrinterPlugin`           | Default implementation (use this) |
| `PrinterStatus`           | `ok`, `paperOut`, `error`, `busy`, `offline` |
| `PaperWidth`              | Paper size for PDF: `width55mm`, `width58mm` (default), `width80mm` |
| `PrinterError`            | Error with `code` and `message` |
| `PrnStrFormat`             | Text format (size, alignment, style, font) |
| `PrintFormats`            | Preset formats (header, normal, bold, etc.) |
| `cancelPrint()`           | Dismiss system print sheet (iOS) or no-op (Android); returns `true` if cancelled |

Full usage examples: [example/lib/main.dart](example/lib/main.dart).

## Example app

```bash
cd example
flutter run
```

The example demonstrates: status check, receipt, QR, barcode, image (gallery), PDF (file picker), system print (Android and iOS), and cancel print.

## Notes

- Printing is implemented via the ZCS SDK on Android; on iOS only system print (`printWithSystem`) is supported.
- PDF printing converts each page to bitmaps, scales to fit paper width using [PaperWidth] (pixel width from [PaperWidth.widthPx]). Default is 58mm.
- System print uses Android `PrintHelper` or iOS `UIPrintInteractionController`; cut behavior depends on the selected printer.
- Cutter is used only when `isSupportCutter()` is true (Android only); cutting is skipped otherwise.
- `cancelPrint()` dismisses the system print sheet on iOS when it is presented; on Android it returns `false`.

## License

Copyright (c) 2025 Moltaqa. Licensed under the [MIT License](LICENSE).
