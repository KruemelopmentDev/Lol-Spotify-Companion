class ChampionSong {
  final int championId;
  final String championName;
  final String spotifyId;
  final String songName;
  final String artistName;
  final String imagePath;

  ChampionSong({
    required this.championId,
    required this.championName,
    required this.spotifyId,
    required this.songName,
    required this.artistName,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'championId': championId,
    'championName': championName,
    'spotifyId': spotifyId,
    'songName': songName,
    'artistName': artistName,
    'imagePath': imagePath,
  };

  factory ChampionSong.fromJson(Map<String, dynamic> json) => ChampionSong(
    championId: json['championId'],
    championName: json['championName'],
    spotifyId: json['spotifyId'],
    songName: json['songName'],
    artistName: json['artistName'],
    imagePath: json['imagePath'],
  );
}
