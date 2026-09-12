import 'package:flutter/services.dart';

import '../domain/model_provider.dart';
import '../domain/tool_models.dart';
import '../providers/model_top_up.dart';

class OpenModelTopUpTool implements AgentTool, RuntimeCapabilityAgentTool {
  OpenModelTopUpTool(this.settings);
  final ModelSettings settings;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'openModelTopUp',
    description:
        'Open the official recharge page for a saved model provider in the phone browser. Currently supports official DeepSeek only. This only opens a page: it does not select an amount, create an order, authenticate, or pay. Use only for a user-requested recharge. For assisted preparation, first clarify the exact amount and currency and query getModelBalance. The browser login may belong to a different account from the API key: ask the user to confirm they match before selecting amounts. Then observe using screen tools and prepare only the requested amount. The user must complete login, payment and any codes themselves. Do not click pay/submit-order/confirm-purchase or use code/shell to perform payment. Cancellation ends the recharge flow; never retry a payment. After the user reports payment, query the new balance and report the snapshot without asserting a specific order settled. Use blocking askUser for missing amount/currency, never assume defaults. Have the user return to Aurai and report paid/cancelled with askUser(waitForResponse=true). After paid feedback query balance once; on query failure never recommend paying again. When model funds are exhausted, the manual recharge entry remains under Model settings > DeepSeek > Account balance and recharge.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'provider': {
          'type': 'string',
          'enum': ['current', 'deepSeek', 'openAi'],
        },
      },
      'required': ['provider'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'model.topUp',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final service = switch (call.arguments['provider'] as String) {
      'current' => settings.activeService,
      'deepSeek' => ModelService.deepSeek,
      'openAi' => ModelService.openAi,
      _ => throw const FormatException('Unknown model provider'),
    };
    try {
      await ModelTopUp.open(settings.profile(service));
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          'provider': service.label,
          'pageOpened': true,
          'url': ModelTopUp.deepSeekUrl,
          'amountSelected': false,
          'orderCreated': false,
          'paymentPerformed': false,
          'accountMatchVerified': false,
          'next':
              'Observe the browser. Have the user log in and confirm the account matches their saved API key before choosing their requested amount. Stop before any order/payment submission. Let the user pay and return to Aurai; use askUser with waitForResponse=true to receive paid/cancelled feedback, then query balance only after paid feedback. Never treat an opened page as payment success.',
        },
      );
    } on ModelProviderException catch (error) {
      return _error(call, error.message);
    } on PlatformException {
      return _error(call, '无法打开官方充值页，请在模型配置页手动打开');
    }
  }

  ToolResult _error(ToolCall call, String message) => ToolResult(
    callId: call.id,
    toolName: call.name,
    status: ToolResultStatus.error,
    output: {'error': message},
  );

  @override
  Future<void> cancel() async {}
}
