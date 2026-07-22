import 'dart:convert';

enum WinnerMode { lowestScore, highestScore }

/// Preset nama pemain di layar setup (punya ID stabil untuk dropdown / hapus).
class SavedPlayerPreset {
  const SavedPlayerPreset({required this.id, required this.name});

  final String id;
  final String name;

  /// Label pendek untuk UI (bukan ID teknis penuh).
  String get shortDisplayId => id.length <= 14 ? id : '${id.substring(0, 12)}…';

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory SavedPlayerPreset.fromJson(Map<String, dynamic> json) {
    return SavedPlayerPreset(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  static String generateId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return 'sp_${t}_${t.toRadixString(16)}';
  }
}

class Player {
  const Player({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(id: json['id'] as String, name: json['name'] as String);
  }
}

class RuleConfig {
  const RuleConfig({
    required this.winnerMode,
    this.targetScore,
    this.maxRounds,
  });

  final WinnerMode winnerMode;
  final int? targetScore;
  final int? maxRounds;

  Map<String, dynamic> toJson() => {
    'winnerMode': winnerMode.name,
    'targetScore': targetScore,
    'maxRounds': maxRounds,
  };

  factory RuleConfig.fromJson(Map<String, dynamic> json) {
    return RuleConfig(
      winnerMode: WinnerMode.values.firstWhere(
        (mode) => mode.name == json['winnerMode'],
      ),
      targetScore: json['targetScore'] as int?,
      maxRounds: json['maxRounds'] as int?,
    );
  }
}

class RoundScore {
  const RoundScore({
    required this.roundNumber,
    required this.elapsedSeconds,
    required this.scores,
  });

  final int roundNumber;
  final int elapsedSeconds;
  final Map<String, int> scores;

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'elapsedSeconds': elapsedSeconds,
    'scores': scores,
  };

  factory RoundScore.fromJson(Map<String, dynamic> json) {
    return RoundScore(
      roundNumber: json['roundNumber'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
      scores: (json['scores'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }
}

class GameSession {
  const GameSession({
    required this.id,
    required this.name,
    required this.seasonName,
    required this.players,
    required this.rules,
    required this.createdAt,
    required this.rounds,
    this.finishedAt,
    this.ignoredInStandings = false,
  });

  final String id;
  final String name;
  final String seasonName;
  final List<Player> players;
  final RuleConfig rules;
  final DateTime createdAt;
  final List<RoundScore> rounds;
  final DateTime? finishedAt;
  final bool ignoredInStandings;

  GameSession copyWith({
    String? id,
    String? name,
    String? seasonName,
    List<Player>? players,
    RuleConfig? rules,
    DateTime? createdAt,
    List<RoundScore>? rounds,
    DateTime? finishedAt,
    bool? ignoredInStandings,
    bool clearFinishedAt = false,
  }) {
    return GameSession(
      id: id ?? this.id,
      name: name ?? this.name,
      seasonName: seasonName ?? this.seasonName,
      players: players ?? this.players,
      rules: rules ?? this.rules,
      createdAt: createdAt ?? this.createdAt,
      rounds: rounds ?? this.rounds,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      ignoredInStandings: ignoredInStandings ?? this.ignoredInStandings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seasonName': seasonName,
    'players': players.map((player) => player.toJson()).toList(),
    'rules': rules.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'rounds': rounds.map((round) => round.toJson()).toList(),
    'finishedAt': finishedAt?.toIso8601String(),
    'ignoredInStandings': ignoredInStandings,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      name: json['name'] as String,
      seasonName: (json['seasonName'] as String?) ?? 'Season Umum',
      players: (json['players'] as List<dynamic>)
          .map((item) => Player.fromJson(item as Map<String, dynamic>))
          .toList(),
      rules: RuleConfig.fromJson(json['rules'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      rounds: (json['rounds'] as List<dynamic>)
          .map((item) => RoundScore.fromJson(item as Map<String, dynamic>))
          .toList(),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
      ignoredInStandings: (json['ignoredInStandings'] as bool?) ?? false,
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory GameSession.fromRawJson(String source) {
    return GameSession.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}
