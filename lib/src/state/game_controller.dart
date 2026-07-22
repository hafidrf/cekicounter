import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_models.dart';
import '../models/standings_models.dart';
import 'theme_controller.dart';

class GameState {
  const GameState({
    required this.history,
    this.activeSession,
    this.undoStack = const [],
    this.activeSeason = 'Season 1',
    this.manualStandings = const {},
    this.standingsHiddenPlayers = const {},
  });

  final List<GameSession> history;
  final GameSession? activeSession;
  final List<GameSession> undoStack;
  final String activeSeason;
  final Map<String, List<StandingRow>> manualStandings;
  /// Player names excluded from klasemen for a season (typo fixes / removed rows).
  final Map<String, List<String>> standingsHiddenPlayers;

  GameState copyWith({
    List<GameSession>? history,
    GameSession? activeSession,
    List<GameSession>? undoStack,
    String? activeSeason,
    Map<String, List<StandingRow>>? manualStandings,
    Map<String, List<String>>? standingsHiddenPlayers,
    bool clearActiveSession = false,
  }) {
    return GameState(
      history: history ?? this.history,
      activeSession: clearActiveSession
          ? null
          : activeSession ?? this.activeSession,
      undoStack: undoStack ?? this.undoStack,
      activeSeason: activeSeason ?? this.activeSeason,
      manualStandings: manualStandings ?? this.manualStandings,
      standingsHiddenPlayers: standingsHiddenPlayers ?? this.standingsHiddenPlayers,
    );
  }
}

final gameControllerProvider = StateNotifierProvider<GameController, GameState>((
  ref,
) {
  return GameController(ref)..loadHistory();
});

class GameController extends StateNotifier<GameState> {
  GameController(this._ref) : super(const GameState(history: <GameSession>[]));

  final Ref _ref;

  Future<void> loadHistory() async {
    final storage = _ref.read(localStorageProvider);
    final history = await storage.loadHistory();
    final activeSession = await storage.loadActiveSession();
    final manualStandings = await storage.loadManualStandings();
    final hiddenPlayers = await storage.loadStandingsHiddenPlayers();
    final seasons = history.map((item) => item.seasonName).toSet().toList()..sort();
    state = state.copyWith(
      history: history,
      activeSession: activeSession,
      activeSeason: activeSession?.seasonName ?? (seasons.isEmpty ? 'Season 1' : seasons.last),
      manualStandings: manualStandings,
      standingsHiddenPlayers: hiddenPlayers,
    );
  }

  void setActiveSeason(String seasonName) {
    state = state.copyWith(activeSeason: seasonName.trim().isEmpty ? 'Season 1' : seasonName.trim());
  }

  List<String> allSeasons() {
    final seasons = <String>{
      ...state.history.map((item) => item.seasonName),
      ...state.manualStandings.keys,
      ...state.standingsHiddenPlayers.keys,
    }.toList()..sort();
    if (!seasons.contains(state.activeSeason)) {
      seasons.add(state.activeSeason);
    }
    return seasons;
  }

  Set<String> _hiddenForSeason(String seasonName) {
    return {...(state.standingsHiddenPlayers[seasonName] ?? const <String>[])};
  }

  Future<void> _persistStandingsHidden(Map<String, List<String>> next) async {
    state = state.copyWith(standingsHiddenPlayers: next);
    await _ref.read(localStorageProvider).saveStandingsHiddenPlayers(next);
  }

  Future<void> hideStandingsPlayer(String seasonName, String playerName) async {
    final key = playerName.trim();
    if (key.isEmpty) {
      return;
    }
    final season = seasonName.trim().isEmpty ? 'Season 1' : seasonName.trim();
    final current = [...(state.standingsHiddenPlayers[season] ?? const <String>[])];
    if (!current.contains(key)) {
      current.add(key);
    }
    final next = {...state.standingsHiddenPlayers, season: current};
    await _persistStandingsHidden(next);
  }

  /// Hapus baris dari klasemen: sembunyikan dari hitungan sesi + hapus entri manual jika ada.
  Future<void> deleteStandingsRow(String seasonName, String playerName) async {
    await hideStandingsPlayer(seasonName, playerName);
    await deleteManualStanding(seasonName, playerName.trim());
  }

  /// Edit/rename baris: update manual; jika nama berubah, sembunyikan nama lama dari hitungan sesi.
  Future<void> replaceStandingsRow({
    required String seasonName,
    required String previousPlayerName,
    required StandingRow row,
  }) async {
    final season = seasonName.trim().isEmpty ? 'Season 1' : seasonName.trim();
    final prev = previousPlayerName.trim();
    final nextName = row.playerName.trim();
    if (nextName.isEmpty) {
      return;
    }
    if (prev != nextName) {
      await hideStandingsPlayer(season, prev);
      await deleteManualStanding(season, prev);
    }
    await upsertManualStanding(season, row.copyWith(playerName: nextName));
  }

  Future<List<SavedPlayerPreset>> loadSavedPlayerPresets() async {
    return _ref.read(localStorageProvider).loadSavedPlayerPresets();
  }

  Future<void> saveSavedPlayerPresets(List<SavedPlayerPreset> presets) async {
    await _ref.read(localStorageProvider).saveSavedPlayerPresets(presets);
  }

  /// Ganti daftar preset sesuai nama pemain saat ini; pertahankan ID jika nama sudah ada.
  Future<void> replacePresetsFromNames(List<String> names) async {
    final existing = await loadSavedPlayerPresets();
    final byName = {for (final p in existing) p.name: p};
    final next = <SavedPlayerPreset>[];
    for (final n in names.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      next.add(byName[n] ?? SavedPlayerPreset(id: SavedPlayerPreset.generateId(), name: n));
    }
    next.sort((a, b) => a.name.compareTo(b.name));
    await saveSavedPlayerPresets(next);
  }

  Future<void> deleteSavedPlayerPreset(String id) async {
    final list = await loadSavedPlayerPresets();
    list.removeWhere((p) => p.id == id);
    await saveSavedPlayerPresets(list);
  }

  /// Pastikan setiap nama di klasemen manual atau riwayat sesi punya baris preset (ID stabil; tidak menghapus yang ada).
  Future<void> ensurePresetsIncludeStandingsPlayers() async {
    final names = <String>{};
    for (final rows in state.manualStandings.values) {
      for (final r in rows) {
        final n = r.playerName.trim();
        if (n.isNotEmpty) {
          names.add(n);
        }
      }
    }
    for (final session in state.history) {
      for (final p in session.players) {
        final n = p.name.trim();
        if (n.isNotEmpty) {
          names.add(n);
        }
      }
    }
    if (names.isEmpty) {
      return;
    }
    final existing = await loadSavedPlayerPresets();
    final haveLower = existing.map((p) => p.name.toLowerCase()).toSet();
    final next = [...existing];
    var changed = false;
    for (final raw in names) {
      final lower = raw.toLowerCase();
      if (!haveLower.contains(lower)) {
        next.add(SavedPlayerPreset(id: SavedPlayerPreset.generateId(), name: raw));
        haveLower.add(lower);
        changed = true;
      }
    }
    if (!changed) {
      return;
    }
    next.sort((a, b) => a.name.compareTo(b.name));
    await saveSavedPlayerPresets(next);
  }

  /// Tambah preset baru (nama unik, non-kosong). Mengembalikan false jika duplikat / kosong.
  Future<bool> addSavedPlayerPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final list = await loadSavedPlayerPresets();
    if (list.any((p) => p.name.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    list.add(SavedPlayerPreset(id: SavedPlayerPreset.generateId(), name: trimmed));
    list.sort((a, b) => a.name.compareTo(b.name));
    await saveSavedPlayerPresets(list);
    return true;
  }

  /// Ubah nama preset (ID sama). Mengembalikan false jika kosong / duplikat / tidak ditemukan.
  Future<String?> loadPresetDeletionPin() async {
    return _ref.read(localStorageProvider).loadPresetDeletionPin();
  }

  Future<void> savePresetDeletionPin(String pin) async {
    await _ref.read(localStorageProvider).savePresetDeletionPin(pin);
  }

  /// True jika nama punya data klasemen manual atau pernah main di riwayat sesi (hapus preset dilindungi PIN).
  bool isPresetNameLinkedToStandingsOrHistory(String rawName) {
    final n = rawName.trim().toLowerCase();
    if (n.isEmpty) {
      return false;
    }
    for (final rows in state.manualStandings.values) {
      for (final r in rows) {
        if (r.playerName.trim().toLowerCase() == n) {
          return true;
        }
      }
    }
    for (final session in state.history) {
      for (final p in session.players) {
        if (p.name.trim().toLowerCase() == n) {
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> renameSavedPlayerPreset({required String id, required String newName}) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final list = await loadSavedPlayerPresets();
    final idx = list.indexWhere((p) => p.id == id);
    if (idx < 0) {
      return false;
    }
    if (list.any((p) => p.id != id && p.name.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    list[idx] = SavedPlayerPreset(id: id, name: trimmed);
    list.sort((a, b) => a.name.compareTo(b.name));
    await saveSavedPlayerPresets(list);
    return true;
  }

  Future<void> startSession({
    required String name,
    required String seasonName,
    required List<String> playerNames,
    required RuleConfig rules,
  }) async {
    final now = DateTime.now();
    final session = GameSession(
      id: now.millisecondsSinceEpoch.toString(),
      name: name.isEmpty ? 'Sesi ${now.day}/${now.month}' : name,
      seasonName: seasonName.trim().isEmpty ? 'Season 1' : seasonName.trim(),
      players: playerNames
          .asMap()
          .entries
          .map(
            (entry) => Player(
              id: 'p${entry.key}_${now.millisecondsSinceEpoch}',
              name: entry.value,
            ),
          )
          .toList(),
      rules: rules,
      createdAt: now,
      rounds: const [],
    );
    state = state.copyWith(activeSession: session, undoStack: const []);
    await _ref.read(localStorageProvider).saveActiveSession(session);
  }

  Future<void> addRound(Map<String, int> scores, int elapsedSeconds) async {
    final active = state.activeSession;
    if (active == null) {
      return;
    }
    final round = RoundScore(
      roundNumber: active.rounds.length + 1,
      elapsedSeconds: elapsedSeconds,
      scores: scores,
    );
    final next = active.copyWith(rounds: <RoundScore>[...active.rounds, round]);
    state = state.copyWith(
      activeSession: next,
      undoStack: <GameSession>[...state.undoStack, active],
    );
    await _ref.read(localStorageProvider).saveActiveSession(next);
  }

  Future<void> updateRound({
    required int roundNumber,
    required Map<String, int> scores,
  }) async {
    final active = state.activeSession;
    if (active == null) {
      return;
    }
    final idx = active.rounds.indexWhere((round) => round.roundNumber == roundNumber);
    if (idx < 0) {
      return;
    }
    final updatedRound = RoundScore(
      roundNumber: roundNumber,
      elapsedSeconds: active.rounds[idx].elapsedSeconds,
      scores: scores,
    );
    final updatedRounds = [...active.rounds];
    updatedRounds[idx] = updatedRound;
    final next = active.copyWith(rounds: updatedRounds);
    state = state.copyWith(
      activeSession: next,
      undoStack: <GameSession>[...state.undoStack, active],
    );
    await _ref.read(localStorageProvider).saveActiveSession(next);
  }

  Future<void> deleteRound(int roundNumber) async {
    final active = state.activeSession;
    if (active == null) {
      return;
    }
    final nextRounds = active.rounds
        .where((round) => round.roundNumber != roundNumber)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => RoundScore(
            roundNumber: entry.key + 1,
            elapsedSeconds: entry.value.elapsedSeconds,
            scores: entry.value.scores,
          ),
        )
        .toList();
    final next = active.copyWith(rounds: nextRounds);
    state = state.copyWith(
      activeSession: next,
      undoStack: <GameSession>[...state.undoStack, active],
    );
    await _ref.read(localStorageProvider).saveActiveSession(next);
  }

  Future<void> undoLastRound() async {
    if (state.undoStack.isEmpty) {
      return;
    }
    final previous = state.undoStack.last;
    final updatedUndo = <GameSession>[...state.undoStack]..removeLast();
    state = state.copyWith(activeSession: previous, undoStack: updatedUndo);
    await _ref.read(localStorageProvider).saveActiveSession(previous);
  }

  Map<String, int> calculateTotals(GameSession session) {
    final totals = {for (final p in session.players) p.id: 0};
    for (final round in session.rounds) {
      for (final player in session.players) {
        totals[player.id] = (totals[player.id] ?? 0) + (round.scores[player.id] ?? 0);
      }
    }
    return totals;
  }

  bool isSessionFinished(GameSession session) {
    final totals = calculateTotals(session);
    final target = session.rules.targetScore;
    final maxRounds = session.rules.maxRounds;

    if (maxRounds != null && session.rounds.length >= maxRounds) {
      return true;
    }
    if (target == null) {
      return false;
    }
    if (session.rules.winnerMode == WinnerMode.highestScore) {
      return totals.values.any((value) => value >= target);
    }
    return totals.values.any((value) => value <= target);
  }

  Player? winner(GameSession session) {
    final totals = calculateTotals(session);
    if (totals.isEmpty) {
      return null;
    }
    final sorted = [...session.players]
      ..sort((a, b) {
        final scoreA = totals[a.id] ?? 0;
        final scoreB = totals[b.id] ?? 0;
        return session.rules.winnerMode == WinnerMode.lowestScore
            ? scoreA.compareTo(scoreB)
            : scoreB.compareTo(scoreA);
      });
    return sorted.first;
  }

  Player? loser(GameSession session) {
    final totals = calculateTotals(session);
    if (totals.isEmpty) {
      return null;
    }
    final sorted = [...session.players]
      ..sort((a, b) {
        final scoreA = totals[a.id] ?? 0;
        final scoreB = totals[b.id] ?? 0;
        return session.rules.winnerMode == WinnerMode.lowestScore
            ? scoreB.compareTo(scoreA)
            : scoreA.compareTo(scoreB);
      });
    return sorted.first;
  }

  Future<void> finishSession() async {
    final active = state.activeSession;
    if (active == null) {
      return;
    }
    final finished = active.copyWith(finishedAt: DateTime.now());
    final history = <GameSession>[
      finished,
      ...state.history.where((item) => item.id != finished.id),
    ];

    await _ref.read(localStorageProvider).saveHistory(history);
    await _ref.read(localStorageProvider).saveActiveSession(null);
    state = state.copyWith(
      history: history,
      clearActiveSession: true,
      undoStack: const [],
    );
  }

  Future<void> restoreFromHistory(String sessionId) async {
    final match = state.history.where((item) => item.id == sessionId).firstOrNull;
    if (match == null) {
      return;
    }
    final restored = match.copyWith(clearFinishedAt: true);
    state = state.copyWith(
      activeSession: restored,
      activeSeason: restored.seasonName,
      undoStack: const [],
    );
    await _ref.read(localStorageProvider).saveActiveSession(restored);
  }

  Future<void> clearActiveSession() async {
    state = state.copyWith(clearActiveSession: true, undoStack: const []);
    await _ref.read(localStorageProvider).saveActiveSession(null);
  }

  Future<void> reopenLastActiveSession() async {
    final active = await _ref.read(localStorageProvider).loadActiveSession();
    if (active == null) {
      return;
    }
    state = state.copyWith(
      activeSession: active,
      activeSeason: active.seasonName,
      undoStack: const [],
    );
  }

  List<StandingRow> standingsBySeason(String seasonName) {
    final hidden = _hiddenForSeason(seasonName);
    final sessions = state.history
        .where((session) => session.seasonName == seasonName && !session.ignoredInStandings)
        .toList();
    final map = <String, StandingRow>{};
    for (final session in sessions) {
      final totals = calculateTotals(session);
      final ranking = [...session.players]
        ..sort((a, b) {
          final scoreA = totals[a.id] ?? 0;
          final scoreB = totals[b.id] ?? 0;
          return session.rules.winnerMode == WinnerMode.lowestScore
              ? scoreA.compareTo(scoreB)
              : scoreB.compareTo(scoreA);
        });
      for (var i = 0; i < ranking.length; i++) {
        final player = ranking[i];
        if (hidden.contains(player.name)) {
          continue;
        }
        final rawScore = totals[player.id] ?? 0;
        final perfScore = session.rules.winnerMode == WinnerMode.lowestScore
            ? -rawScore
            : rawScore;
        final prev = map[player.name] ??
            const StandingRow(playerName: '', played: 0, points: 0, scoreDiff: 0);
        final points = switch (i) {
          0 => 3,
          1 => 2,
          2 => 1,
          _ => 0,
        };
        map[player.name] = StandingRow(
          playerName: player.name,
          played: prev.played + 1,
          points: prev.points + points,
          scoreDiff: prev.scoreDiff + perfScore,
        );
      }
    }
    final manual = state.manualStandings[seasonName] ?? const <StandingRow>[];
    final manualByName = {for (final r in manual) r.playerName: r};
    final allNames = {...map.keys, ...manualByName.keys};
    final merged = <String, StandingRow>{};
    for (final name in allNames) {
      if (name.trim().isEmpty || hidden.contains(name)) {
        continue;
      }
      merged[name] = _sumStandingRows(sessionRow: map[name], baseline: manualByName[name], playerName: name);
    }
    final mergedRows = merged.values.toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) {
          return byPoints;
        }
        return b.scoreDiff.compareTo(a.scoreDiff);
      });
    return mergedRows;
  }

  /// Baseline impor/manual + agregat sesi di musim ini (match baru menambah di atas baseline).
  StandingRow _sumStandingRows({
    required StandingRow? sessionRow,
    required StandingRow? baseline,
    required String playerName,
  }) {
    return StandingRow(
      playerName: playerName,
      played: (sessionRow?.played ?? 0) + (baseline?.played ?? 0),
      points: (sessionRow?.points ?? 0) + (baseline?.points ?? 0),
      scoreDiff: (sessionRow?.scoreDiff ?? 0) + (baseline?.scoreDiff ?? 0),
    );
  }

  List<GameSession> sessionsBySeason(String seasonName) {
    return state.history.where((session) => session.seasonName == seasonName).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> setSessionIgnored({
    required String sessionId,
    required bool ignored,
  }) async {
    final nextHistory = state.history
        .map((session) => session.id == sessionId
            ? session.copyWith(ignoredInStandings: ignored)
            : session)
        .toList();
    state = state.copyWith(history: nextHistory);
    await _ref.read(localStorageProvider).saveHistory(nextHistory);
  }

  Future<void> deleteSession(String sessionId) async {
    final nextHistory = state.history.where((session) => session.id != sessionId).toList();
    state = state.copyWith(history: nextHistory);
    await _ref.read(localStorageProvider).saveHistory(nextHistory);
  }

  Future<void> upsertManualStanding(String seasonName, StandingRow row) async {
    final current = [...(state.manualStandings[seasonName] ?? const <StandingRow>[])];
    final idx = current.indexWhere((item) => item.playerName == row.playerName);
    if (idx >= 0) {
      current[idx] = row;
    } else {
      current.add(row);
    }
    final nextMap = {...state.manualStandings, seasonName: current};
    state = state.copyWith(manualStandings: nextMap);
    await _ref.read(localStorageProvider).saveManualStandings(nextMap);
  }

  Future<void> deleteManualStanding(String seasonName, String playerName) async {
    final current = [...(state.manualStandings[seasonName] ?? const <StandingRow>[])];
    current.removeWhere((row) => row.playerName == playerName);
    final nextMap = {...state.manualStandings, seasonName: current};
    state = state.copyWith(manualStandings: nextMap);
    await _ref.read(localStorageProvider).saveManualStandings(nextMap);
  }

  static const backupSchemaVersion = 2;

  /// JSON lengkap untuk dibagikan/disimpan (histori, sesi aktif, klasmen manual, hidden, preset, tema).
  Future<String> exportBackupJsonString() async {
    final storage = _ref.read(localStorageProvider);
    final savedPresets = await storage.loadSavedPlayerPresets();
    final themeMode = await storage.loadThemeMode() ?? 'system';
    final payload = <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'appId': 'cekicounter',
      'history': state.history.map((s) => s.toJson()).toList(),
      'activeSession': state.activeSession?.toJson(),
      'manualStandings': state.manualStandings.map(
        (season, rows) => MapEntry(season, rows.map((r) => r.toJson()).toList()),
      ),
      'standingsHiddenPlayers': state.standingsHiddenPlayers.map(
        (season, names) => MapEntry(season, List<String>.from(names)),
      ),
      'savedPlayerPresets': savedPresets.map((p) => p.toJson()).toList(),
      'themeMode': themeMode,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Ganti seluruh data lokal dengan isi backup ([rawJson] dari [exportBackupJsonString]).
  Future<void> importBackupReplace(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('File backup tidak valid.');
    }
    final rawSchema = decoded['schemaVersion'] ?? decoded['version'];
    final schemaInt = rawSchema is int ? rawSchema : int.tryParse('$rawSchema') ?? 0;
    if (schemaInt != 1 && schemaInt != 2) {
      throw FormatException('Versi backup tidak didukung ($rawSchema).');
    }
    final appId = decoded['appId'] as String?;
    if (appId != null && appId != 'cekicounter') {
      throw const FormatException('Bukan file backup Ceki League.');
    }

    final historyList = decoded['history'] as List<dynamic>? ?? const [];
    final history = historyList
        .map((e) => GameSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    GameSession? activeSession;
    final activeRaw = decoded['activeSession'];
    if (activeRaw is Map<String, dynamic>) {
      activeSession = GameSession.fromJson(activeRaw);
    }

    final manualRaw = decoded['manualStandings'] as Map<String, dynamic>? ?? {};
    final manualStandings = manualRaw.map((season, listRaw) {
      final rows = (listRaw as List<dynamic>)
          .map((item) => StandingRow.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return MapEntry(season, rows);
    });

    final hiddenRaw = decoded['standingsHiddenPlayers'] as Map<String, dynamic>? ?? {};
    final standingsHiddenPlayers = hiddenRaw.map((season, listRaw) {
      final names = (listRaw as List<dynamic>).map((e) => e as String).toList();
      return MapEntry(season, names);
    });

    final savedPresetsRaw = decoded['savedPlayerPresets'];
    final legacySavedRaw = decoded['savedPlayers'];
    final List<SavedPlayerPreset> savedPresets;
    if (savedPresetsRaw is List<dynamic> && savedPresetsRaw.isNotEmpty) {
      savedPresets = savedPresetsRaw
          .map((e) => SavedPlayerPreset.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (legacySavedRaw is List<dynamic> && legacySavedRaw.isNotEmpty) {
      if (legacySavedRaw.first is String) {
        savedPresets = [
          for (var i = 0; i < legacySavedRaw.length; i++)
            SavedPlayerPreset(
              id: SavedPlayerPreset.generateId(),
              name: legacySavedRaw[i] as String,
            ),
        ];
      } else {
        savedPresets = legacySavedRaw
            .map((e) => SavedPlayerPreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } else {
      savedPresets = <SavedPlayerPreset>[];
    }

    final themeRaw = decoded['themeMode'] as String? ?? 'system';
    final themeMode = ['light', 'dark', 'system'].contains(themeRaw) ? themeRaw : 'system';

    final storage = _ref.read(localStorageProvider);
    await storage.saveHistory(history);
    await storage.saveActiveSession(activeSession);
    await storage.saveManualStandings(manualStandings);
    await storage.saveStandingsHiddenPlayers(standingsHiddenPlayers);
    await storage.saveSavedPlayerPresets(savedPresets);
    await storage.saveThemeMode(themeMode);
    await _ref.read(themeControllerProvider.notifier).load();

    final seasons = history.map((item) => item.seasonName).toSet().toList()..sort();
    state = state.copyWith(
      history: history,
      activeSession: activeSession,
      undoStack: const [],
      manualStandings: manualStandings,
      standingsHiddenPlayers: standingsHiddenPlayers,
      activeSeason: activeSession?.seasonName ?? (seasons.isEmpty ? 'Season 1' : seasons.last),
    );
    await ensurePresetsIncludeStandingsPlayers();
  }
}
