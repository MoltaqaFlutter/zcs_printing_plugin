import 'dart:io';
import 'package:flutter/services.dart';
import 'bitmap_print_options.dart';
import 'paper_width.dart';
import 'printing_service_interface.dart';
import 'printer_status.dart';
import 'printer_error.dart';
import 'prn_str_format.dart';

/// Printer plugin implementation
/// Android: Uses MethodChannel to communicate with native code
/// iOS: Returns platform unsupported errors
class PrinterPlugin implements IPrintingServiceInterface {
  static const MethodChannel _channel = MethodChannel('com.example.zcs_printing/printer');

  @override
  Future<PrinterStatus> getPrinterStatus() async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      final String statusStr = await _channel.invokeMethod('getPrinterStatus');
      return PrinterStatusExtension.fromString(statusStr);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<bool> isSupportCutter() async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      final bool result = await _channel.invokeMethod('isSupportCutter');
      return result;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendText(String text, PrnStrFormat format) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('appendText', {
        'text': text,
        'format': format.toMap(),
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendEmptyLines({
    int count = 1,
    PrnStrFormat? format,
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    if (count < 1) {
      throw PrinterError.invalidArgument('count must be at least 1');
    }

    // Use normal format if not provided
    final spacingFormat = format ?? PrnStrFormat(textSize: 26, alignment: 'left', style: 'normal', font: 'sansSerif');

    try {
      // Append empty string multiple times to create spacing
      for (int i = 0; i < count; i++) {
        await _channel.invokeMethod('appendText', {
          'text': '',
          'format': spacingFormat.toMap(),
        });
      }
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendStrings(
    List<String> texts,
    List<int> columnWidths,
    List<PrnStrFormat> formats,
  ) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('appendStrings', {
        'texts': texts,
        'columnWidths': columnWidths,
        'formats': formats.map((f) => f.toMap()).toList(),
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendQrCode(
    String data, {
    int width = 200,
    int height = 200,
    String alignment = "center",
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('appendQrCode', {
        'data': data,
        'width': width,
        'height': height,
        'alignment': alignment,
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendBarcode(
    String data, {
    String format = "CODE_128",
    int width = 360,
    int height = 100,
    bool showText = true,
    String alignment = "center",
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('appendBarcode', {
        'data': data,
        'format': format,
        'width': width,
        'height': height,
        'showText': showText,
        'alignment': alignment,
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> appendBitmap({
    Uint8List? imageBytes,
    String? imagePath,
    String alignment = "center",
    PaperWidth paperWidth = PaperWidth.width58mm,
    BitmapPrintOptions? options,
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    if (imageBytes == null && imagePath == null) {
      throw PrinterError.invalidArgument('Either imageBytes or imagePath must be provided');
    }

    try {
      await _channel.invokeMethod('appendBitmap', {
        if (imageBytes != null) 'imageBytes': imageBytes,
        if (imagePath != null) 'imagePath': imagePath,
        'alignment': alignment,
        'paperWidthPx': paperWidth.widthPx,
        ...(options ?? const BitmapPrintOptions()).toMap(),
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<bool> startPrint({
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    if (copies < 1) {
      throw PrinterError.invalidArgument('copies must be at least 1');
    }

    if (spacingBetweenCopies < 0) {
      throw PrinterError.invalidArgument('spacingBetweenCopies must be non-negative');
    }

    try {
      final bool result = await _channel.invokeMethod('startPrint', {
        'copies': copies,
        'cutAfterEachCopy': cutAfterEachCopy,
        'spacingBetweenCopies': spacingBetweenCopies,
      });
      return result;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> cutPaper() async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('cutPaper');
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> setPrintType(String paperType) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('setPrintType', {'paperType': paperType});
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> setPrintLine({int lines = 30}) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('setPrintLine', {'lines': lines});
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> printLabel(
    Uint8List bitmapBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    if (spacingBetweenCopies < 0) {
      throw PrinterError.invalidArgument('spacingBetweenCopies must be non-negative');
    }

    try {
      await _channel.invokeMethod('printLabel', {
        'bitmapBytes': bitmapBytes,
        'copies': copies,
        'cutAfterEachCopy': cutAfterEachCopy,
        'spacingBetweenCopies': spacingBetweenCopies,
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<void> openCashDrawer() async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    try {
      await _channel.invokeMethod('openCashDrawer');
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    bool cutBetweenPages = false,
    int spacingBetweenCopies = 0,
    PaperWidth paperWidth = PaperWidth.width58mm,
    BitmapPrintOptions? options,
  }) async {
    if (!Platform.isAndroid) {
      throw PrinterError.platformUnsupported();
    }

    if (spacingBetweenCopies < 0) {
      throw PrinterError.invalidArgument('spacingBetweenCopies must be non-negative');
    }

    try {
      final bool result = await _channel.invokeMethod('printPdf', {
        'pdfBytes': pdfBytes,
        'copies': copies,
        'cutAfterEachCopy': cutAfterEachCopy,
        'cutBetweenPages': cutBetweenPages,
        'spacingBetweenCopies': spacingBetweenCopies,
        'paperWidthPx': paperWidth.widthPx,
        ...(options ?? const BitmapPrintOptions()).toMap(),
      });
      return result;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<bool> printWithSystem(
    Uint8List imageBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
  }) async {
    // Supported on both Android (PrintHelper) and iOS (UIPrintInteractionController)
    try {
      final bool result = await _channel.invokeMethod('printWithSystem', {
        'imageBytes': imageBytes,
        'copies': copies,
        'cutAfterEachCopy': cutAfterEachCopy,
      });
      return result;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<bool> cancelPrint() async {
    try {
      final bool result = await _channel.invokeMethod('cancelPrint');
      return result;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Handle platform exceptions and convert to PrinterError
  PrinterError _handlePlatformException(PlatformException e) {
    if (e.code == 'platformUnsupported') {
      return PrinterError.platformUnsupported();
    }

    // Try to parse error details from platform
    final dynamic details = e.details;
    if (details is Map) {
      final String? codeStr = details['code'] as String?;
      final String? message = details['message'] as String?;
      final String? detailsStr = details['details'] as String?;

      if (codeStr != null && message != null) {
        final errorCode = PrinterErrorCodeExtension.fromString(codeStr);
        return PrinterError(
          code: errorCode,
          message: message,
          details: detailsStr,
        );
      }
    }

    // Fallback to unknown error
    return PrinterError.unknown(e.message);
  }
}

