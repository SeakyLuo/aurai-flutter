class MusicGenerationModels {
  static const values = [
    (id: 'chirp-hawk', name: 'Suno V6'),
    (id: 'chirp-hawk-wild', name: 'Suno V6-wild'),
    (id: 'chirp-goose', name: 'Suno V6-mini'),
  ];

  static String nameOf(String id) =>
      values.firstWhere((model) => model.id == id).name;
}
