import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../services/database_backup_service.dart';
import '../services/database_restore_service.dart';

class BackupScreen extends StatefulWidget {
  final AppDatabase database;

  const BackupScreen({super.key, required this.database});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isCreatingBackup = false;
  bool _isRestoringBackup = false;

  File? _lastBackup;
  DateTime? _lastBackupDate;

  bool get _isBusy => _isCreatingBackup || _isRestoringBackup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Respaldos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _BackupIntroductionCard(
                isCreatingBackup: _isCreatingBackup,
                isDisabled: _isRestoringBackup,
                onCreateBackup: _createBackup,
              ),
              const SizedBox(height: 16),
              const _BackupContentCard(),
              const SizedBox(height: 16),
              _RestoreBackupCard(
                isRestoring: _isRestoringBackup,
                isDisabled: _isCreatingBackup,
                onRestore: _restoreBackup,
              ),
              if (_lastBackup != null) ...[
                const SizedBox(height: 16),
                _BackupResultCard(
                  file: _lastBackup!,
                  createdAt: _lastBackupDate ?? DateTime.now(),
                ),
              ],
              const SizedBox(height: 16),
              const _BackupRecommendationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isCreatingBackup = true;
    });

    try {
      final file = await DatabaseBackupService.createBackup(
        database: widget.database,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingBackup = false;
        _lastBackup = file;
        _lastBackupDate = DateTime.now();
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF15803D),
              size: 42,
            ),
            title: const Text('Respaldo creado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('La base de datos se respaldó correctamente.'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingBackup = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el respaldo: $error')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBusy) {
      return;
    }

    try {
      final backupFile = await DatabaseRestoreService.selectBackupFile();

      if (backupFile == null || !mounted) {
        return;
      }

      final fileName = backupFile.path.split(Platform.pathSeparator).last;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 42,
            ),
            title: const Text('Restaurar respaldo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La información actual será reemplazada '
                  'por el contenido del respaldo seleccionado.',
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Antes de reemplazar la información se creará '
                  'automáticamente un respaldo de seguridad de '
                  'la base actual en la carpeta Descargas.',
                  style: TextStyle(color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restaurar y reiniciar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      setState(() {
        _isRestoringBackup = true;
      });

      await DatabaseRestoreService.restoreAndRestart(
        database: widget.database,
        backupFile: backupFile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringBackup = false;
      });
    } on DatabaseRestartRequiredException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringBackup = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: Icon(
              error.restoreCompleted
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: error.restoreCompleted
                  ? const Color(0xFF15803D)
                  : Colors.redAccent,
              size: 42,
            ),
            title: Text(
              error.restoreCompleted
                  ? 'Respaldo restaurado'
                  : 'Restauración cancelada',
            ),
            content: SelectableText(error.message),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cerrar aplicación'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        await SystemNavigator.pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringBackup = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 40,
            ),
            title: const Text('No se pudo restaurar'),
            content: SelectableText(error.toString()),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );
    }
  }
}

class _BackupIntroductionCard extends StatelessWidget {
  final bool isCreatingBackup;
  final bool isDisabled;
  final VoidCallback onCreateBackup;

  const _BackupIntroductionCard({
    required this.isCreatingBackup,
    required this.isDisabled,
    required this.onCreateBackup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final information = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.backup_outlined,
                    color: Color(0xFF1D4ED8),
                    size: 31,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Respaldar base de datos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Genera una copia completa de la información '
                        'del punto de venta y guárdala en la carpeta '
                        'Descargas.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final button = FilledButton.icon(
              onPressed: isCreatingBackup || isDisabled ? null : onCreateBackup,
              icon: isCreatingBackup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_alt_outlined),
              label: Text(
                isCreatingBackup ? 'Creando respaldo...' : 'Crear respaldo',
              ),
            );

            if (constraints.maxWidth >= 680) {
              return Row(
                children: [
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  button,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [information, const SizedBox(height: 20), button],
            );
          },
        ),
      ),
    );
  }
}

class _BackupContentCard extends StatelessWidget {
  const _BackupContentCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.inventory_2_outlined, 'Productos e inventario'),
      (Icons.people_outline, 'Clientes'),
      (Icons.assignment_outlined, 'Pedidos y productos solicitados'),
      (Icons.shopping_cart_outlined, 'Compras, proveedores y surtidos'),
      (Icons.point_of_sale_outlined, 'Ventas y costos históricos'),
      (Icons.receipt_long_outlined, 'Gastos y movimientos de caja'),
    ];

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información incluida',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < items.length; index++) ...[
              _BackupContentRow(icon: items[index].$1, label: items[index].$2),
              if (index < items.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupContentRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BackupContentRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF475569), size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
      ],
    );
  }
}

class _RestoreBackupCard extends StatelessWidget {
  final bool isRestoring;
  final bool isDisabled;
  final VoidCallback onRestore;

  const _RestoreBackupCard({
    required this.isRestoring,
    required this.isDisabled,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final information = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.restore_outlined,
                    color: Color(0xFFB45309),
                    size: 31,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurar respaldo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Selecciona un respaldo SQLite para '
                        'reemplazar la información actual del POS.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final button = FilledButton.icon(
              onPressed: isRestoring || isDisabled ? null : onRestore,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              icon: isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                isRestoring ? 'Restaurando...' : 'Seleccionar respaldo',
              ),
            );

            if (constraints.maxWidth >= 680) {
              return Row(
                children: [
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  button,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [information, const SizedBox(height: 20), button],
            );
          },
        ),
      ),
    );
  }
}

class _BackupResultCard extends StatelessWidget {
  final File file;
  final DateTime createdAt;

  const _BackupResultCard({required this.file, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm:ss');

    final sizeInKilobytes = file.lengthSync() / 1024;

    final formattedSize = sizeInKilobytes >= 1024
        ? '${(sizeInKilobytes / 1024).toStringAsFixed(2)} MB'
        : '${sizeInKilobytes.toStringAsFixed(2)} KB';

    return Card(
      color: const Color(0xFFECFDF3),
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Último respaldo creado',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _BackupDetailRow(
              label: 'Fecha',
              value: dateFormatter.format(createdAt),
            ),
            const SizedBox(height: 8),
            _BackupDetailRow(label: 'Tamaño', value: formattedSize),
            const SizedBox(height: 12),
            const Text(
              'Ruta del archivo',
              style: TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                file.path,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _BackupDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: Color(0xFF166534),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF166534))),
        ),
      ],
    );
  }
}

class _BackupRecommendationCard extends StatelessWidget {
  const _BackupRecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBEB),
      surfaceTintColor: Colors.transparent,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: Color(0xFFB45309)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Crea respaldos con frecuencia y copia los archivos '
                'a una memoria USB, disco externo o almacenamiento '
                'en la nube. Antes de restaurar, conserva siempre '
                'una copia adicional de tus archivos.',
                style: TextStyle(color: Color(0xFF78350F), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
