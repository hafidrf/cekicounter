import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/game_models.dart';
import '../state/game_controller.dart';
import '../state/theme_controller.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  /// Nama cepat selalu ada di pool meski belum simpan preset / belum impor backup.
  static const _defaultSquadNames = ['Agil', 'Andik', 'Fahmi', 'Hafid', 'Noenet'];

  final _sessionController = TextEditingController();
  final _seasonController = TextEditingController(text: 'Season 1');
  List<TextEditingController> _players = List.generate(
    4,
    (index) => TextEditingController(text: 'Pemain ${index + 1}'),
  );
  final _targetController = TextEditingController();
  final _maxRoundsController = TextEditingController();
  final _newPresetNameController = TextEditingController();
  List<SavedPlayerPreset> _savedPresets = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlayers();
    _seasonController.text = ref.read(gameControllerProvider).activeSeason;
  }

  Future<void> _loadSavedPlayers() async {
    await ref.read(gameControllerProvider.notifier).ensurePresetsIncludeStandingsPlayers();
    final presets = await ref.read(gameControllerProvider.notifier).loadSavedPlayerPresets();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedPresets = presets;
      if (presets.isNotEmpty) {
        final sorted = [...presets]..sort((a, b) => a.name.compareTo(b.name));
        for (final controller in _players) {
          controller.dispose();
        }
        _players = sorted
            .take(8)
            .map((p) => TextEditingController(text: p.name))
            .toList();
      }
    });
  }

  Future<void> _refreshSavedPresets() async {
    await ref.read(gameControllerProvider.notifier).ensurePresetsIncludeStandingsPlayers();
    final presets = await ref.read(gameControllerProvider.notifier).loadSavedPlayerPresets();
    if (!mounted) {
      return;
    }
    setState(() => _savedPresets = presets);
  }

  Future<void> _savePlayersPreset() async {
    final names = _players
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    await ref.read(gameControllerProvider.notifier).replacePresetsFromNames(names);
    await _refreshSavedPresets();
  }

  void _appendPlayerRowWithName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) {
      return;
    }
    if (_players.length >= 8) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 8 pemain di meja.')),
      );
      return;
    }
    setState(() {
      _players.add(TextEditingController(text: name));
    });
  }

  Future<void> _editPlayerNameAtIndex(int index) async {
    final current = _players[index];
    final c = TextEditingController(text: current.text);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pemain ${index + 1}'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama di meja',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    c.dispose();
    if (!mounted || result == null) {
      return;
    }
    setState(() => current.text = result);
  }

  void _removePlayerAt(int index) {
    if (_players.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal 2 pemain untuk mulai.')),
      );
      return;
    }
    setState(() {
      final removed = _players.removeAt(index);
      removed.dispose();
    });
  }

  Future<bool> _verifyPresetDeletionPin() async {
    final pinController = TextEditingController();
    final entered = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi PIN'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN hapus preset',
            hintText: 'Sama seperti Home → ☁️ → Atur PIN',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, pinController.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    pinController.dispose();
    if (!mounted || entered == null || entered.isEmpty) {
      return false;
    }
    final stored = await ref.read(gameControllerProvider.notifier).loadPresetDeletionPin();
    if (!mounted) {
      return false;
    }
    if (entered == stored) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN salah.')),
    );
    return false;
  }

  Future<void> _submitNewPresetName() async {
    final text = _newPresetNameController.text;
    final ok = await ref.read(gameControllerProvider.notifier).addSavedPlayerPreset(text);
    if (!mounted) {
      return;
    }
    if (!ok) {
      final empty = text.trim().isEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            empty ? 'Isi nama pemain dulu.' : 'Nama itu sudah ada di daftar preset.',
          ),
        ),
      );
      return;
    }
    _newPresetNameController.clear();
    await _refreshSavedPresets();
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nama tersimpan di preset.')),
    );
  }

  Future<void> _editPresetDialog(SavedPlayerPreset preset) async {
    final editController = TextEditingController(text: preset.name);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perbaiki nama preset'),
        content: TextField(
          controller: editController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama pemain',
            hintText: 'Perbaiki typo di sini',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    editController.dispose();
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    final ok = await ref.read(gameControllerProvider.notifier).renameSavedPlayerPreset(
          id: preset.id,
          newName: result,
        );
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kosong atau sudah dipakai preset lain.')),
      );
      return;
    }
    await _refreshSavedPresets();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _confirmDeletePreset(SavedPlayerPreset preset) async {
    final ctrl = ref.read(gameControllerProvider.notifier);
    final linked = ctrl.isPresetNameLinkedToStandingsOrHistory(preset.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dari preset?'),
        content: Text(
          linked
              ? 'Hapus "${preset.name}" dari daftar preset?\n\n'
                    'Pemain ini tercatat di klasemen atau riwayat sesi — '
                    'untuk melanjutkan Anda harus memasukkan PIN (agar ID tidak berubah karena salah hapus).\n\n'
                    'Data klasemen tidak ikut terhapus.'
              : 'Hapus "${preset.name}" dari daftar preset?\n\n'
                    'Ini tidak menghapus klasemen.\n(ID: ${preset.shortDisplayId})',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Lanjut hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    if (linked) {
      final pinStored = await ctrl.loadPresetDeletionPin();
      if (!mounted) {
        return;
      }
      if (pinStored == null || pinStored.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada PIN. Buka Home → ikon ☁️ → 「Atur PIN hapus preset」, lalu coba lagi.',
            ),
          ),
        );
        return;
      }
      final verified = await _verifyPresetDeletionPin();
      if (!verified || !mounted) {
        return;
      }
    }
    await ctrl.deleteSavedPlayerPreset(preset.id);
    await _refreshSavedPresets();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _seasonController.dispose();
    _targetController.dispose();
    _maxRoundsController.dispose();
    _newPresetNameController.dispose();
    for (final item in _players) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _startGame() async {
    final existingActive = ref.read(gameControllerProvider).activeSession;
    if (existingActive != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sesi aktif terdeteksi'),
          content: Text(
            'Saat ini masih ada sesi aktif "${existingActive.name}". '
            'Kalau mulai game baru, sesi aktif akan diganti.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjut New Game'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    final names = _players
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Minimal 2 pemain.')));
      return;
    }
    await ref
        .read(gameControllerProvider.notifier)
        .startSession(
          name: _sessionController.text.trim(),
          seasonName: _seasonController.text.trim(),
          playerNames: names,
          rules: RuleConfig(
            winnerMode: WinnerMode.highestScore,
            targetScore: int.tryParse(_targetController.text.trim()),
            maxRounds: int.tryParse(_maxRoundsController.text.trim()),
          ),
        );
    await ref.read(gameControllerProvider.notifier).replacePresetsFromNames(names);
    if (!mounted) {
      return;
    }
    context.go('/game');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final seasons = ref.watch(gameControllerProvider.select((s) => s.history)).map((e) => e.seasonName).toSet().toList()..sort();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;

    Widget content = ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 14, compact ? 12 : 16, 20),
      children: [
        Card(
          elevation: 8,
          color: const Color(0xFF111C31),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Siapkan match remi kamu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _seasonController,
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    hintText: 'Contoh: Season 1',
                  ),
                  onChanged: (value) =>
                      ref.read(gameControllerProvider.notifier).setActiveSeason(value),
                ),
                if (seasons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: seasons
                        .map(
                          (season) => ActionChip(
                            label: Text(season),
                            onPressed: () {
                              _seasonController.text = season;
                              ref.read(gameControllerProvider.notifier).setActiveSeason(season);
                              setState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _sessionController,
                  decoration: const InputDecoration(
                    labelText: 'Nama sesi',
                    hintText: 'Contoh: Remi Jumat Malam',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 8,
          color: const Color(0xFF111C31),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pemain',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Klasemen lengkap: dari Home → ☁️ → impor restore_klasmen_terakhir.json.',
                  style: TextStyle(color: Color(0xFF94A3C4), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap kartu pemain untuk mengubah nama. Tambah ke meja dari ikon ⊕ di kartu preset di atas.',
                  style: TextStyle(color: Color(0xFFB8C5E0), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kelola daftar preset',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newPresetNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Tambah nama baru ke preset',
                          hintText: 'Pemain yang belum ada di daftar',
                          filled: true,
                          fillColor: Color(0xFF1A2744),
                        ),
                        onSubmitted: (_) => _submitNewPresetName(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: _submitNewPresetName,
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_savedPresets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Belum ada preset. Tambahkan di atas, atau setelah isi pemain di bawah pakai '
                      '「Simpan preset pemain」.',
                      style: TextStyle(color: Color(0xFF8FA4C8), fontSize: 12, height: 1.35),
                    ),
                  )
                else
                  Column(
                    children: _savedPresets.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: const Color(0xFF1A2744),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${p.shortDisplayId}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8FA4C8),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tambah ke meja',
                                  onPressed: _players.length >= 8
                                      ? null
                                      : () => _appendPlayerRowWithName(p.name),
                                  icon: const Icon(Icons.playlist_add),
                                  color: const Color(0xFF7CB4FF),
                                ),
                                IconButton(
                                  tooltip: 'Perbaiki nama',
                                  onPressed: () => _editPresetDialog(p),
                                  icon: const Icon(Icons.edit_outlined),
                                  color: Colors.white70,
                                ),
                                IconButton(
                                  tooltip: 'Hapus dari preset',
                                  onPressed: () => _confirmDeletePreset(p),
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.redAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Pemain di meja',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final c in _players) {
                          c.dispose();
                        }
                        _players = _defaultSquadNames
                            .map((n) => TextEditingController(text: n))
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Isi cepat 5 pemain (Agil … Noenet)'),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_players.length, (int idx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Material(
                            color: const Color(0xFF1B4332),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _editPlayerNameAtIndex(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Colors.tealAccent.shade100,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _players[idx].text.trim().isEmpty
                                            ? 'Pemain ${idx + 1} (tap untuk nama)'
                                            : _players[idx].text.trim(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus dari meja',
                          onPressed: () => _removePlayerAt(idx),
                          icon: const Icon(Icons.close),
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _players.length >= 8
                            ? null
                            : () => setState(
                                  () => _players.add(TextEditingController()),
                                ),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah baris pemain'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _savePlayersPreset,
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan preset pemain'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 8,
          color: const Color(0xFF111C31),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode custom',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('Mode aktif: Skor tertinggi menang'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target skor (opsional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _maxRoundsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Batas ronde (opsional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _startGame,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Mulai permainan'),
        ),
      ],
    );

    if (!compact) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF10192B),
        title: const Text('Play - Setup Match'),
        actions: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home),
          ),
          IconButton(
            onPressed: () => context.go('/klasemen'),
            icon: const Icon(Icons.leaderboard),
          ),
          PopupMenuButton<ThemeMode>(
            initialValue: themeMode,
            onSelected: (mode) =>
                ref.read(themeControllerProvider.notifier).setMode(mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('System')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
        ],
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
        child: content,
      ),
    );
  }
}
