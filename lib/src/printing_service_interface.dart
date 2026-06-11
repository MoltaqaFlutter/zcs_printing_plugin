import 'dart:typed_data';
import 'paper_width.dart';
import 'printer_status.dart';
import 'prn_str_format.dart';
import 'image_processing_mode.dart';

/// Main interface for ZCS/SmartPos printing from Flutter.
///
/// Use [PrinterPlugin] as the implementation. All methods that talk to the
/// printer (receipts, PDF, images, QR, barcode) are defined here with clear
/// parameter docs. Check each method's documentation for:
/// - **Usage**: when to call it and in what order (e.g. append then startPrint).
/// - **Parameters**: what each argument does and default values.
/// - **Returns / Throws**: success value and possible errors.
///
/// Supported on Android (ZCS hardware + system print). On iOS only
/// [printWithSystem] is supported; other methods throw [PrinterError].
abstract class IPrintingServiceInterface {
  /// Get current printer status.
  ///
  /// **Returns:** [PrinterStatus] — e.g. [PrinterStatus.ok], [PrinterStatus.paperOut].
  ///
  /// **Usage:** Call before printing to avoid errors (e.g. paper out).
  ///
  /// Example:
  /// ```dart
  /// final status = await printer.getPrinterStatus();
  /// if (status == PrinterStatus.ok) {
  ///   await printer.startPrint();
  /// } else if (status == PrinterStatus.paperOut) {
  ///   showError('Load paper');
  /// }
  /// ```
  Future<PrinterStatus> getPrinterStatus();

  /// Check if the device supports a paper cutter.
  ///
  /// **Returns:** `true` if cutter is available, `false` otherwise.
  /// Use this to decide whether to pass [cutAfterEachCopy] or [cutBetweenPages].
  Future<bool> isSupportCutter();

  /// Append text to the print buffer.
  ///
  /// **Parameters:**
  /// - [text] — String to print. Can contain `\n` for line breaks.
  /// - [format] — [PrnStrFormat] for size, alignment, style, font (or use [PrintFormats] presets).
  ///
  /// **Usage:** Call one or more append methods, then [startPrint]. Buffer is cleared after print.
  ///
  /// Example:
  /// ```dart
  /// await printer.appendText('Header', PrintFormats.header);
  /// await printer.appendText('Body text', PrintFormats.normal);
  /// await printer.startPrint();
  /// ```
  Future<void> appendText(String text, PrnStrFormat format);

  /// Append empty lines (blank spacing) to the print buffer.
  ///
  /// **Parameters:**
  /// - [count] — Number of empty lines (default: 1, minimum: 1).
  /// - [format] — Optional format for the lines; if null, uses normal format.
  ///
  /// **Usage:** Add vertical spacing between sections (e.g. after header, before total).
  Future<void> appendEmptyLines({
    int count = 1,
    PrnStrFormat? format,
  });

  /// Append a row of strings in columns (e.g. table row).
  ///
  /// **Parameters:**
  /// - [texts] — One string per column (e.g. `['Item', 'Qty', 'Price']`).
  /// - [columnWidths] — Width ratios per column (e.g. `[2, 1, 1]`).
  /// - [formats] — One [PrnStrFormat] per column (e.g. normal for first two, rightAligned for price).
  ///
  /// **Usage:** Call for each row, then [startPrint]. Good for receipts and tables.
  Future<void> appendStrings(
    List<String> texts,
    List<int> columnWidths,
    List<PrnStrFormat> formats,
  );

  /// Append a QR code to the print buffer.
  ///
  /// **Parameters:**
  /// - [data] — String to encode (URL, ticket id, etc.).
  /// - [width] — QR width in pixels (default: 200).
  /// - [height] — QR height in pixels (default: 200).
  /// - [alignment] — `"left"`, `"center"`, or `"right"` (default: `"center"`).
  ///
  /// **Usage:** Append other content as needed, then [startPrint].
  Future<void> appendQrCode(
    String data, {
    int width = 200,
    int height = 200,
    String alignment = "center",
  });

  /// Append a barcode to the print buffer.
  ///
  /// **Parameters:**
  /// - [data] — String to encode (e.g. product code).
  /// - [format] — Barcode format, e.g. `"CODE_128"`, `"EAN13"` (default: `"CODE_128"`).
  /// - [width] — Barcode width in pixels (default: 360).
  /// - [height] — Barcode height in pixels (default: 100).
  /// - [showText] — Whether to show the number below the barcode (default: true).
  /// - [alignment] — `"left"`, `"center"`, or `"right"` (default: `"center"`).
  Future<void> appendBarcode(
    String data, {
    String format = "CODE_128",
    int width = 360,
    int height = 100,
    bool showText = true,
    String alignment = "center",
  });

  /// Append a bitmap image to the print buffer.
  ///
  /// The image is scaled to fit [paperWidth] (same as PDF) using [PaperWidth.widthPx].
  ///
  /// **Parameters:**
  /// - [imageBytes] — Image bytes (PNG, JPEG, BMP), or
  /// - [imagePath] — Path to an image file on device. Provide exactly one of these.
  /// - [alignment] — `"left"`, `"center"`, or `"right"` (default: `"center"`).
  /// - [paperWidth] — Paper size to scale image to (default [PaperWidth.width58mm]).
  ///
  /// **Usage:** Append other content if needed, then [startPrint].
  Future<void> appendBitmap({
    Uint8List? imageBytes,
    String? imagePath,
    String alignment = "center",
    PaperWidth paperWidth = PaperWidth.width58mm,
    bool convertToMonochrome = false,
  });

  /// Send the print buffer to the printer and clear the buffer.
  ///
  /// Prints all content added with [appendText], [appendStrings], [appendQrCode],
  /// [appendBarcode], [appendBitmap]. After printing, the buffer is cleared.
  ///
  /// **Parameters:**
  /// - [copies] — Number of copies (default: 1, minimum: 1).
  /// - [cutAfterEachCopy] — If true and device has cutter, cut after each copy (default: false).
  /// - [spacingBetweenCopies] — Empty lines between copies when copies > 1 (default: 0).
  ///
  /// **Returns:** `true` if print succeeded, `false` otherwise.
  ///
  /// **Throws:** [PrinterError] if printer unavailable, paper out, etc.
  Future<bool> startPrint({
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  });

  /// Cut paper immediately (no-op if device has no cutter).
  ///
  /// **Usage:** e.g. after manual feed or to leave a clean edge.
  Future<void> cutPaper();

  /// Set printer to label paper mode (required before [printLabel]).
  ///
  /// **Parameters:**
  /// - [paperType] — `"label"` or `"label80mm"` to match your label roll.
  Future<void> setPrintType(String paperType);

  /// Set number of lines to feed for label paper.
  ///
  /// **Parameters:**
  /// - [lines] — Number of lines to feed (default: 30). Use for label positioning.
  Future<void> setPrintLine({int lines = 30});

  /// Print a bitmap on label paper (call [setPrintType] and optionally [setPrintLine] first).
  ///
  /// **Parameters:**
  /// - [bitmapBytes] — Image bytes for the label.
  /// - [copies] — Number of labels to print (default: 1).
  /// - [cutAfterEachCopy] — Cut after each label if cutter supported (default: false).
  /// - [spacingBetweenCopies] — Empty lines between copies when copies > 1 (default: 0).
  Future<void> printLabel(
    Uint8List bitmapBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    int spacingBetweenCopies = 0,
  });

  /// Open the connected cash drawer.
  ///
  /// **Usage:** Call when you need to open the drawer (e.g. after cash sale).
  Future<void> openCashDrawer();

  /// Print a PDF by converting each page to an image and scaling to fit paper width.
  ///
  /// PDF pages are scaled to use the full paper width (small PDFs enlarged, large ones shrunk).
  /// Use [paperWidth] to match your roll; pixel width is taken from [PaperWidth.widthPx].
  ///
  /// **Parameters:**
  /// - [pdfBytes] — Raw PDF file bytes.
  /// - [copies] — Number of copies (default: 1).
  /// - [cutAfterEachCopy] — Cut after each full copy if cutter supported (default: false).
  /// - [cutBetweenPages] — Cut between PDF pages if cutter supported (default: false).
  /// - [spacingBetweenCopies] — Empty lines between copies when copies > 1 (default: 0).
  /// - [paperWidth] — Paper size (default [PaperWidth.width58mm]). Use [PaperWidth.width80mm] for 80 mm; pixel width from [PaperWidth.widthPx].
  ///
  /// **Returns:** `true` if print succeeded, `false` otherwise.
  ///
  /// **Throws:** [PrinterError] if PDF is invalid or printer unavailable.
  ///
  /// Example:
  /// ```dart
  /// await printer.printPdf(pdfBytes, paperWidth: PaperWidth.width80mm);
  /// await printer.printPdf(pdfBytes, copies: 2, cutAfterEachCopy: true);  // default 58mm
  /// ```
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
    bool cutBetweenPages = false,
    int spacingBetweenCopies = 0,
    PaperWidth paperWidth = PaperWidth.width58mm,
    ImageProcessingMode imageMode = ImageProcessingMode.adaptiveThreshold,
    int threshold = 128,
    double gamma = 1.4,
    int renderScale = 3,
  });

  /// Show the system print dialog (choose printer or Save as PDF).
  ///
  /// Uses Android PrintHelper or iOS UIPrintInteractionController. User picks
  /// printer or "Save as PDF". Cut behavior depends on the selected printer.
  ///
  /// **Parameters:**
  /// - [imageBytes] — Image bytes (PNG, JPEG, BMP) to print.
  /// - [copies] — Number of copies (default: 1).
  /// - [cutAfterEachCopy] — Request cut after each copy if printer supports it (default: false).
  ///
  /// **Returns:** `true` if the dialog was shown, `false` otherwise.
  ///
  /// **Throws:** [PrinterError] if image is invalid or print unavailable.
  Future<bool> printWithSystem(
    Uint8List imageBytes, {
    int copies = 1,
    bool cutAfterEachCopy = false,
  });

  /// Cancel the current printing operation if possible.
  ///
  /// **Returns:** `true` if something was cancelled (e.g. system print sheet on iOS), `false` otherwise.
  ///
  /// **Behavior:** On iOS, dismisses the system print sheet. On Android, the system
  /// dialog cannot be dismissed by app; direct ZCS print has no cancel API.
  Future<bool> cancelPrint();
}
