class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestampMs': timestamp.inMilliseconds,
      'text': text,
    };
  }

  factory LyricLine.fromMap(Map<dynamic, dynamic> map) {
    return LyricLine(
      timestamp: Duration(milliseconds: (map['timestampMs'] as num?)?.toInt() ?? 0),
      text: map['text'] as String? ?? '',
    );
  }
}

class ParsedLyrics {
  final String trackId;
  final List<LyricLine> lines;
  final bool isSynced;
  final String? plainText;

  const ParsedLyrics({
    required this.trackId,
    required this.lines,
    required this.isSynced,
    this.plainText,
  });

  bool get isEmpty => lines.isEmpty && (plainText == null || plainText!.trim().isEmpty);

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'lines': lines.map((l) => l.toMap()).toList(),
      'isSynced': isSynced,
      'plainText': plainText,
    };
  }

  factory ParsedLyrics.fromMap(Map<dynamic, dynamic> map) {
    return ParsedLyrics(
      trackId: map['trackId'] as String,
      lines: (map['lines'] as List? ?? [])
          .map((item) => LyricLine.fromMap(item as Map))
          .toList(),
      isSynced: map['isSynced'] as bool? ?? false,
      plainText: map['plainText'] as String?,
    );
  }
}
