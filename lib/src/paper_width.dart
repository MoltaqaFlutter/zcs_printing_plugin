/// Standard thermal receipt paper widths for PDF and image printing.
///
/// Use this enum so PDFs are scaled to fit your POS paper width without
/// dealing with pixel values. The default is [PaperWidth.width58mm].
///
/// Example:
/// ```dart
/// await printer.printPdf(pdfBytes, paperWidth: PaperWidth.width80mm);
/// ```
enum PaperWidth {
  /// 55 mm paper width (e.g. some narrow receipt rolls).
  /// Pixel width: 364.
  width55mm(364),

  /// 58 mm paper width — most common thermal receipt size (default).
  /// Pixel width: 384.
  width58mm(384),

  /// 80 mm paper width — common for wider POS receipts and invoices.
  /// Pixel width: 576.
  width80mm(576);

  /// Creates a [PaperWidth] with the given pixel width used when scaling PDFs.
  const PaperWidth(this.widthPx);

  /// Paper width in printer pixels. Used to scale PDF pages to fit the paper.
  final int widthPx;
}
