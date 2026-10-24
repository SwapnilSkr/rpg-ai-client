/// Pure text and path reducers shared by every error report.
///
/// An exception message can carry a player's words: a parse error quoting a
/// reply, a server error echoing input. Anything that leaves the device is
/// reduced to its *shape* first (`analytics.md` §4.3). The server runs the same
/// rules again, so a build that forgot this still would not store the words.
library;

const int maxMessageLength = 300;

final RegExp _quoted = RegExp(r"""'[^']*'|"[^"]*"|`[^`]*`""");
final RegExp _email = RegExp(r'[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+');
final RegExp _urlQuery = RegExp(r'(https?://[^\s?#]+)\?\S*');
final RegExp _hexId = RegExp(r'\b[0-9a-fA-F]{24}\b');
final RegExp _longDigits = RegExp(r'\d{6,}');
final RegExp _spaces = RegExp(r'\s+');

String scrubMessage(String message) {
  var out = message.replaceAll(_quoted, "'…'");
  out = out.replaceAll(_email, '<email>');
  out = out.replaceAllMapped(_urlQuery, (m) => '${m[1]}?…');
  out = out.replaceAll(_hexId, '<id>');
  out = out.replaceAll(_longDigits, '<n>');
  out = out.replaceAll(_spaces, ' ').trim();
  if (out.length > maxMessageLength) {
    out = out.substring(0, maxMessageLength);
  }
  return out;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _hex24 = RegExp(r'^[0-9a-fA-F]{24}$');
final RegExp _digits = RegExp(r'^\d+$');
final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{16,}$');
final RegExp _hasDigit = RegExp(r'\d');

/// `/instances/66f…/choices?x=1` → `/instances/:id/choices`.
///
/// Segments that look like identifiers become `:id`: 24-hex, UUIDs, plain
/// numbers, and long opaque tokens that contain a digit. Decided by shape, not
/// by a list of known routes, so a new route needs no change here.
String routeTemplate(String path) {
  final bare = path.split('?').first.split('#').first;
  final segments = bare.split('/').map((segment) {
    if (segment.isEmpty) return segment;
    if (_hex24.hasMatch(segment) ||
        _uuid.hasMatch(segment) ||
        _digits.hasMatch(segment) ||
        (_token.hasMatch(segment) && _hasDigit.hasMatch(segment))) {
      return ':id';
    }
    return segment;
  });
  var out = segments.join('/');
  if (!out.startsWith('/')) out = '/$out';
  return out.length > 120 ? out.substring(0, 120) : out;
}
