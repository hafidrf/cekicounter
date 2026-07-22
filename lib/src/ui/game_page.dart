import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game_models.dart';
import '../state/game_controller.dart';

class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  final _repaintKey = GlobalKey();
  late final Stopwatch _stopwatch;
  late final ScrollController _tableVerticalController;
  Timer? _ticker;
  static const _chartPalette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFE11D48),
    Color(0xFF7C3AED),
  ];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _tableVerticalController = ScrollController();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tableVerticalController.dispose();
    super.dispose();
  }

  String _timerText() {
    final elapsed = _stopwatch.elapsed;
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _addRound(GameSession session) async {
    final controllers = {
      for (final player in session.players) player.id: TextEditingController(),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ronde ${session.rounds.length + 1}'),
          content: SizedBox(
            width: 380,
            child: _scoreInputs(session, controllers),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (result != true) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }
    final scores = <String, int>{
      for (final entry in controllers.entries) entry.key: int.tryParse(entry.value.text) ?? 0,
    };
    for (final controller in controllers.values) {
      controller.dispose();
    }
    await ref
        .read(gameControllerProvider.notifier)
        .addRound(scores, _stopwatch.elapsed.inSeconds);
    _stopwatch.reset();
    _stopwatch.start();
  }

  Future<void> _editRound(GameSession session) async {
    if (session.rounds.isEmpty) {
      return;
    }
    final pickedRound = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih ronde untuk diedit'),
        children: session.rounds
            .map(
              (round) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, round.roundNumber),
                child: Text('Ronde ${round.roundNumber}'),
              ),
            )
            .toList(),
      ),
    );
    if (pickedRound == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final target = session.rounds.firstWhere((round) => round.roundNumber == pickedRound);
    final controllers = {
      for (final player in session.players)
        player.id: TextEditingController(
          text: (target.scores[player.id] ?? 0) == 0 ? '' : '${target.scores[player.id] ?? 0}',
        ),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Ronde $pickedRound'),
        content: SizedBox(
          width: 380,
          child: _scoreInputs(session, controllers),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan perubahan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final scores = <String, int>{
        for (final entry in controllers.entries) entry.key: int.tryParse(entry.value.text) ?? 0,
      };
      await ref
          .read(gameControllerProvider.notifier)
          .updateRound(roundNumber: pickedRound, scores: scores);
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _scoreInputs(
    GameSession session,
    Map<String, TextEditingController> controllers,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: session.players.map((player) {
        final controller = controllers[player.id]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: player.name,
                    hintText: 'Kosong = 0',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2744),
                  foregroundColor: const Color(0xFFBFD4FF),
                ),
                onPressed: () {
                  final raw = int.tryParse(controller.text.trim()) ?? 0;
                  final next = -raw.abs();
                  controller.text = next == 0 ? '' : '$next';
                },
                child: const Text('-'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _deleteRound(GameSession session) async {
    if (session.rounds.isEmpty) {
      return;
    }
    final pickedRound = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih ronde untuk dihapus'),
        children: session.rounds
            .map(
              (round) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, round.roundNumber),
                child: Text('Ronde ${round.roundNumber}'),
              ),
            )
            .toList(),
      ),
    );
    if (pickedRound == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi hapus'),
        content: Text('Yakin ingin menghapus Ronde $pickedRound?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gameControllerProvider.notifier).deleteRound(pickedRound);
    }
  }

  Future<void> _exportCsv(GameSession session, Map<String, int> totals) async {
    final rows = <List<dynamic>>[];
    rows.add(['Pemain', ...session.rounds.map((item) => 'R${item.roundNumber}'), 'Total']);
    for (final player in session.players) {
      rows.add([
        player.name,
        ...session.rounds.map((round) => round.scores[player.id] ?? 0),
        totals[player.id] ?? 0,
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ceki_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Hasil skor remi');
  }

  Future<void> _exportImage() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }
    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ceki_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Screenshot skor remi');
  }

  List<FlSpot> _spotsForPlayer(GameSession session, String playerId) {
    var running = 0;
    final spots = <FlSpot>[];
    for (final round in session.rounds) {
      running += round.scores[playerId] ?? 0;
      spots.add(FlSpot(round.roundNumber.toDouble(), running.toDouble()));
    }
    return spots;
  }

  Widget _buildLegendTile({
    required Color color,
    required String label,
    required int score,
    required bool highlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($score)',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFDCE6FF),
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(String value) {
    if (value.length <= 8) return value;
    return '${value.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/play'),
            child: const Text('Kembali ke setup'),
          ),
        ),
      );
    }
    final controller = ref.read(gameControllerProvider.notifier);
    final totals = controller.calculateTotals(session);
    final winner = controller.winner(session);
    final loser = controller.loser(session);
    final finished = controller.isSessionFinished(session);
    final chartSpots = {
      for (final player in session.players) player.id: _spotsForPlayer(session, player.id),
    };
    final allChartPoints = chartSpots.values.expand((spots) => spots).toList();
    final minY = allChartPoints.isEmpty
        ? -10.0
        : allChartPoints.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = allChartPoints.isEmpty
        ? 10.0
        : allChartPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 10;
    final ranked = [...session.players]
      ..sort((a, b) {
        final scoreA = totals[a.id] ?? 0;
        final scoreB = totals[b.id] ?? 0;
        return session.rules.winnerMode == WinnerMode.lowestScore
            ? scoreA.compareTo(scoreB)
            : scoreB.compareTo(scoreA);
      });
    final maxAbs = math.max(maxY.abs(), minY.abs());
    final leftTick = (maxAbs * -1).toInt();
    final rightTick = maxAbs.toInt();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF10192B),
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded),
          tooltip: 'Kembali ke home',
        ),
        title: Text(session.name),
        actions: [
          IconButton(
            onPressed: () => controller.undoLastRound(),
            icon: const Icon(Icons.undo),
            tooltip: 'Undo ronde terakhir',
          ),
          IconButton(
            onPressed: () => _exportCsv(session, totals),
            icon: const Icon(Icons.table_view),
            tooltip: 'Export CSV',
          ),
          IconButton(
            onPressed: _exportImage,
            icon: const Icon(Icons.image),
            tooltip: 'Export gambar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRound(session),
        icon: const Icon(Icons.add),
        label: const Text('Tambah ronde'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090E1A),
              Color(0xFF121A2D),
              Color(0xFF1B2340),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 8,
              color: const Color(0xFF111C31),
              shadowColor: Colors.black.withOpacity(0.35),
              child: ListTile(
                textColor: Colors.white,
                title: Text('Timer ronde: ${_timerText()}'),
                subtitle: Text(
                  'Rules: Tertinggi menang'
                  ' | Target: ${session.rules.targetScore ?? "-"} | Maks ronde: ${session.rules.maxRounds ?? "-"}',
                  style: const TextStyle(color: Color(0xFFA9B4D0)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _repaintKey,
              child: Card(
                elevation: 8,
                color: const Color(0xFF111C31),
                shadowColor: Colors.black.withOpacity(0.35),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _editRound(session),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit ronde'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _deleteRound(session),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus ronde'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const firstCol = 54.0;
                          final count = session.players.length.clamp(1, 99);
                          final usable = constraints.maxWidth - firstCol - 2;
                          final colWidth = (usable / count).clamp(48.0, 120.0);
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF13203B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF28406A)),
                            ),
                            child: Column(
                              children: [
                                Table(
                                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  columnWidths: {
                                    0: const FixedColumnWidth(firstCol),
                                    for (var i = 1; i <= session.players.length; i += 1)
                                      i: FixedColumnWidth(colWidth),
                                  },
                                  children: [
                                    TableRow(
                                      children: [
                                        _tableCellCompact('#', isHeader: true),
                                        ...session.players.map(
                                          (player) => _tableCellCompact(
                                            _shortName(player.name),
                                            isHeader: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _tableCellCompact('Total', isTotalRow: true),
                                        ...session.players.map(
                                          (player) => _tableCellCompact(
                                            '${totals[player.id] ?? 0}',
                                            isTotalRow: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 300,
                                  child: Scrollbar(
                                    controller: _tableVerticalController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _tableVerticalController,
                                      child: Table(
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        columnWidths: {
                                          0: const FixedColumnWidth(firstCol),
                                          for (var i = 1; i <= session.players.length; i += 1)
                                            i: FixedColumnWidth(colWidth),
                                        },
                                        children: session.rounds.map((round) {
                                          return TableRow(
                                            children: [
                                              _tableCellCompact('R${round.roundNumber}'),
                                              ...session.players.map(
                                                (player) => _tableCellCompact(
                                                  '${round.scores[player.id] ?? 0}',
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 8,
              color: const Color(0xFF111C31),
              shadowColor: Colors.black.withOpacity(0.35),
              child: ListTile(
                textColor: Colors.white,
                title: winner == null
                    ? const Text('Belum ada pemenang')
                    : Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Seng mBahlil'),
                            const TextSpan(
                              text: '❌',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            TextSpan(text: ': ${winner.name} (${totals[winner.id]})'),
                          ],
                        ),
                      ),
                subtitle: Text(
                  'Pecundang ngucut: ${loser?.name ?? "-"} (${loser == null ? "-" : totals[loser.id]})\n'
                  'Update ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const TextStyle(color: Color(0xFFA9B4D0)),
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: session.rounds.isEmpty
                      ? null
                      : () async {
                          final router = GoRouter.of(context);
                          final shouldFinish = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Selesaikan sesi?'),
                              content: const Text(
                                'Sesi akan masuk ke klasemen season dan disimpan ke riwayat.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Finish'),
                                ),
                              ],
                            ),
                          );
                          if (shouldFinish != true) {
                            return;
                          }
                          await controller.finishSession();
                          if (!mounted) return;
                          router.go('/klasemen');
                        },
                  child: Text(finished ? 'Finish' : 'Finish manual'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              elevation: 10,
              color: const Color(0xFF0D1426),
              shadowColor: Colors.black.withOpacity(0.45),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  iconColor: const Color(0xFFB7C8F0),
                  collapsedIconColor: const Color(0xFFB7C8F0),
                  title: const Text(
                    'Tampilkan grafik performa',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Klik untuk buka / tutup chart',
                    style: TextStyle(color: Color(0xFF94A3C4), fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF111F3E), Color(0xFF0B1530)],
                        ),
                        border: Border.all(color: const Color(0xFF314A80).withOpacity(0.65)),
                      ),
                      child: SizedBox(
                        height: 255,
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xFFEDF2FF),
                                getTooltipItems: (spots) {
                                  return spots.map((spot) {
                                    final player = session.players[spot.barIndex];
                                    return LineTooltipItem(
                                      '${_shortName(player.name)}\nR${spot.x.toInt()}  •  ${spot.y.toInt()}',
                                      const TextStyle(
                                        color: Color(0xFF1D2A4B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: ((maxY - minY) / 4).clamp(1, 9999).toDouble(),
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: const Color(0xFF566D9E).withOpacity(0.35),
                                strokeWidth: 1,
                              ),
                              getDrawingVerticalLine: (value) => FlLine(
                                color: const Color(0xFF566D9E).withOpacity(0.18),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, _) {
                                    if (value < 1 || value > session.rounds.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'R${value.toInt()}',
                                        style: const TextStyle(
                                          color: Color(0xFF9AADE0),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: 0,
                                  color: const Color(0xFF89A2DC),
                                  strokeWidth: 1.1,
                                  dashArray: [6, 6],
                                ),
                              ],
                            ),
                            lineBarsData: session.players.asMap().entries.map((entry) {
                              final player = entry.value;
                              final spots = chartSpots[player.id] ?? const <FlSpot>[];
                              final color = _chartPalette[entry.key % _chartPalette.length];
                              return LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                curveSmoothness: 0.23,
                                barWidth: 3.3,
                                color: color,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) =>
                                      FlDotCirclePainter(
                                        radius: spot == bar.spots.last ? 3.8 : 2.4,
                                        color: color,
                                        strokeWidth: 1,
                                        strokeColor: Colors.white.withOpacity(0.85),
                                      ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [color.withOpacity(0.22), color.withOpacity(0.02)],
                                  ),
                                ),
                              );
                            }).toList(),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: const Color(0xFF3A4F83)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '$leftTick',
                          style: const TextStyle(color: Color(0xFF7E95C7), fontSize: 11),
                        ),
                        const Spacer(),
                        const Text(
                          'Baseline 0',
                          style: TextStyle(color: Color(0xFF9AADE0), fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          '$rightTick',
                          style: const TextStyle(color: Color(0xFF7E95C7), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ranked.asMap().entries.map((entry) {
                        final player = entry.value;
                        final color = _chartPalette[entry.key % _chartPalette.length];
                        return _buildLegendTile(
                          color: color,
                          label: _shortName(player.name),
                          score: totals[player.id] ?? 0,
                          highlighted: winner?.id == player.id || loser?.id == player.id,
                        );
                      }).toList(),
                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCellCompact(
    String text, {
    bool isHeader = false,
    bool isTotalRow = false,
  }) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isHeader
            ? const Color(0xFF1A2A4A)
            : isTotalRow
            ? const Color(0xFF1D345E)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF243B61)),
        ),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isTotalRow
              ? const Color(0xFFEAF1FF)
              : const Color(0xFFD3DFFD),
          fontWeight: isHeader || isTotalRow ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
