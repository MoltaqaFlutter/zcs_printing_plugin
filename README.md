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

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  zcs_printing: ^1.0.0
```

If the package is in a **private Git repo** (e.g. GitHub Enterprise), use a git dependency instead:

```yaml
dependencies:
  zcs_printing:
    git:
      url: https://github.com/MoltaqaFlutter/zcs_printing_plugin.git
      ref: main   # or tag, e.g. v1.0.0
```

Then run `flutter pub get`. For private repos, ensure Git can clone the repo (SSH key or HTTPS with token).

## Android setup

1. **ZCS SDK**  
   The plugin compiles against the ZCS SDK. You need the AAR file(s) in **two** places when building:
   - **Plugin (required for compilation):** Copy into the plugin’s `android/libs/`:
     - Required: `SmartPos_2.0.1_R251024.aar`
     - Optional: `emv_2.0.1_R251023.aar` (EMV; not used by this plugin)
   - **Your app (required at runtime):** Copy the same file(s) into your app’s `android/app/libs/`.

2. **Permissions**  
   In `android/app/src/main/AndroidManifest.xml`:

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

3. **Gradle**  
   The plugin’s `android/build.gradle` already has `compileOnly fileTree(dir: 'libs', include: ['*.jar', '*.aar'])` so the plugin can compile when the AARs are in `zcs_printing/android/libs/`.  
   In your **app’s** `android/app/build.gradle`:

   ```gradle
   dependencies {
       implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
   }
   ```

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

```dart
// From bytes
await printer.appendBitmap(
  imageBytes: imageBytes,
  alignment: 'center',
);
await printer.startPrint();

// From file path
await printer.appendBitmap(
  imagePath: '/path/to/image.jpg',
  alignment: 'center',
);
await printer.startPrint();
```

### Print PDF

```dart
bool success = await printer.printPdf(
  pdfBytes,
  copies: 1,
  cutAfterEachCopy: true,
  cutBetweenPages: false,
  spacingBetweenCopies: 0,
);
```

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
- PDF printing converts each page to bitmaps then prints.
- System print uses Android `PrintHelper` or iOS `UIPrintInteractionController`; cut behavior depends on the selected printer.
- Cutter is used only when `isSupportCutter()` is true (Android only); cutting is skipped otherwise.
- `cancelPrint()` dismisses the system print sheet on iOS when it is presented; on Android it returns `false`.

## License

MIT
