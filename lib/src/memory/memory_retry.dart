import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/model_provider.dart';
import '../domain/model_failure.dart';
import '../providers/provider_error.dart';

String? memoryFailureResponseId(Object error) {
  if (error is! ModelProviderException || error.detail == null) return null;
  try {
    final data = jsonDecode(error.detail!);
    if (data is Map && data['response'] is Map) {
      return data['response']['id'] as String?;
    }
  } on FormatException {
    // Plain-text provider errors have no structured response identifier.
  }
  return null;
}

Duration? memoryRetryDelay(Object error, int retries) {
  if (retries >= 3) return null;
  var transient =
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is ModelConnectionInterrupted;
  if (error is ModelProviderException) {
    if (isProviderQuotaError(error.detail ?? error.message)) return null;
    final failure = classifyModelFailure(
      error.detail ?? error.message,
      statusCode: error.statusCode,
    );
    if (failure == ModelFailure.contentFilter) return null;
    transient =
        transient ||
        failure == ModelFailure.connection ||
        failure == ModelFailure.timeout ||
        failure == ModelFailure.rateLimit ||
        failure == ModelFailure.unavailable;
    final status = error.statusCode;
    if (status != null) {
      transient = status == 408 || status == 429 || status >= 500;
    } else if (error.detail != null &&
        error.detail!.trimLeft().startsWith('{')) {
      // Provider details are not guaranteed to be JSON (network/proxy errors can be plain text).
      Object? decoded;
      try {
        decoded = jsonDecode(error.detail!);
      } on FormatException {
        decoded = null;
      }
      if (decoded is Map) {
        final response = decoded['response'];
        if (decoded['type'] == 'response.failed' && response is Map) {
          final failure = response['error'];
          transient =
              transient ||
              failure == null ||
              (failure is Map &&
                  [
                    'server_error',
                    'rate_limit_exceeded',
                  ].contains(failure['code']));
        }
      }
    }
  }
  if (!transient) return null;
  var delay = Duration(seconds: [10, 30, 120][retries]);
  if (error is ModelProviderException && error.retryAfter != null) {
    final seconds = int.tryParse(error.retryAfter!);
    Duration? requested;
    if (seconds != null) {
      requested = Duration(seconds: seconds);
    } else {
      try {
        requested = HttpDate.parse(
          error.retryAfter!,
        ).difference(DateTime.now());
      } on FormatException {
        /* A malformed server header cannot set a retry deadline. */
      }
    }
    if (requested != null && requested > delay) delay = requested;
  }
  return delay;
}
