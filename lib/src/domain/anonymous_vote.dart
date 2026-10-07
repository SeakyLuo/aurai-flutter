/// Forwarded results must not expose the forwarding participant's own ballot.
Map<String, Object?> anonymousForwardView(Map<String, Object?> view) => {
  ...view,
  'submitted': false,
  'self': null,
  'components': [
    for (final component in view['components'] as List)
      {
        ...component as Map,
        if (component['type'] == 'distribution') 'selected': null,
      },
  ],
};
