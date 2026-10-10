/// Keep every recorded match fact once, without repeating it in each player,
/// the public log, the host view, and the viewer's private timeline.
Map<String, Object?> werewolfPostgameContext(Map<String, Object?> state) {
  final miniapp = state['_miniapp'] as Map;
  final own = miniapp['own'] as Map;
  return {
    for (final key in [
      'phase',
      'hostId',
      'day',
      'winner',
      'sheriff',
      'speaker',
      'loverIds',
      'rules',
      'postgame',
    ])
      key: state[key],
    'players': [
      for (final player in state['players'] as List)
        {
          for (final key in ['id', 'name', 'seat', 'alive', 'role'])
            key: (player as Map)[key],
        },
    ],
    'roles': [
      for (final role in state['roles'] as List)
        {
          for (final key in ['name', 'type', 'team', 'category', 'skills'])
            key: (role as Map)[key],
        },
    ],
    'matchFacts': [
      for (final row in state['timeline'] as List)
        if ((row as Map)['type'] != 'postgameSpeech')
          {
            for (final key in [
              'order',
              'day',
              'period',
              'playerId',
              'type',
              'text',
            ])
              key: row[key],
          },
    ],
    '_miniapp': {
      'viewerId': miniapp['viewerId'],
      'ownerId': miniapp['ownerId'],
      'own': {
        for (final key in ['isHost', 'role', 'seq', 'protocol', 'eventGuards'])
          if (own.containsKey(key)) key: own[key],
      },
      'cards': miniapp['cards'],
    },
  };
}
