import 'prn_str_format.dart';

/// Reusable format presets for common printing scenarios
class PrintFormats {
  /// Header format - large, centered, bold
  static PrnStrFormat get header => PrnStrFormat(
        textSize: 30,
        alignment: 'center',
        style: 'bold',
        font: 'sansSerif',
      );

  /// Normal text format - standard size, left aligned
  static PrnStrFormat get normal => PrnStrFormat(
        textSize: 24,
        alignment: 'left',
        style: 'normal',
        font: 'sansSerif',
      );

  /// Right-aligned format - useful for prices, totals
  static PrnStrFormat get rightAligned => PrnStrFormat(
        textSize: 24,
        alignment: 'right',
        style: 'normal',
        font: 'monospace',
      );

  /// Center-aligned format
  static PrnStrFormat get center => PrnStrFormat(
        textSize: 24,
        alignment: 'center',
        style: 'normal',
        font: 'sansSerif',
      );

  /// Bold format
  static PrnStrFormat get bold => PrnStrFormat(
        textSize: 24,
        alignment: 'left',
        style: 'bold',
        font: 'sansSerif',
      );

  /// Small text format
  static PrnStrFormat get small => PrnStrFormat(
        textSize: 20,
        alignment: 'left',
        style: 'normal',
        font: 'sansSerif',
      );
}
