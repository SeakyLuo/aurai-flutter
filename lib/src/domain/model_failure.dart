import 'dart:convert';

enum ModelFailure {
  connection,
  timeout,
  rateLimit,
  authentication,
  permission,
  quota,
  contentFilter,
  outputLimit,
  unavailable,
  invalidRequest,
  unknown;

  bool get canContinue =>
      this == connection || this == timeout || this == outputLimit;

  String get title => switch (this) {
    connection => '模型连接中断',
    timeout => '模型响应超时',
    rateLimit => '请求过于频繁',
    authentication => '模型服务认证失败',
    permission => '模型服务拒绝访问',
    quota => '模型服务额度不足',
    contentFilter => '回复被内容限制中止',
    outputLimit => '回复达到输出上限',
    unavailable => '模型服务暂不可用',
    invalidRequest => '模型请求未被接受',
    unknown => '回复出错',
  };
}

/// Reads structured error fields from the existing persisted error detail.
/// Only structured codes and the gateway's exact stream-failure message are
/// classified; arbitrary prose and model refusals do not imply error codes.
ModelFailure classifyModelFailure(String detail, {int? statusCode}) {
  // Persisted message failures may contain only our already-classified title.
  final heading = detail.split('\n').first;
  for (final failure in ModelFailure.values) {
    if (heading == failure.title) return failure;
  }
  final codes = <String>{};
  final messages = <String>{};
  void read(Map value) {
    if (value['message'] case final String message) messages.add(message);
    for (final key in ['code', 'type', 'reason', 'finish_reason', 'status']) {
      if (value[key] case final String code) codes.add(code.toLowerCase());
    }
    for (final key in [
      'error',
      'response',
      'incomplete_details',
      'innererror',
    ]) {
      if (value[key] case final Map nested) read(nested);
    }
  }

  final start = detail.indexOf('{');
  final end = detail.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final decoded = jsonDecode(detail.substring(start, end + 1));
      if (decoded is Map) read(decoded);
    } on FormatException {
      // Gateways may return HTML/plain text; retain it as an unknown error.
    }
  }
  bool has(Set<String> values) => codes.any(values.contains);
  if (has({'upstream_stream_error'}) ||
      (has({'api_error'}) &&
          messages.contains('Upstream stream failed. Please retry.'))) {
    return ModelFailure.connection;
  }
  if (has({
    'content_filter',
    'content_policy_violation',
    'responsibleaipolicyviolation',
  }))
    return ModelFailure.contentFilter;
  if (has({
    'insufficient_quota',
    'insufficient_user_quota',
    'billing_hard_limit_reached',
  }))
    return ModelFailure.quota;
  if (has({'invalid_api_key', 'authentication_error', 'unauthenticated'}))
    return ModelFailure.authentication;
  if (has({'permission_error', 'permission_denied'}))
    return ModelFailure.permission;
  if (has({'rate_limit_exceeded', 'rate_limit_error', 'resource_exhausted'}))
    return ModelFailure.rateLimit;
  if (has({'max_output_tokens', 'length'})) return ModelFailure.outputLimit;
  if (has({'timeout', 'request_timeout', 'deadline_exceeded'}))
    return ModelFailure.timeout;
  if (has({'overloaded_error', 'server_error', 'unavailable'}))
    return ModelFailure.unavailable;
  final http =
      statusCode ??
      int.tryParse(
        RegExp(r'HTTP (\d{3})[）)]').firstMatch(detail)?.group(1) ?? '',
      );
  if (http != null) {
    return switch (http) {
      401 => ModelFailure.authentication,
      403 => ModelFailure.permission,
      402 => ModelFailure.quota,
      408 || 504 => ModelFailure.timeout,
      429 => ModelFailure.rateLimit,
      >= 500 => ModelFailure.unavailable,
      400 || 404 || 422 => ModelFailure.invalidRequest,
      _ => ModelFailure.unknown,
    };
  }
  if (detail.startsWith('ModelConnectionInterrupted:'))
    return ModelFailure.connection;
  if (detail.startsWith('TimeoutException')) return ModelFailure.timeout;
  return ModelFailure.unknown;
}
