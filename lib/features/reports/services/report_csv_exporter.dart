import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/local/app_database.dart';

class ReportCsvExporter {
  const ReportCsvExporter._();

  static Future<File> export({
    required BusinessReportSummary summary,
    required List<ProductSalesReport> products,
    required DateTime start,
    required DateTime end,
  }) async {
    final directory = await _resolveOutputDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final visibleEnd = end.subtract(const Duration(days: 1));

    final fileTimestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final startLabel = DateFormat('yyyyMMdd').format(start);

    final endLabel = DateFormat('yyyyMMdd').format(visibleEnd);

    final fileName = 'reporte_${startLabel}_${endLabel}_$fileTimestamp.csv';

    final file = File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '$fileName',
    );

    final buffer = StringBuffer();

    _writeRow(buffer, ['REPORTE DEL NEGOCIO']);

    _writeRow(buffer, [
      'Fecha inicial',
      DateFormat('dd/MM/yyyy').format(start),
    ]);

    _writeRow(buffer, [
      'Fecha final',
      DateFormat('dd/MM/yyyy').format(visibleEnd),
    ]);

    _writeRow(buffer, [
      'Generado',
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    ]);

    buffer.writeln();

    _writeRow(buffer, ['RESUMEN GENERAL']);

    _writeRow(buffer, ['Indicador', 'Valor']);

    _writeRow(buffer, ['Ventas completadas', summary.completedSalesCount]);

    _writeRow(buffer, ['Ventas canceladas', summary.cancelledSalesCount]);

    _writeRow(buffer, ['Unidades vendidas', summary.soldUnits]);

    _writeRow(buffer, ['Ventas netas', _moneyValue(summary.salesTotalCents)]);

    _writeRow(buffer, [
      'Descuentos aplicados',
      _moneyValue(summary.discountsCents),
    ]);

    _writeRow(buffer, [
      'Costo de productos vendidos',
      _moneyValue(summary.costOfGoodsSoldCents),
    ]);

    _writeRow(buffer, [
      'Utilidad bruta',
      _moneyValue(summary.grossProfitCents),
    ]);

    _writeRow(buffer, ['Gastos', _moneyValue(summary.expensesCents)]);

    _writeRow(buffer, ['Utilidad neta', _moneyValue(summary.netProfitCents)]);

    _writeRow(buffer, [
      'Ticket promedio',
      _moneyValue(summary.averageTicketCents),
    ]);

    _writeRow(buffer, [
      'Ventas sin costo histórico',
      summary.salesWithoutHistoricalCost,
    ]);

    buffer.writeln();

    _writeRow(buffer, ['PRODUCTOS MÁS VENDIDOS']);

    _writeRow(buffer, [
      'Posición',
      'Producto',
      'SKU',
      'Unidades vendidas',
      'Importe antes de descuento',
      'Costo histórico conocido',
      'Utilidad bruta conocida',
      'Costo histórico incompleto',
    ]);

    for (var index = 0; index < products.length; index++) {
      final product = products[index];

      _writeRow(buffer, [
        index + 1,
        product.productName,
        product.sku ?? '',
        product.quantitySold,
        _moneyValue(product.salesSubtotalCents),
        _moneyValue(product.knownCostCents),
        _moneyValue(product.knownGrossProfitCents),
        product.hasMissingHistoricalCost ? 'Sí' : 'No',
      ]);
    }

    if (products.isEmpty) {
      _writeRow(buffer, ['', 'No hubo productos vendidos en este periodo.']);
    }

    // El BOM permite que Excel reconozca correctamente
    // caracteres como á, é, í, ó, ú y ñ.
    final bytes = utf8.encode('\uFEFF${buffer.toString()}');

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  static Future<Directory> _resolveOutputDirectory() async {
    try {
      final downloadsDirectory = await getDownloadsDirectory();

      if (downloadsDirectory != null) {
        return downloadsDirectory;
      }
    } on UnsupportedError {
      // Algunas plataformas podrían no tener
      // una carpeta de descargas disponible.
    }

    return getApplicationDocumentsDirectory();
  }

  static void _writeRow(StringBuffer buffer, List<Object?> values) {
    final row = values.map(_escapeCsvValue).join(';');

    buffer.writeln(row);
  }

  static String _escapeCsvValue(Object? value) {
    final text = value?.toString() ?? '';

    final escapedText = text.replaceAll('"', '""');

    return '"$escapedText"';
  }

  static String _moneyValue(int cents) {
    return (cents / 100).toStringAsFixed(2);
  }
}
