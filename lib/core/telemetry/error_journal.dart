/// A plain file that an uncaught error is appended to *synchronously*.
///
/// The queue lives in sqflite, whose writes are asynchronous: a crash that
/// kills the process between "error caught" and "row written" would lose the
/// one report we most want. A synchronous file append has no such gap. The
/// next launch folds the journal into the queue (ids make that idempotent) and
/// empties it.
library;

import 'dart:convert';
import 'dart:io';

class ErrorJournal {
  ErrorJournal(this.path);

  final String path;

  /// Appends one JSON line. Never throws: a failing disk must not turn an
  /// error report into a second error.
  void append(Map<String, Object?> line) {
    try {
      File(path).writeAsStringSync(
        '${jsonEncode(line)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  List<Map<String, Object?>> read() {
    try {
      final file = File(path);
      if (!file.existsSync()) return const [];
      final out = <Map<String, Object?>>[];
      for (final raw in file.readAsLinesSync()) {
        if (raw.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, Object?>) out.add(decoded);
        } catch (_) {
          // A line cut off by the crash itself; the rest are still good.
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  void clear() {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
