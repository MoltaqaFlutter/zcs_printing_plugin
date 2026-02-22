/// Custom error class for printer operations
/// Provides clear, user-facing error messages
class PrinterError implements Exception {
  /// Error code for programmatic handling
  final PrinterErrorCode code;

  /// User-friendly error message
  final String message;

  /// Optional technical details for debugging (not shown to users)
  final String? details;

  PrinterError({
    required this.code,
    required this.message,
    this.details,
  });

  /// Platform unsupported error (iOS)
  factory PrinterError.platformUnsupported() {
    return PrinterError(
      code: PrinterErrorCode.platformUnsupported,
      message: 'Printer is not supported on this device. This feature is available only on Android.',
    );
  }

  /// Printer not available error
  factory PrinterError.printerNotAvailable([String? details]) {
    return PrinterError(
      code: PrinterErrorCode.printerNotAvailable,
      message: 'Printer is not available. Please check that the device is connected and powered on.',
      details: details,
    );
  }

  /// Paper out error
  factory PrinterError.paperOut() {
    return PrinterError(
      code: PrinterErrorCode.paperOut,
      message: 'Printer is out of paper. Please add paper and try again.',
    );
  }

  /// Invalid PDF error
  factory PrinterError.invalidPdf([String? details]) {
    return PrinterError(
      code: PrinterErrorCode.invalidPdf,
      message: 'The PDF could not be read. It may be damaged or in an unsupported format.',
      details: details,
    );
  }

  /// Invalid image error
  factory PrinterError.invalidImage([String? details]) {
    return PrinterError(
      code: PrinterErrorCode.invalidImage,
      message: 'The image could not be printed. Please check the file format and try again.',
      details: details,
    );
  }

  /// Invalid argument error
  factory PrinterError.invalidArgument(String message) {
    return PrinterError(
      code: PrinterErrorCode.invalidArgument,
      message: 'Invalid input provided. $message',
    );
  }

  /// Buffer empty error
  factory PrinterError.bufferEmpty() {
    return PrinterError(
      code: PrinterErrorCode.bufferEmpty,
      message: 'Nothing to print. Please add content using appendText or other append methods first.',
    );
  }

  /// Unknown error
  factory PrinterError.unknown([String? details]) {
    return PrinterError(
      code: PrinterErrorCode.unknown,
      message: 'An unexpected error occurred. Please try again.',
      details: details,
    );
  }

  @override
  String toString() => message;
}

/// Error codes for printer operations
enum PrinterErrorCode {
  platformUnsupported,
  printerNotAvailable,
  paperOut,
  invalidPdf,
  invalidImage,
  invalidArgument,
  bufferEmpty,
  cutterNotSupported,
  unknown,
}

/// Extension to convert error code to/from string
extension PrinterErrorCodeExtension on PrinterErrorCode {
  String get name {
    switch (this) {
      case PrinterErrorCode.platformUnsupported:
        return 'platformUnsupported';
      case PrinterErrorCode.printerNotAvailable:
        return 'printerNotAvailable';
      case PrinterErrorCode.paperOut:
        return 'paperOut';
      case PrinterErrorCode.invalidPdf:
        return 'invalidPdf';
      case PrinterErrorCode.invalidImage:
        return 'invalidImage';
      case PrinterErrorCode.invalidArgument:
        return 'invalidArgument';
      case PrinterErrorCode.bufferEmpty:
        return 'bufferEmpty';
      case PrinterErrorCode.cutterNotSupported:
        return 'cutterNotSupported';
      case PrinterErrorCode.unknown:
        return 'unknown';
    }
  }

  static PrinterErrorCode fromString(String value) {
    switch (value) {
      case 'platformUnsupported':
        return PrinterErrorCode.platformUnsupported;
      case 'printerNotAvailable':
        return PrinterErrorCode.printerNotAvailable;
      case 'paperOut':
        return PrinterErrorCode.paperOut;
      case 'invalidPdf':
        return PrinterErrorCode.invalidPdf;
      case 'invalidImage':
        return PrinterErrorCode.invalidImage;
      case 'invalidArgument':
        return PrinterErrorCode.invalidArgument;
      case 'bufferEmpty':
        return PrinterErrorCode.bufferEmpty;
      case 'cutterNotSupported':
        return PrinterErrorCode.cutterNotSupported;
      case 'unknown':
        return PrinterErrorCode.unknown;
      default:
        return PrinterErrorCode.unknown;
    }
  }
}
