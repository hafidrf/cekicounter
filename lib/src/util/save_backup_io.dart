import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareBackupJson(String json) async {
  final dir = await getTemporaryDirectory();
  final name = 'ceki_league_backup_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File('${dir.path}/$name');
  await file.writeAsString(json);
  await Share.shareXFiles([XFile(file.path)], text: 'Backup Ceki League');
}
