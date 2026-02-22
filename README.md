# zcs_printing

A Flutter plugin for ZCS/SmartPos printer integration with PDF printing and system print support.

## Features

- ✅ Direct ZCS printer control (text, QR codes, barcodes, bitmaps, labels)
- ✅ PDF printing (convert PDF to bitmaps and print)
- ✅ System print support (Android PrintHelper)
- ✅ Print copies with optional cut after each copy
- ✅ Type-safe API with enums and clear error handling
- ✅ Reusable format presets for common printing scenarios

## Platform Support

- ✅ Android (full support)
- ❌ iOS (returns platform unsupported error)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  zcs_printing: ^0.0.1
```

## Setup

### Android

1. **Add ZCS SDK files**: Copy the ZCS SDK `.aar`/`.jar` files to your app's `android/app/libs/` directory
   - Required: `SmartPos_2.0.1_R251024.aar`
   - Optional: `emv_2.0.1_R251023.aar` (for EMV features, not used by this plugin)

2. **Add required permissions** to `android/app/src/main/AndroidManifest.xml`:
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

3. **Update build.gradle**: Ensure your `android/app/build.gradle` includes:
   ```gradle
   dependencies {
       implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])
   }
   ```

## Usage

### Basic Example

```dart
import 'package:zcs_printing/zcs_printing.dart';

final IPrintingServiceInterface printer = PrinterPlugin();

// Check printer status
PrinterStatus status = await printer.getPrinterStatus();
if (status == PrinterStatus.ok) {
  // Printer is ready
}

// Print text
await printer.appendText('Hello World', PrintFormats.normal);
await printer.startPrint();
```

### Print Receipt

```dart
// Build receipt
await printer.appendText('RECEIPT', PrintFormats.header);
await printer.appendText('Date: ${DateTime.now()}', PrintFormats.normal);
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
await printer.appendText('Total: \$5.00', PrintFormats.bold);

// Execute print (2 copies, cut after each)
bool success = await printer.startPrint(
  copies: 2,
  cutAfterEachCopy: true,
);
```

### Print QR Code

```dart
await printer.appendText('QR CODE', PrintFormats.header);
await printer.appendQrCode(
  'https://example.com',
  width: 300,
  height: 300,
  alignment: 'center',
);
await printer.startPrint();
```

### Print Barcode

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

### Print Image

```dart
// From bytes
Uint8List imageBytes = ...; // Your image bytes
await printer.appendBitmap(
  imageBytes: imageBytes,
  alignment: 'center',
);
await printer.startPrint();

// Or from file path
await printer.appendBitmap(
  imagePath: '/path/to/image.jpg',
  alignment: 'center',
);
await printer.startPrint();
```

### Print PDF

```dart
Uint8List pdfBytes = ...; // Your PDF bytes
bool success = await printer.printPdf(
  pdfBytes,
  copies: 1,
  cutAfterEachCopy: true,
  cutBetweenPages: false,
);
```

### Print with System (Android Print Dialog)

```dart
Uint8List imageBytes = ...; // Your image bytes
bool success = await printer.printWithSystem(
  imageBytes,
  copies: 1,
  cutAfterEachCopy: false,
);
// User will see system print dialog to choose printer or Save as PDF
```

### Error Handling

```dart
try {
  await printer.startPrint();
} on PrinterError catch (e) {
  print('Error code: ${e.code}');
  print('Error message: ${e.message}');
  // Show error.message to user
}
```

### Format Presets

Use `PrintFormats` helper class for common formats:

```dart
PrintFormats.header      // Large, centered, bold
PrintFormats.normal      // Standard text
PrintFormats.rightAligned // Right-aligned (for prices)
PrintFormats.center      // Center-aligned
PrintFormats.bold        // Bold text
PrintFormats.small       // Small text
```

### Custom Format

```dart
final format = PrnStrFormat(
  textSize: 30,
  alignment: 'center',
  style: 'bold',
  font: 'sansSerif',
  // For custom font:
  // font: 'custom',
  // path: 'fonts/CustomFont.ttf', // Asset path or file path
);
await printer.appendText('Custom Format', format);
```

## API Reference

See the [example app](example/lib/main.dart) for complete usage examples.

### Main Classes

- `IPrintingServiceInterface` - Interface for all printing operations
- `PrinterPlugin` - Implementation of the interface
- `PrinterStatus` - Enum for printer status (ok, paperOut, error, busy, offline)
- `PrinterError` - Custom error class with user-friendly messages
- `PrnStrFormat` - Format configuration for text
- `PrintFormats` - Reusable format presets

## Example App

Run the example app to see all features in action:

```bash
cd example
flutter run
```

The example includes:
- Printer status checking
- Test receipt printing
- QR code printing
- Barcode printing
- Image printing (from gallery)
- PDF printing (from file picker)

## Notes

- All printing logic is handled on the SDK side (Android native)
- iOS returns `PrinterError.platformUnsupported` for all operations
- PDF printing converts PDF pages to bitmaps before printing
- System print uses Android's PrintHelper (user selects printer or Save as PDF)
- Cut functionality only works if device supports cutter (checked automatically)

## License

MIT
