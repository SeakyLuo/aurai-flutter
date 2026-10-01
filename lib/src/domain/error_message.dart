import 'package:flutter/services.dart';
import 'model_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Preserve the cause without exposing a stack trace in user-facing messages.
String errorMessage(Object error) => switch (error) {
  ModelProviderException() => error.displayMessage,
  PlatformException() => [
    if (error.message != null) error.message!,
    '错误码：${error.code}',
    if (error.details != null) '${error.details}',
  ].join('\n'),
  StateError() => '${error.message}',
  DatabaseException() when error.toString().contains('你已被禁言，暂时不能在这个群发送消息') =>
    '你已被禁言，暂时不能在这个群发送消息',
  ArgumentError() => error.toString(),
  _ => error.toString(),
};
