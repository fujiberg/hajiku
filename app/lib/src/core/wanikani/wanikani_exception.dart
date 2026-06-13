/// Base type for errors raised by [WaniKaniApiClient].
sealed class WaniKaniException implements Exception {
  const WaniKaniException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when no API token is configured, or the configured token is
/// rejected by the WaniKani API (HTTP 401).
class WaniKaniAuthException extends WaniKaniException {
  const WaniKaniAuthException(super.message);
}

/// Thrown when the WaniKani API returns an unexpected non-success status.
class WaniKaniApiException extends WaniKaniException {
  const WaniKaniApiException(this.statusCode, super.message);

  final int statusCode;
}
