import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';

/// Turns any thrown object into something a player can read.
///
/// This exists because the app used to render `e.toString()` straight into the
/// UI. That is fine for an [ApiException] the server wrote for a player, and
/// wrong for everything else: a lost DNS lookup surfaced as
/// "ClientException with SocketException: Failed host lookup:
/// 'api.everloreapp.com' ... uri=https://api.everloreapp.com/auth/otp/send",
/// which tells the player nothing, and tells anyone reading over their
/// shoulder our hostnames and routes.
///
/// The rule is the same one the play socket already follows: show the server's
/// words only where the server wrote them for a player, and otherwise say
/// something true and useful.

/// Statuses whose `error` text the server authors for players.
///
/// 5xx is deliberately excluded. Most of it is already flattened to "Internal
/// server error", but not all: `imageService.generatePreview` raises
/// `HttpError(502, 'Image generation failed: <provider message>')`, so a 5xx
/// body can still carry a vendor's words. Anything at or above 500 gets the
/// fallback.
bool _isAuthoredStatus(int status) => status >= 400 && status < 500;

/// True when [error] means "we could not reach the server", as opposed to "the
/// server said no".
bool isConnectivityError(Object error) {
  return error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException ||
      error is TimeoutException;
}

/// What to show a player when the network is the problem. Deliberately names
/// no host, no route, and no OS error code.
const String connectivityMessage =
    'Could not reach Everlore. Check your connection and try again.';

/// The player-facing text for [error], or [fallback] when the failure has
/// nothing a player could act on.
///
/// [fallback] should say what did not happen, in the language of the screen
/// ("Could not send the code.") rather than the language of the transport.
String userFacingError(Object? error, {required String fallback}) {
  if (error == null) return fallback;

  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isEmpty || !_isAuthoredStatus(error.statusCode)) {
      return fallback;
    }
    // The server's own default when it had nothing better to say. Showing it
    // is no better than showing the fallback, and the fallback at least names
    // the action that failed.
    if (message.toLowerCase() == 'unknown error') return fallback;
    return message;
  }

  if (isConnectivityError(error)) return connectivityMessage;

  // Everything else — a FormatException from a body that was not JSON, a null
  // dereference, a platform channel failure — is a bug or an outage. Its text
  // is for the log, not the player.
  if (kDebugMode) {
    debugPrint('userFacingError: unhandled ${error.runtimeType}: $error');
  }
  return fallback;
}
