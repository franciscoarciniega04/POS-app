import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/local/app_database.dart';

class ReportPdfExporter {
  const ReportPdfExporter._();

  static Future<File> export({
    required BusinessReportSummary summary,
    required List<ProductSalesReport> products,
    required DateTime start,
    required DateTime end,
  }) async {
    final document = pw.Document();

    final visibleEnd = end.subtract(const Duration(days: 1));

    final dateFormatter = DateFormat('dd/MM/yyyy');
    final dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

    final periodLabel = DateUtilsHelper.isSameDay(start, visibleEnd)
        ? dateFormatter.format(start)
        : '${dateFormatter.format(start)} al '
              '${dateFormatter.format(visibleEnd)}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'POS Offline',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.Text(
                  'Reporte del negocio',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generado: ${dateTimeFormatter.format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de '
                  '${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              'Reporte del negocio',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Periodo: $periodLabel',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 22),
            _sectionTitle('Resumen financiero'),
            pw.SizedBox(height: 10),
            _summaryTable(summary),
            if (summary.hasIncompleteHistoricalCosts) ...[
              pw.SizedBox(height: 14),
              _historicalCostWarning(summary.salesWithoutHistoricalCost),
            ],
            pw.SizedBox(height: 22),
            _sectionTitle('Actividad del periodo'),
            pw.SizedBox(height: 10),
            _activityTable(summary),
            pw.SizedBox(height: 22),
            _sectionTitle('Productos más vendidos'),
            pw.SizedBox(height: 5),
            pw.Text(
              'Los importes por producto se muestran antes '
              'del descuento general de la venta.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            if (products.isEmpty)
              _emptyProducts()
            else
              _productsTable(products),
          ];
        },
      ),
    );

    final directory = await _resolveOutputDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final startLabel = DateFormat('yyyyMMdd').format(start);

    final endLabel = DateFormat('yyyyMMdd').format(visibleEnd);

    final fileName = 'reporte_${startLabel}_${endLabel}_$timestamp.pdf';

    final file = File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '$fileName',
    );

    await file.writeAsBytes(await document.save(), flush: true);

    return file;
  }

  static pw.Widget _summaryTable(BusinessReportSummary summary) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
      children: [
        _tableHeaderRow(['Indicador', 'Importe']),
        _summaryRow('Ventas netas', _money(summary.salesTotalCents)),
        _summaryRow(
          'Costo de productos vendidos',
          _money(summary.costOfGoodsSoldCents),
        ),
        _summaryRow('Utilidad bruta', _money(summary.grossProfitCents)),
        _summaryRow('Gastos', _money(summary.expensesCents)),
        _summaryRow(
          'Utilidad neta',
          _money(summary.netProfitCents),
          emphasize: true,
        ),
        _summaryRow('Ticket promedio', _money(summary.averageTicketCents)),
      ],
    );
  }

  static pw.Widget _activityTable(BusinessReportSummary summary) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
      children: [
        _tableHeaderRow(['Indicador', 'Valor']),
        _summaryRow(
          'Ventas completadas',
          summary.completedSalesCount.toString(),
        ),
        _summaryRow(
          'Ventas canceladas',
          summary.cancelledSalesCount.toString(),
        ),
        _summaryRow('Unidades vendidas', summary.soldUnits.toString()),
        _summaryRow('Descuentos aplicados', _money(summary.discountsCents)),
      ],
    );
  }

  static pw.Widget _productsTable(List<ProductSalesReport> products) {
    final rows = <List<String>>[];

    for (var index = 0; index < products.length; index++) {
      final product = products[index];

      rows.add([
        '${index + 1}',
        product.productName,
        product.sku ?? '',
        product.quantitySold.toString(),
        _money(product.salesSubtotalCents),
        _money(product.knownCostCents),
        _money(product.knownGrossProfitCents),
        product.hasMissingHistoricalCost ? 'Incompleto' : 'Completo',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: const [
        '#',
        'Producto',
        'SKU',
        'Unidades',
        'Importe',
        'Costo',
        'Utilidad',
        'Costo histórico',
      ],
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.all(5),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.TableRow _tableHeaderRow(List<String> values) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      children: values.map((value) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.TableRow _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return pw.TableRow(
      decoration: emphasize
          ? const pw.BoxDecoration(color: PdfColors.green50)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: emphasize ? PdfColors.green800 : PdfColors.blueGrey900,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _historicalCostWarning(int salesCount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber400, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        '$salesCount '
        '${salesCount == 1 ? 'venta no tiene' : 'ventas no tienen'} '
        'costo histórico. La utilidad puede aparecer '
        'más alta de lo real.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.brown800),
      ),
    );
  }

  static pw.Widget _emptyProducts() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        'No hubo productos vendidos en este periodo.',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey900,
      ),
    );
  }

  static String _money(int cents) {
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    ).format(cents / 100);
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

class DateUtilsHelper {
  const DateUtilsHelper._();

  static bool isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
