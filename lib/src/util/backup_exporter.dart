import 'save_backup_io.dart' if (dart.library.html) 'save_backup_web.dart' as impl;

Future<void> shareBackupJson(String json) => impl.shareBackupJson(json);
