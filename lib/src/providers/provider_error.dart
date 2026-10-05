import '../domain/model_provider.dart';
import '../domain/model_failure.dart';

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
      : classifyModelFailure(detail, statusCode: statusCode).title,
  detail: detail,
  statusCode: statusCode,
);
