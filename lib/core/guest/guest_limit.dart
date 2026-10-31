/// How many turns a guest may play before an account is needed.
///
/// Mirrors `GUEST_TURN_LIMIT` in `everlore-server/src/services/guest-policy.ts`.
/// The server stays the real gate; the app only uses this to time the
/// "keep your story" prompt for right after the last allowed reply instead of
/// after a message the player typed and the server threw away.
const int kGuestTurnLimit = 5;

/// Whether the "keep your story" sheet should be raised now.
///
/// Only once the last allowed reply has finished streaming, and only once per
/// stretch: [alreadyPrompted] is the caller's memory of having done it.
bool shouldPromptKeepStory({
  required int used,
  required int limit,
  required bool streaming,
  bool alreadyPrompted = false,
}) => used >= limit && !streaming && !alreadyPrompted;

/// Whether a guide arc may open by itself.
///
/// A spent guest is about to be shown the sign-in sheet, and a card over the
/// box the player is typing in is worse than no card, so both hold the guide
/// back. Signed-in players only wait for the box.
bool mayAutoStartGuide({
  required bool isGuest,
  required int used,
  required int limit,
  required bool inputFocused,
  required bool draftEmpty,
  bool keepStoryShowing = false,
}) {
  if (inputFocused || !draftEmpty) return false;
  if (!isGuest) return true;
  return used < limit && !keepStoryShowing;
}

/// The line to put back in the composer after a refused send: the bubble the
/// player had sent, else a line held behind it. Null when there is nothing.
String? draftAfterRefusal({String? droppedInput, String? queued}) =>
    (droppedInput != null && droppedInput.trim().isNotEmpty)
    ? droppedInput
    : queued;
