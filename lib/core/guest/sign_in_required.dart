import 'package:flutter/foundation.dart';

/// The one place "this guest must sign in to go on" is announced.
///
/// Kept free of imports from the network and auth layers so [ApiClient] can
/// raise it without a cycle. Each raise bumps the counter, so a listener hears
/// a second refusal even though nothing else changed.
class SignInRequired {
  SignInRequired._();

  static final ValueNotifier<int> requests = ValueNotifier<int>(0);

  static void raise() => requests.value++;
}
