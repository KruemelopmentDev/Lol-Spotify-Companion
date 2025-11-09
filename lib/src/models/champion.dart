class Champion {
  final int id;
  final String name;
  final String imagePath;

  Champion({required this.id, required this.name, required this.imagePath});

  factory Champion.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown';
    final safeName = name.isEmpty ? 'Unknown' : name;

    return Champion(
      id: json['ID'] as int,
      name: safeName,
      imagePath: json['image'] as String? ?? '',
    );
  }
}
