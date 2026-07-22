import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_models.dart';
import '../models/standings_models.dart';

class LocalStorageService {
  static const historyKey = 'game_history_v1';
  static const themeKey = 'theme_mode_v1';
  static const savedPlayersKey = 'saved_players_v1';
  static const savedPlayersV2Key = 'saved_players_v2';
  static const activeSessionKey = 'active_session_v1';
  static const manualStandingsKey = 'manual_standings_v1';
  static const standingsHiddenPlayersKey = 'standings_hidden_players_v1';
  static const presetDeletionPinKey = 'preset_deletion_pin_v1';

  Future<List<GameSession>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(historyKey) ?? <String>[];
    return raw.map(GameSession.fromRawJson).toList();
  }

  Future<void> saveHistory(List<GameSession> history) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = history.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(historyKey, raw);
  }

  Future<String?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(themeKey);
  }

  Future<void> saveThemeMode(String modeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, modeName);
  }

  Future<List<SavedPlayerPreset>> loadSavedPlayerPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(savedPlayersV2Key);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedPlayerPreset.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final legacy = prefs.getStringList(savedPlayersKey) ?? <String>[];
    if (legacy.isEmpty) {
      return <SavedPlayerPreset>[];
    }
    final migrated = <SavedPlayerPreset>[];
    final ts = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < legacy.length; i++) {
      migrated.add(
        SavedPlayerPreset(
          id: 'mig_${ts}_${i}_${legacy[i].hashCode}',
          name: legacy[i],
        ),
      );
    }
    await saveSavedPlayerPresets(migrated);
    await prefs.remove(savedPlayersKey);
    return migrated;
  }

  Future<void> saveSavedPlayerPresets(List<SavedPlayerPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((p) => p.toJson()).toList());
    await prefs.setString(savedPlayersV2Key, encoded);
  }

  Future<GameSession?> loadActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(activeSessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return GameSession.fromRawJson(raw);
  }

  Future<void> saveActiveSession(GameSession? session) async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(activeSessionKey);
      return;
    }
    await prefs.setString(activeSessionKey, session.toRawJson());
  }

  Future<Map<String, List<StandingRow>>> loadManualStandings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(manualStandingsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((season, listRaw) {
      final rows = (listRaw as List<dynamic>)
          .map((item) => StandingRow.fromJson(item as Map<String, dynamic>))
          .toList();
      return MapEntry(season, rows);
    });
  }

  Future<void> saveManualStandings(Map<String, List<StandingRow>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = data.map(
      (season, rows) => MapEntry(
        season,
        rows.map((row) => row.toJson()).toList(),
      ),
    );
    await prefs.setString(manualStandingsKey, jsonEncode(encoded));
  }

  Future<Map<String, List<String>>> loadStandingsHiddenPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(standingsHiddenPlayersKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (season, listRaw) => MapEntry(
        season,
        (listRaw as List<dynamic>).map((e) => e as String).toList(),
      ),
    );
  }

  Future<void> saveStandingsHiddenPlayers(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(standingsHiddenPlayersKey, jsonEncode(data));
  }

  Future<String?> loadPresetDeletionPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(presetDeletionPinKey);
  }

  Future<void> savePresetDeletionPin(String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == null || pin.isEmpty) {
      await prefs.remove(presetDeletionPinKey);
    } else {
      await prefs.setString(presetDeletionPinKey, pin);
    }
  }
}
