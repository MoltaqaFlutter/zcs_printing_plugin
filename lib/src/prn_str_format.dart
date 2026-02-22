/// Print string format configuration
/// Used to format text when printing
class PrnStrFormat {
  /// Font size (e.g. 24, 25, 30)
  final int textSize;

  /// Text alignment: "left", "center", or "right"
  final String alignment;

  /// Text style: "normal" or "bold"
  final String style;

  /// Font family: "sansSerif", "monospace", or "custom"
  final String font;

  /// Path to custom font file (only used when font="custom")
  /// Can be asset path (e.g. "fonts/CustomFont.ttf") or file system path
  final String? path;

  PrnStrFormat({
    required this.textSize,
    this.alignment = 'left',
    this.style = 'normal',
    this.font = 'sansSerif',
    this.path,
  });

  /// Convert to Map for platform channel
  Map<String, dynamic> toMap() {
    return {
      'textSize': textSize,
      'alignment': alignment,
      'style': style,
      'font': font,
      if (path != null) 'path': path,
    };
  }

  /// Create from Map (from platform channel)
  factory PrnStrFormat.fromMap(Map<dynamic, dynamic> map) {
    return PrnStrFormat(
      textSize: map['textSize'] as int,
      alignment: map['alignment'] as String? ?? 'left',
      style: map['style'] as String? ?? 'normal',
      font: map['font'] as String? ?? 'sansSerif',
      path: map['path'] as String?,
    );
  }

  /// Copy with modified values
  PrnStrFormat copyWith({
    int? textSize,
    String? alignment,
    String? style,
    String? font,
    String? path,
  }) {
    return PrnStrFormat(
      textSize: textSize ?? this.textSize,
      alignment: alignment ?? this.alignment,
      style: style ?? this.style,
      font: font ?? this.font,
      path: path ?? this.path,
    );
  }
}
