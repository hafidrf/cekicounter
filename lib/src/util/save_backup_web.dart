import 'package:share_plus/share_plus.dart';

Future<void> shareBackupJson(String json) async {
  await Share.share(json, subject: 'Backup Ceki League');
}
