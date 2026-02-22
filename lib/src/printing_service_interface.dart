import 'dart:typed_data';
import 'printer_status.dart';
import 'prn_str_format.dart';

/// Interface for printing service
/// Implemented by PrinterPlugin (Android) and stub (iOS)
abstract class IPrintingServiceInterface {
  /// Get current printer status
  /// 
  /// Returns: PrinterStatus enum indicating current printer state
  /// 
  /// Usage:
  ///   PrinterStatus status = await printer.getPrinterStatus();
  ///   if (status == PrinterStatus.ok) {
  ///     // Printer is ready
  ///   } else if (status == PrinterStatus.paperOut) {
  ///     // Handle paper out
  ///   }
  Future<PrinterStatus> getPrinterStatus();

  /// Check if device supports paper cutter
  /// Returns: true if cutter is available, false otherwise
  Future<bool> isSupportCutter();

  /// Append text to print buffer
  /// 
  /// Usage: Call multiple times to build a document, then call startPrint() to execute.
  /// Example: 
  ///   await printer.appendText("Header", format);
  ///   await printer.appendText("Body text", format);
  ///   await printer.startPrint();
  /// 
  /// [text] - The text string to print. Can contain newlines (\n) for line breaks.
  /// [format] - Formatting options (textSize, alignment, style, font, custom font path).
  Future<void> appendText(String text, PrnStrFormat format);

  /// Append empty lines (blank spacing) to print buffer
  /// 
  /// Usage: Add vertical spacing between content sections.
  /// Example:
  ///   await printer.appendText("Header", format);
  ///   await printer.appendEmptyLines(2);  // Add 2 blank lines
  ///   await printer.appendText("Body", format);
  /// 
  /// [count] - Number of empty lines to add (default: 1, minimum: 1)
  /// [format] - Optional format for the empty lines. If not provided, uses normal format.
  Future<void> appendEmptyLines({
    int count = 1,
    PrnStrFormat? format,
  });

  /// Append multiple strings in columns to print buffer
  /// 
  /// Usage: Print table rows with aligned columns.
  /// Example:
  ///   await printer.appendStrings(
  ///     ["Item", "Qty", "Price"],
  ///     [2, 1, 1],  // Column width ratios
  ///     [format, format, rightFormat]
  ///   );
  /// 
  /// [texts] - List of strings, one per column
  /// [columnWidths] - List of integers representing width ratios
  /// [formats] - List of PrnStrFormat, one per column
  Future<void> appendStrings(
    List<String> texts,
    List<int> columnWidths,
    List<PrnStrFormat> formats,
  );

  /// Append QR code to print buffer
  /// 
  /// Usage: Generate QR code from data string.
  /// Example: await printer.appendQrCode("https://example.com", width: 200, height: 200);
  /// 
  /// [data] - String to encode as QR code (URL, text, etc.)
  /// [width] - QR code width in pixels (default: 200)
  /// [height] - QR code height in pixels (default: 200)
  /// [alignment] - String ("left", "center", "right") - QR code alignment (default: "center")
  Future<void> appendQrCode(
    String data, {
    int width = 200,
    int height = 200,
    String alignment = "center",
  });

  /// Append barcode to print buffer
  /// 
  /// Usage: Print barcode (e.g. CODE_128, EAN13).
  /// Example: await printer.appendBarcode("6922711079066", format: "CODE_128");
  /// 
  /// [data] - String to encode as barcode
  /// [format] - String ("CODE_128", "EAN13", etc.) - Barcode format (default: "CODE_128")
  /// [width] - Barcode width in pixels (default: 360)
  /// [height] - Barcode height in pixels (default: 100)
  /// [showText] - bool - Show human-readable text below barcode (default: true)
  /// [alignment] - String ("left", "center", "right") - Barcode alignment (default: "center")
  Future<void> appendBarcode(
    String data, {
    String format = "CODE_128",
    int width = 360,
    int height = 100,
    bool showText = true,
    String alignment = "center",
  });

  /// Append bitmap image to print buffer
  /// 
  /// Usage: Print image from bytes or file path.
  /// Example: await printer.appendBitmap(imageBytes: imageBytes);
  /// 
  /// [imageBytes] - Uint8List - Image bytes (PNG, JPEG, BMP supported)
  /// OR
  /// [imagePath] - String - Path to image file on device
  /// [alignment] - String ("left", "center", "right") - Image alignment (default: "center")
  /// 
  /// Note: Only provide either imageBytes OR imagePath, not both.
  Future<void> appendBitmap({
    Uint8List? imageBytes,
    String? imagePath,
    String alignment = "center",
  });

  /// Execute print buffer - Print all content added via appendText/appendStrings/etc.
  /// 
  /// What it does:
  /// - Sends all buffered content (text, QR, barcode, bitmap) to the printer
  /// - Prints [copies] number of copies
  /// - Adds [spacingBetweenCopies] empty lines between each copy (if copies > 1)
  /// - If [cutAfterEachCopy] is true and device supports cutter, cuts paper after each copy
  /// - Clears the buffer after printing
  /// 
  /// [copies] - Number of copies to print (default: 1, minimum: 1)
  /// [cutAfterEachCopy] - If true and device supports cutter, cut paper after each copy (default: false)
  /// [spacingBetweenCopies] - Number of empty lines to add between copies (default: 0, only applies when copies > 1)
  /// 
  /// Returns: bool - true if print was successful, false if failed
  /// 
  /// Throws: PrinterError if printer is unavailable, paper out, or other error occurs
  /// 
  /// Example:
  ///   await printer.appendText("Receipt", format);
  ///   await printer.startPrint(copies: 3, spacingBetweenCopies: 2);  // Print 3 copies with 2 blank lines between each
  Future<bool> startPrint({
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  });

  /// Cut paper immediately
  /// 
  /// Usage: Cut paper without printing (e.g. after manual feed).
  /// If device does not support cutter, this is a no-op (no error).
  Future<void> cutPaper();

  /// Set printer to label mode
  /// 
  /// Usage: Switch printer to label paper mode before printLabel().
  /// [paperType] - String ("label" or "label80mm") - Label paper type
  Future<void> setPrintType(String paperType);

  /// Set number of lines to feed for label paper
  /// 
  /// Usage: Feed label paper before/after printing.
  /// [lines] - int - Number of lines to feed (default: 30)
  Future<void> setPrintLine({int lines = 30});

  /// Print label (bitmap image)
  /// 
  /// Usage: Print image on label paper.
  /// Example: await printer.printLabel(labelImageBytes, copies: 3, cutAfterEachCopy: true);
  /// 
  /// [bitmapBytes] - Uint8List - Image bytes for label
  /// [copies] - Number of copies to print (default: 1)
  /// [cutAfterEachCopy] - If true and device supports cutter, cut after each copy (default: false)
  /// [spacingBetweenCopies] - Number of empty lines to add between copies (default: 0, only applies when copies > 1)
  Future<void> printLabel(
    Uint8List bitmapBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  });

  /// Open cash drawer
  /// 
  /// Usage: Trigger cash drawer to open.
  Future<void> openCashDrawer();

  /// Print PDF document
  /// 
  /// Usage: Convert PDF to bitmaps and print each page on ZCS device.
  /// Example: await printer.printPdf(pdfBytes, copies: 2, cutAfterEachCopy: true);
  /// 
  /// [pdfBytes] - Uint8List - PDF file bytes
  /// [copies] - Number of copies to print (default: 1)
  /// [cutAfterEachCopy] - If true and device supports cutter, cut after each full copy (default: false)
  /// [cutBetweenPages] - If true and device supports cutter, cut between PDF pages (default: false)
  /// [spacingBetweenCopies] - Number of empty lines to add between copies (default: 0, only applies when copies > 1)
  /// 
  /// Returns: bool - true if print was successful, false if failed
  /// 
  /// Throws: PrinterError if PDF is invalid, printer unavailable, or other error occurs
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    bool cutBetweenPages = false,
    int spacingBetweenCopies = 0,
  });

  /// Print using Android system print dialog (any printer or Save as PDF)
  /// 
  /// Usage: Show system print dialog so user can choose printer or save as PDF.
  /// Example: await printer.printWithSystem(imageBytes, copies: 2);
  /// 
  /// [imageBytes] - Uint8List - Image bytes (PNG, JPEG, BMP)
  /// [copies] - Number of copies to print (default: 1)
  /// [cutAfterEachCopy] - If true, attempt to cut after each copy (only works if system printer supports it; may be ignored) (default: false)
  /// 
  /// Returns: bool - true if print dialog was shown successfully, false if failed
  /// 
  /// Throws: PrinterError if image is invalid, printer unavailable, or other error occurs
  /// 
  /// Note: This uses Android PrintHelper, not ZCS SDK. User selects printer or "Save as PDF" in dialog.
  /// Cut functionality depends on selected printer capabilities.
  Future<bool> printWithSystem(
    Uint8List imageBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
  });
}
