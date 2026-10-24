/// Turns a Dart [StackTrace] into the frames the contract allows.
///
/// Release builds are not obfuscated, so frames arrive readable
/// (`package:everlore/...`). Only `package:` and `dart:` URIs are kept: a
/// `file:///` frame would carry a developer's home directory.
library;

class TelemetryFrame {
  const TelemetryFrame({
    required this.file,
    required this.symbol,
    required this.line,
  });

  final String file;
  final String symbol;
  final int line;

  Map<String, Object> toJson() => {'file': file, 'symbol': symbol, 'line': line};
}

const int maxFrames = 30;

// `#3      PlayCubit._onFrame (package:everlore/x.dart:412:7)`
final RegExp _frame = RegExp(r'^#\d+\s+(.+?)\s+\((.+?):(\d+)(?::\d+)?\)\s*$');

List<TelemetryFrame> parseFrames(StackTrace? stack, {int limit = maxFrames}) {
  if (stack == null) return const [];
  final frames = <TelemetryFrame>[];
  for (final raw in stack.toString().split('\n')) {
    final match = _frame.firstMatch(raw.trim());
    if (match == null) continue;
    final file = match[2]!;
    if (!(file.startsWith('package:') || file.startsWith('dart:'))) continue;
    if (file.length > 160) continue;
    var symbol = match[1]!;
    if (symbol.length > 120) symbol = symbol.substring(0, 120);
    frames.add(
      TelemetryFrame(
        file: file,
        symbol: symbol,
        line: int.tryParse(match[3]!) ?? 0,
      ),
    );
    if (frames.length >= limit) break;
  }
  return frames;
}
