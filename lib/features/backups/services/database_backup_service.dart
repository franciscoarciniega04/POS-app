import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/local/app_database.dart';

class DatabaseBackupService {
  const DatabaseBackupService._();

  static Future<File> createBackup({
    required AppDatabase database,
    String fileNamePrefix = 'pos_offline_respaldo',
  }) async {
    final directory = await _resolveOutputDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final cleanPrefix = _sanitizeFileNamePrefix(fileNamePrefix);

    final timestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());

    final fileName = '${cleanPrefix}_$timestamp.sqlite';

    final file = File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '$fileName',
    );

    if (await file.exists()) {
      await file.delete();
    }

    await database.createBackupAt(file.path);

    if (!await file.exists()) {
      throw StateError('El archivo de respaldo no fue creado.');
    }

    final fileSize = await file.length();

    if (fileSize <= 0) {
      await file.delete();

      throw StateError('El archivo de respaldo está vacío.');
    }

    return file;
  }

  static String _sanitizeFileNamePrefix(String value) {
    final cleanValue = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');

    if (cleanValue.isEmpty) {
      return 'pos_offline_respaldo';
    }

    return cleanValue;
  }

  static Future<Directory> _resolveOutputDirectory() async {
    try {
      final downloadsDirectory = await getDownloadsDirectory();

      if (downloadsDirectory != null) {
        return downloadsDirectory;
      }
    } on UnsupportedError {
      // Se utilizará Documentos como alternativa.
    }

    return getApplicationDocumentsDirectory();
  }
}
