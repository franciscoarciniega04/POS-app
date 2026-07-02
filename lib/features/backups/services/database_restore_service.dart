import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../data/local/app_database.dart';
import 'database_backup_service.dart';

class DatabaseRestartRequiredException implements Exception {
  final String message;
  final bool restoreCompleted;

  const DatabaseRestartRequiredException({
    required this.message,
    required this.restoreCompleted,
  });

  @override
  String toString() => message;
}

class DatabaseRestoreService {
  const DatabaseRestoreService._();

  static Set<String> _requiredTablesForVersion(int databaseVersion) {
    final tables = <String>{
      'products',
      'inventory_movements',
      'purchases',
      'purchase_items',
      'sales',
      'sale_items',
      'expenses',
      'cash_transactions',
    };

    if (databaseVersion >= 2) {
      tables.add('suppliers');
    }

    if (databaseVersion >= 4) {
      tables.add('customers');
    }

    if (databaseVersion >= 5) {
      tables.addAll({
        'customer_orders',
        'customer_order_items',
        'order_purchase_allocations',
      });
    }

    return tables;
  }

  static Future<File?> selectBackupFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'sqlite3', 'db'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;

    if (path == null || path.trim().isEmpty) {
      throw StateError(
        'No fue posible obtener la ruta del archivo seleccionado.',
      );
    }

    return File(path);
  }

  static Future<void> restoreAndRestart({
    required AppDatabase database,
    required File backupFile,
  }) async {
    if (!await backupFile.exists()) {
      throw StateError('El archivo seleccionado ya no existe.');
    }

    if (await backupFile.length() <= 0) {
      throw StateError('El archivo seleccionado está vacío.');
    }

    await _validateDatabaseFile(backupFile);

    final currentDatabaseFile = await AppDatabase.getDatabaseFile();

    final databaseDirectory = currentDatabaseFile.parent;

    if (!await databaseDirectory.exists()) {
      await databaseDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final temporaryRestoreFile = File(
      '${currentDatabaseFile.path}'
      '.restore_$timestamp.tmp',
    );

    final previousDatabaseFile = File(
      '${currentDatabaseFile.path}'
      '.before_restore_$timestamp',
    );

    await _deleteIfExists(temporaryRestoreFile);

    await _deleteIfExists(previousDatabaseFile);

    // Copiamos primero el respaldo a la misma carpeta de la base.
    // La base actual todavía permanece abierta en este punto.
    await backupFile.copy(temporaryRestoreFile.path);

    await _validateDatabaseFile(temporaryRestoreFile);

    // Conservamos una copia de seguridad de la información actual.
    await DatabaseBackupService.createBackup(
      database: database,
      fileNamePrefix: 'pos_offline_antes_restauracion',
    );

    // Windows mantiene bloqueado el archivo mientras Drift está abierto.
    await database.close();

    await _deleteSQLiteSidecarFiles(currentDatabaseFile.path);

    var currentDatabaseWasRenamed = false;

    try {
      if (await currentDatabaseFile.exists()) {
        await currentDatabaseFile.rename(previousDatabaseFile.path);

        currentDatabaseWasRenamed = true;
      }

      await temporaryRestoreFile.rename(currentDatabaseFile.path);

      await _validateDatabaseFile(currentDatabaseFile);

      await _deleteIfExists(previousDatabaseFile);
    } catch (error) {
      await _rollbackDatabaseReplacement(
        currentDatabaseFile: currentDatabaseFile,
        previousDatabaseFile: previousDatabaseFile,
        temporaryRestoreFile: temporaryRestoreFile,
        currentDatabaseWasRenamed: currentDatabaseWasRenamed,
      );

      throw DatabaseRestartRequiredException(
        restoreCompleted: false,
        message:
            'No se pudo aplicar el respaldo. '
            'La base anterior fue recuperada, pero la conexión '
            'ya está cerrada. Cierra y vuelve a abrir la aplicación. '
            'Detalle: $error',
      );
    }

    final restartResult = await Restart.restartApp();

    if (!restartResult.success) {
      throw const DatabaseRestartRequiredException(
        restoreCompleted: true,
        message:
            'El respaldo fue restaurado correctamente, pero '
            'Windows no pudo reiniciar la aplicación de forma '
            'automática. Cierra el programa y vuelve a abrirlo '
            'para cargar la información restaurada.',
      );
    }
  }

  static Future<void> _rollbackDatabaseReplacement({
    required File currentDatabaseFile,
    required File previousDatabaseFile,
    required File temporaryRestoreFile,
    required bool currentDatabaseWasRenamed,
  }) async {
    await _deleteIfExists(currentDatabaseFile);

    if (currentDatabaseWasRenamed && await previousDatabaseFile.exists()) {
      await previousDatabaseFile.rename(currentDatabaseFile.path);
    }

    await _deleteIfExists(temporaryRestoreFile);
  }

  static Future<void> _validateDatabaseFile(File file) async {
    Database? sqliteDatabase;

    try {
      sqliteDatabase = sqlite3.open(file.path, mode: OpenMode.readOnly);

      final integrityRows = sqliteDatabase.select('PRAGMA integrity_check;');

      if (integrityRows.isEmpty) {
        throw const FormatException(
          'SQLite no devolvió un resultado de integridad.',
        );
      }

      final integrityResult = integrityRows.first.values.first.toString();

      if (integrityResult.toLowerCase() != 'ok') {
        throw FormatException(
          'La verificación de integridad falló: '
          '$integrityResult',
        );
      }

      final databaseVersion = _readDatabaseVersion(sqliteDatabase);

      if (databaseVersion <= 0) {
        throw const FormatException(
          'El archivo no contiene una versión válida '
          'de la base de datos.',
        );
      }

      if (databaseVersion > AppDatabase.currentSchemaVersion) {
        throw FormatException(
          'El respaldo pertenece a una versión más nueva '
          'de la aplicación. Versión del respaldo: '
          '$databaseVersion. Versión compatible: '
          '${AppDatabase.currentSchemaVersion}.',
        );
      }

      final requiredTables = _requiredTablesForVersion(databaseVersion);

      final tableNames = _readTableNames(sqliteDatabase);

      final missingTables = requiredTables.difference(tableNames).toList()
        ..sort();

      if (missingTables.isNotEmpty) {
        throw FormatException(
          'El archivo no parece ser un respaldo válido '
          'del POS. Faltan estas tablas: '
          '${missingTables.join(', ')}.',
        );
      }

      if (databaseVersion >= 3) {
        final saleItemColumns = _readColumnNames(sqliteDatabase, 'sale_items');

        if (!saleItemColumns.contains('unit_cost_cents')) {
          throw const FormatException(
            'El respaldo indica que usa la versión 3, '
            'pero no contiene el costo histórico de las ventas.',
          );
        }
      }
    } on SqliteException catch (error) {
      throw FormatException(
        'El archivo seleccionado no es una base SQLite '
        'válida o está dañado. Detalle: $error',
      );
    } finally {
      sqliteDatabase?.close();
    }
  }

  static int _readDatabaseVersion(Database database) {
    final rows = database.select('PRAGMA user_version;');

    if (rows.isEmpty) {
      throw const FormatException('No se pudo obtener la versión de la base.');
    }

    final value = rows.first.values.first;

    return switch (value) {
      int intValue => intValue,
      BigInt bigIntValue => bigIntValue.toInt(),
      _ => int.tryParse(value.toString()) ?? 0,
    };
  }

  static Set<String> _readTableNames(Database database) {
    final rows = database.select('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ''');

    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static Set<String> _readColumnNames(Database database, String tableName) {
    final escapedTableName = tableName.replaceAll("'", "''");

    final rows = database.select("PRAGMA table_info('$escapedTableName');");

    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static Future<void> _deleteSQLiteSidecarFiles(String databasePath) async {
    final files = [
      File('$databasePath-wal'),
      File('$databasePath-shm'),
      File('$databasePath-journal'),
    ];

    for (final file in files) {
      await _deleteIfExists(file);
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
