const uiToolActions = {
  'clickUiElement': 'click',
  'inputUiText': 'inputText',
  'scrollUiForward': 'scrollForward',
  'scrollUiBackward': 'scrollBackward',
  'goBack': 'back',
  'goHome': 'home',
};

bool isScreenTool(String name) =>
    uiToolActions.containsKey(name) ||
    const {'act', 'tapScreen', 'captureScreen'}.contains(name);

Map<String, Object?> uiActionArguments(
  String name,
  Map<String, Object?> arguments,
) => {
  'action': uiToolActions[name]!,
  'observationId': arguments['observationId'],
  'nodeRef': arguments['nodeRef'],
  'text': arguments['text'],
};
