import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../state/game_controller.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Game')),
      body: state.history.isEmpty
          ? const Center(child: Text('Belum ada riwayat game.'))
          : ListView.separated(
              itemCount: state.history.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final session = state.history[index];
                final winner = controller.winner(session);
                final totals = controller.calculateTotals(session);
                return ListTile(
                  title: Text(session.name),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt)}'
                    ' | Ronde: ${session.rounds.length}'
                    ' | Pemenang: ${winner?.name ?? "-"}'
                    ' (${winner == null ? "-" : totals[winner.id]})',
                  ),
                  onTap: () {
                    controller.restoreFromHistory(session.id);
                    context.go('/game');
                  },
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton(
            onPressed: () => context.go('/play'),
            child: const Text('Kembali ke play'),
          ),
        ),
      ),
    );
  }
}
