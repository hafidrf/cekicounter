class StandingRow {
  const StandingRow({
    required this.playerName,
    required this.played,
    required this.points,
    required this.scoreDiff,
  });

  final String playerName;
  final int played;
  final int points;
  final int scoreDiff;

  StandingRow copyWith({
    String? playerName,
    int? played,
    int? points,
    int? scoreDiff,
  }) {
    return StandingRow(
      playerName: playerName ?? this.playerName,
      played: played ?? this.played,
      points: points ?? this.points,
      scoreDiff: scoreDiff ?? this.scoreDiff,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerName': playerName,
    'played': played,
    'points': points,
    'scoreDiff': scoreDiff,
  };

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      playerName: json['playerName'] as String,
      played: json['played'] as int,
      points: json['points'] as int,
      scoreDiff: json['scoreDiff'] as int,
    );
  }
}
