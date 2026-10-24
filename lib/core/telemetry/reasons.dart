/// Maps a failure to the short labels the contract allows. Decided from the
/// error's type and status, never from its text.
library;

import '../errors/user_message.dart';
import '../network/api_client.dart';

/// `cancelled` | `network` | `rejected` | `unknown`
String signInFailureReason(Object error) {
  if (error is ApiException) {
    return error.statusCode >= 400 && error.statusCode < 500
        ? 'rejected'
        : 'unknown';
  }
  if (isConnectivityError(error)) return 'network';
  return 'unknown';
}

/// `network` | `ink` | `server` | `rest` for a turn's error frame, from the
/// frame's code (the server's own classification), never from its text.
/// Null for a frame that is not a failure the player is shown.
String? turnFailureReason(Map<String, dynamic> frame) {
  switch (frame['code']?.toString()) {
    case 'GENERATION_IN_PROGRESS':
      return null;
    case 'STORY_RESTING':
      return 'rest';
    case 'INSUFFICIENT_INK':
      return 'ink';
    default:
      return 'server';
  }
}
