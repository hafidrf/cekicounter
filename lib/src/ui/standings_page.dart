import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/game_models.dart';
import '../models/standings_models.dart';
import '../state/game_controller.dart';

class StandingsPage extends ConsumerStatefulWidget {
  const StandingsPage({super.key});

  @override
  ConsumerState<StandingsPage> createState() => _StandingsPageState();
}

class _StandingsPageState extends ConsumerState<StandingsPage> {
  String? _selectedSeason;

  Future<void> _toggleIgnoreSession(GameSession session) async {
    await ref.read(gameControllerProvider.notifier).setSessionIgnored(
          sessionId: session.id,
          ignored: !session.ignoredInStandings,
        );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteSession(GameSession session) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus sesi'),
        content: Text(
          'Sesi "${session.name}" akan dihapus permanen dari riwayat season ini. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await ref.read(gameControllerProvider.notifier).deleteSession(session.id);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openManualEditDialog({
    StandingRow? existing,
    required String seasonName,
  }) async {
    final name = TextEditingController(text: existing?.playerName ?? '');
    final played = TextEditingController(text: existing?.played.toString() ?? '');
    final points = TextEditingController(text: existing?.points.toString() ?? '');
    final scoreDiff = TextEditingController(text: existing?.scoreDiff.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Tambah manual klasmen' : 'Edit baris klasmen'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama pemain')),
              const SizedBox(height: 8),
              TextField(
                controller: played,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Main'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: points,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Poin'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: scoreDiff,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(labelText: 'Score Akumulasi'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (save == true) {
      final notifier = ref.read(gameControllerProvider.notifier);
      final newRow = StandingRow(
        playerName: name.text.trim(),
        played: int.tryParse(played.text.trim()) ?? 0,
        points: int.tryParse(points.text.trim()) ?? 0,
        scoreDiff: int.tryParse(scoreDiff.text.trim()) ?? 0,
      );
      if (existing == null) {
        await notifier.upsertManualStanding(seasonName, newRow);
      } else {
        await notifier.replaceStandingsRow(
          seasonName: seasonName,
          previousPlayerName: existing.playerName,
          row: newRow,
        );
      }
      if (mounted) {
        setState(() {});
      }
    }
    name.dispose();
    played.dispose();
    points.dispose();
    scoreDiff.dispose();
  }

  Future<void> _confirmDeleteStandingRow({
    required String seasonName,
    required StandingRow row,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dari klasmen'),
        content: Text(
          'Hapus "${row.playerName}" dari tabel klasemen season ini? '
          'Pemain ini tidak lagi dihitung dari sesi (bisa dipakai untuk typo / duplikat).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(gameControllerProvider.notifier).deleteStandingsRow(seasonName, row.playerName);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final seasons = controller.allSeasons();
    if (seasons.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Klasmen Liga'),
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home),
          ),
        ),
        body: const Center(child: Text('Belum ada data season.')),
      );
    }
    final selected = _selectedSeason ?? seasons.first;
    final rows = controller.standingsBySeason(selected);
    final sessions = controller.sessionsBySeason(selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasmen Liga'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090E1A), Color(0xFF121A2D), Color(0xFF1B2340)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Pilih season'),
              items: seasons
                  .map((season) => DropdownMenuItem(value: season, child: Text(season)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSeason = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openManualEditDialog(seasonName: selected),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Input manual klasmen'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF111C31),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minTableWidth = constraints.maxWidth < 360 ? 360.0 : constraints.maxWidth;
                    return Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: minTableWidth),
                          child: Table(
                            columnWidths: const <int, TableColumnWidth>{
                              0: FlexColumnWidth(0.55),
                              1: FlexColumnWidth(2.1),
                              2: FlexColumnWidth(0.85),
                              3: FlexColumnWidth(0.85),
                              4: FlexColumnWidth(1.0),
                              5: FlexColumnWidth(0.95),
                            },
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Colors.white.withOpacity(0.08)),
                              bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
                            ),
                            children: [
                              _standingHeaderRow(),
                              ...rows.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final row = entry.value;
                                return _standingDataRow(
                                  rank: '$idx',
                                  row: row,
                                  onEdit: () => _openManualEditDialog(
                                    existing: row,
                                    seasonName: selected,
                                  ),
                                  onDelete: () => _confirmDeleteStandingRow(
                                    seasonName: selected,
                                    row: row,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: const Color(0xFF111C31),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D4D9A), Color(0xFF144CA8)],
                        ),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aturan poin liga: Rank 1 = 3 poin, Rank 2 = 2 poin, Rank 3 = 1 poin, Rank 4+ = 0 poin. '
                        'Score Akumulasi = total performa skor antar sesi dalam season.',
                        style: TextStyle(color: Color(0xFFB8C7E9), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFF111C31),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: const Text(
                    'Riwayat Per Sesi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Buka/tutup histori pertandingan season ini',
                    style: TextStyle(color: Color(0xFF94A3C4), fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    if (sessions.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Belum ada sesi selesai di season ini.',
                          style: TextStyle(color: Color(0xFF94A3C4)),
                        ),
                      )
                    else
                      ...sessions.map((session) {
                        final totals = controller.calculateTotals(session);
                        final ranking = [...session.players]
                          ..sort((a, b) {
                            final scoreA = totals[a.id] ?? 0;
                            final scoreB = totals[b.id] ?? 0;
                            return session.rules.winnerMode == WinnerMode.lowestScore
                                ? scoreA.compareTo(scoreB)
                                : scoreB.compareTo(scoreA);
                          });
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF182746),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            title: Text(
                              session.name,
                              style: const TextStyle(color: Color(0xFFE5EEFF)),
                            ),
                            subtitle: Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt),
                              style: const TextStyle(color: Color(0xFF94A3C4)),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'toggle_ignore') {
                                  await _toggleIgnoreSession(session);
                                  return;
                                }
                                if (value == 'delete') {
                                  await _deleteSession(session);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle_ignore',
                                  child: Text(
                                    session.ignoredInStandings
                                        ? 'Masukkan lagi ke klasemen'
                                        : 'Ignore sesi ini dari klasemen',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus sesi'),
                                ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            children: [
                              if (session.ignoredInStandings)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3D2A1B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Sesi ini sedang di-ignore dan tidak dihitung ke klasemen.',
                                    style: TextStyle(
                                      color: Color(0xFFFFD8B0),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(56),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(1),
                                },
                                children: [
                                  _sessionHeaderRow(),
                                  ...ranking.asMap().entries.map((entry) {
                                    final rank = entry.key + 1;
                                    final player = entry.value;
                                    return _sessionScoreRow(
                                      rank: rank,
                                      player: player.name,
                                      score: totals[player.id] ?? 0,
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _standingHeaderRow() {
    Text th(String t, {int maxLines = 2}) => Text(
          t,
          maxLines: maxLines,
          softWrap: true,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            height: 1.25,
          ),
        );
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(6, 10, 4, 10), child: th('#')),
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 6, 10), child: th('Pemain')),
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 10), child: th('Main')),
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 10), child: th('Poin')),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: th('Skor\nakum.', maxLines: 2),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 8, 4, 8),
          child: Center(
            child: Icon(Icons.more_horiz, color: Color(0xFF94A3C4), size: 18),
          ),
        ),
      ],
    );
  }

  TableRow _standingDataRow({
    required String rank,
    required StandingRow row,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    Widget cell(String text, {bool numeric = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 3,
            softWrap: true,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: Color(0xFFD7E2FF),
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      );
    }

    return TableRow(
      children: [
        cell(rank, numeric: true),
        cell(row.playerName),
        cell('${row.played}', numeric: true),
        cell('${row.points}', numeric: true),
        cell('${row.scoreDiff}', numeric: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF7EB6FF), size: 20),
              ),
              IconButton(
                tooltip: 'Hapus',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8A8A), size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _sessionHeaderRow() {
    return const TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(
            'Rank',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(
            'Pemain',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(
            'Skor akhir',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  TableRow _sessionScoreRow({
    required int rank,
    required String player,
    required int score,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Text(
            '$rank',
            style: const TextStyle(color: Color(0xFFD7E2FF)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Text(
            player,
            style: const TextStyle(color: Color(0xFFD7E2FF)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Text(
            '$score',
            style: const TextStyle(color: Color(0xFFD7E2FF)),
          ),
        ),
      ],
    );
  }
}
