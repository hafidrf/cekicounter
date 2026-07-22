import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/game_controller.dart';
import '../util/backup_exporter.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final json =
          await ref.read(gameControllerProvider.notifier).exportBackupJsonString();
      await shareBackupJson(json);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Backup dibuat — pilih cara simpan / bagikan.')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan dari backup?'),
        content: const Text(
          'Semua data yang ada sekarang di app akan diganti dengan isi file backup '
          '(histori, klasemen manual, preset pemain, sesi aktif, dll.).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, pulihkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        messenger?.showSnackBar(const SnackBar(content: Text('Tidak ada file dipilih.')));
        return;
      }
      final raw = utf8.decode(bytes);
      await ref.read(gameControllerProvider.notifier).importBackupReplace(raw);
      if (!context.mounted) {
        return;
      }
      messenger?.showSnackBar(const SnackBar(content: Text('Data berhasil dipulihkan.')));
      router?.go('/klasemen');
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Gagal impor: $e')));
    }
  }

  static const _bundledRestoreAsset = 'assets/restore/restore_klasmen_terakhir.json';

  /// Pulihan klasmen dari screenshot (tanpa file di disk — cocok untuk web).
  Future<void> _loadBundledKlasmenRestore(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Muat pulihan klasmen?'),
        content: const Text(
          'Data di app diganti dengan klasmen manual (Season 1) sesuai backup contoh di app. '
          'Riwayat sesi tetap kosong kecuali kamu punya backup JSON lengkap.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Muat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final raw = await rootBundle.loadString(_bundledRestoreAsset);
      await ref.read(gameControllerProvider.notifier).importBackupReplace(raw);
      if (!context.mounted) {
        return;
      }
      messenger?.showSnackBar(const SnackBar(content: Text('Klasmen manual berhasil dimuat.')));
      router?.go('/klasemen');
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Gagal muat pulihan: $e')));
    }
  }

  Future<void> _openPresetDeletionPinEditor(BuildContext outerContext, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(outerContext);
    final existing = await ref.read(gameControllerProvider.notifier).loadPresetDeletionPin();
    if (!outerContext.mounted) {
      return;
    }
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    await showDialog<void>(
      context: outerContext,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing != null && existing.isNotEmpty ? 'Ubah PIN hapus preset' : 'Buat PIN hapus preset',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PIN dipakai saat menghapus nama pemain dari preset jika pemain itu '
                'sudah tercatat di klasemen atau riwayat sesi — supaya ID pemain tidak '
                'berubah karena hapus tidak sengaja.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              if (existing != null && existing.isNotEmpty) ...[
                TextField(
                  controller: oldC,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN lama'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newC,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN baru',
                  hintText: 'Minimal 4 digit',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmC,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ulangi PIN baru'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final newPin = newC.text.trim();
              if (newPin.length < 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN minimal 4 digit.')),
                );
                return;
              }
              if (newPin != confirmC.text.trim()) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Konfirmasi PIN tidak sama.')),
                );
                return;
              }
              if (existing != null && existing.isNotEmpty && oldC.text.trim() != existing) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN lama salah.')),
                );
                return;
              }
              await ref.read(gameControllerProvider.notifier).savePresetDeletionPin(newPin);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              messenger?.showSnackBar(const SnackBar(content: Text('PIN tersimpan.')));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    oldC.dispose();
    newC.dispose();
    confirmC.dispose();
  }

  void _openBackupSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111C31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Backup & pulihkan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Simpan backup JSON sebelum uninstall atau ganti APK, lalu pulihkan kapan saja.',
                style: TextStyle(color: Color(0xFF94A3C4), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportBackup(context, ref);
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Ekspor backup (JSON)'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _importBackup(context, ref);
                },
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Impor backup (JSON)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadBundledKlasmenRestore(context, ref);
                },
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Muat pulihan klasmen (contoh)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPresetDeletionPinEditor(context, ref);
                },
                icon: const Icon(Icons.pin_outlined),
                label: const Text('Atur PIN hapus preset'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tombol ini memuat data klasmen yang disertakan di app (tanpa pilih file). '
                  'File JSON di folder project tidak otomatis masuk ke browser.',
                  style: TextStyle(color: Color(0xFF94A3C4), fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(gameControllerProvider.select((s) => s.activeSession));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ceki League'),
        actions: [
          IconButton(
            tooltip: 'Backup & pulihkan data',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () => _openBackupSheet(context, ref),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090E1A), Color(0xFF121A2D), Color(0xFF1B2340)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (activeSession != null) ...[
                    _MenuCard(
                      title: 'Continue Game',
                      subtitle: 'Lanjutkan: ${activeSession.name}',
                      icon: Icons.play_circle_fill_rounded,
                      onTap: () => context.go('/game'),
                    ),
                    const SizedBox(height: 12),
                    _MenuCard(
                      title: 'New Game',
                      subtitle: 'Buat sesi baru (setup pemain & season)',
                      icon: Icons.add_circle_outline,
                      onTap: () => context.go('/play'),
                    ),
                  ] else
                    _MenuCard(
                      title: 'Play',
                      subtitle: 'Buat sesi baru dalam season',
                      icon: Icons.sports_esports,
                      onTap: () => context.go('/play'),
                    ),
                  const SizedBox(height: 12),
                  _MenuCard(
                    title: 'Klasmen',
                    subtitle: 'Lihat standing liga per season',
                    icon: Icons.leaderboard,
                    onTap: () => context.go('/klasemen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111C31),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2A3F72),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(subtitle, style: const TextStyle(color: Color(0xFFA8B5D5))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
