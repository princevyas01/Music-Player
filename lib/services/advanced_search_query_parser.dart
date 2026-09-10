/// A deliberately narrow parser for SpinWave's local advanced-search syntax.
///
/// It accepts only documented operators. If a query contains an unknown or
/// malformed operator, [isValid] is false and callers should send the complete
/// query to the existing ranked search service unchanged.
class AdvancedSearchQuery {
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final String? playlist;
  final String? title;
  final String? filename;
  final int? durationLessThanSeconds;
  final int? durationGreaterThanSeconds;
  final DateTime? before;
  final DateTime? after;
  final String text;
  final bool isValid;
  final bool hasOperators;

  const AdvancedSearchQuery({
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.playlist,
    this.title,
    this.filename,
    this.durationLessThanSeconds,
    this.durationGreaterThanSeconds,
    this.before,
    this.after,
    this.text = '',
    this.isValid = true,
    this.hasOperators = false,
  });
}

class AdvancedSearchQueryParser {
  static const _supportedFields = {
    'artist',
    'album',
    'genre',
    'year',
    'duration',
    'playlist',
    'title',
    'filename',
    'before',
    'after',
  };

  const AdvancedSearchQueryParser();

  AdvancedSearchQuery parse(String query) {
    final tokens = _tokenize(query.trim());
    if (tokens == null) {
      return const AdvancedSearchQuery(isValid: false);
    }

    String? artist;
    String? album;
    String? genre;
    int? year;
    String? playlist;
    String? title;
    String? filename;
    int? durationLessThanSeconds;
    int? durationGreaterThanSeconds;
    DateTime? before;
    DateTime? after;
    final textTokens = <String>[];
    var hasOperators = false;

    for (final token in tokens) {
      final delimiter = token.indexOf(':');
      if (delimiter <= 0) {
        textTokens.add(token);
        continue;
      }

      final field = token.substring(0, delimiter).toLowerCase();
      final value = token.substring(delimiter + 1).trim();
      // A colon in ordinary text needs to remain an ordinary search. An
      // unsupported field, however, is probably a malformed advanced query.
      if (!_supportedFields.contains(field)) {
        return const AdvancedSearchQuery(isValid: false);
      }
      if (value.isEmpty) return const AdvancedSearchQuery(isValid: false);
      hasOperators = true;

      switch (field) {
        case 'artist':
          artist = value;
          break;
        case 'album':
          album = value;
          break;
        case 'genre':
          genre = value;
          break;
        case 'playlist':
          playlist = value;
          break;
        case 'title':
          title = value;
          break;
        case 'filename':
          filename = value;
          break;
        case 'year':
          year = int.tryParse(value);
          if (year == null || year! < 0 || year! > 9999) {
            return const AdvancedSearchQuery(isValid: false);
          }
          break;
        case 'duration':
          if (value.length < 2 || (value[0] != '<' && value[0] != '>')) {
            return const AdvancedSearchQuery(isValid: false);
          }
          final seconds = int.tryParse(value.substring(1));
          if (seconds == null || seconds < 0) {
            return const AdvancedSearchQuery(isValid: false);
          }
          if (value[0] == '<') {
            durationLessThanSeconds = seconds;
          } else {
            durationGreaterThanSeconds = seconds;
          }
          break;
        case 'before':
          before = DateTime.tryParse(value);
          if (before == null) return const AdvancedSearchQuery(isValid: false);
          break;
        case 'after':
          after = DateTime.tryParse(value);
          if (after == null) return const AdvancedSearchQuery(isValid: false);
          break;
      }
    }

    return AdvancedSearchQuery(
      artist: artist,
      album: album,
      genre: genre,
      year: year,
      playlist: playlist,
      title: title,
      filename: filename,
      durationLessThanSeconds: durationLessThanSeconds,
      durationGreaterThanSeconds: durationGreaterThanSeconds,
      before: before,
      after: after,
      text: textTokens.join(' '),
      hasOperators: hasOperators,
    );
  }

  List<String>? _tokenize(String source) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (char == '"') {
        quoted = !quoted;
        continue;
      }
      if (char.trim().isEmpty && !quoted) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (quoted) return null;
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }
}
