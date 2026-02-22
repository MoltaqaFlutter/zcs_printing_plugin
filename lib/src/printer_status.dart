/// Printer status enum for type-safe status checking
enum PrinterStatus {
  /// Printer is ready and operational
  ok,

  /// Printer is out of paper
  paperOut,

  /// General printer error occurred
  error,

  /// Printer is busy processing
  busy,

  /// Printer is offline or not connected
  offline,
}

/// Extension to convert PrinterStatus to/from string for platform channel
extension PrinterStatusExtension on PrinterStatus {
  String get name {
    switch (this) {
      case PrinterStatus.ok:
        return 'ok';
      case PrinterStatus.paperOut:
        return 'paperOut';
      case PrinterStatus.error:
        return 'error';
      case PrinterStatus.busy:
        return 'busy';
      case PrinterStatus.offline:
        return 'offline';
    }
  }

  static PrinterStatus fromString(String value) {
    switch (value) {
      case 'ok':
        return PrinterStatus.ok;
      case 'paperOut':
        return PrinterStatus.paperOut;
      case 'error':
        return PrinterStatus.error;
      case 'busy':
        return PrinterStatus.busy;
      case 'offline':
        return PrinterStatus.offline;
      default:
        return PrinterStatus.error;
    }
  }
}
