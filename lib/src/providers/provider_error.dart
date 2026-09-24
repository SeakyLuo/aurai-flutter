import '../domain/model_provider.dart';

bool isProviderQuotaError(String detail) =>
    RegExp(
      r'"code"\s*:\s*"(insufficient_user_quota|insufficient_quota|billing_hard_limit_reached)"',
    ).hasMatch(detail) ||
    detail.toLowerCase().contains('insufficient user quota') ||
    detail.contains('预扣费额度失败');

ModelProviderException providerResponseError(
  String detail, {
  int? statusCode,
}) => ModelProviderException(
  isProviderQuotaError(detail) || statusCode == 402
      ? '模型服务余额不足，请先充值'
      : switch (statusCode) {
          401 || 403 => '模型服务认证失败，请检查 API 密钥',
          429 => '模型服务当前繁忙或额度不足，请稍后重试',
          final int code when code >= 500 => '模型服务暂时不可用，请稍后重试',
          _ => '模型服务请求失败',
        },
  detail: detail,
  statusCode: statusCode,
);
