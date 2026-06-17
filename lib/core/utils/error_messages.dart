import 'dart:async';
import 'dart:io';

/// Maps low-level exceptions to short, user-facing messages.
///
/// Network failures (no internet, DNS failure, timeouts) are by far the most
/// common real-world error, so they get a clear, actionable message instead of
/// a raw stack-tracey string.
String friendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (isOffline(error)) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }
  return fallback;
}

/// Whether [error] looks like a connectivity / host-lookup failure.
bool isOffline(Object error) {
  if (error is SocketException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection closed') ||
      text.contains('Connection refused');
}
