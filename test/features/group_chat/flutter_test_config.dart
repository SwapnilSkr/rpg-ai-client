import 'dart:async';

/// These tests draw nothing, so they do not load the bundled typefaces the
/// app-wide config loads. That also lets them run where the asset bundle
/// cannot be built.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
