import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads the bundled Cinzel and EB Garamond before any test runs. Left to load
/// on first use, a font lands mid-frame and a laid-out paragraph changes size
/// before it paints; loaded up front, every test measures the real typefaces.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final weight in const [FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.cinzel(fontWeight: weight);
  }
  GoogleFonts.ebGaramond();
  GoogleFonts.ebGaramond(fontStyle: FontStyle.italic);
  await GoogleFonts.pendingFonts();
  await testMain();
}
