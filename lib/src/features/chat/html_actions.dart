part of 'chat_controller.dart';

extension HtmlActions on ChatController {
  HtmlStore get htmlStore => HtmlStore(_store.database);
}
