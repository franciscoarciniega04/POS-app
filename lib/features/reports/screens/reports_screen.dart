import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import '../services/report_csv_exporter.dart';
import '../services/report_pdf_exporter.dart';

enum _ReportPeriod { today, thisWeek, thisMonth, thisYear, custom }

class ReportsScreen extends StatefulWidget {
  final AppDatabase database;

  const ReportsScreen({super.key, required this.database});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPeriod _selectedPeriod = _ReportPeriod.thisMonth;

  late DateTime _start;
  late DateTime _end;

  DateTimeRange? _customRange;

  late Stream<BusinessReportSummary> _summaryStream;
  late Stream<List<ProductSalesReport>> _productsStream;

  bool _isExporting = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();

    _applyPresetPeriod(_ReportPeriod.thisMonth, updateState: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _ReportPeriodFilters(
                selectedPeriod: _selectedPeriod,
                onSelected: _selectPeriod,
              ),
              _SelectedPeriodCard(start: _start, end: _end),
              Expanded(
                child: StreamBuilder<BusinessReportSummary>(
                  stream: _summaryStream,
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !summarySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (summarySnapshot.hasError) {
                      return _ReportsErrorState(
                        message: summarySnapshot.error.toString(),
                      );
                    }

                    final summary = summarySnapshot.data;

                    if (summary == null) {
                      return const _ReportsErrorState(
                        message: 'No se pudo calcular el resumen del periodo.',
                      );
                    }

                    return StreamBuilder<List<ProductSalesReport>>(
                      stream: _productsStream,
                      builder: (context, productsSnapshot) {
                        if (productsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !productsSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (productsSnapshot.hasError) {
                          return _ReportsErrorState(
                            message: productsSnapshot.error.toString(),
                          );
                        }

                        final products =
                            productsSnapshot.data ??
                            const <ProductSalesReport>[];

                        return _ReportsContent(
                          summary: summary,
                          products: products,
                          start: _start,
                          end: _end,
                          isExporting: _isExporting,
                          isExportingPdf: _isExportingPdf,
                          onExport: () {
                            _exportReport(summary: summary, products: products);
                          },
                          onExportPdf: () {
                            _exportPdfReport(
                              summary: summary,
                              products: products,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPeriod(_ReportPeriod period) async {
    if (period == _ReportPeriod.custom) {
      await _selectCustomPeriod();
      return;
    }

    _applyPresetPeriod(period);
  }

  void _applyPresetPeriod(_ReportPeriod period, {bool updateState = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late DateTime start;
    late DateTime end;

    switch (period) {
      case _ReportPeriod.today:
        start = today;
        end = today.add(const Duration(days: 1));

      case _ReportPeriod.thisWeek:
        start = today.subtract(Duration(days: today.weekday - DateTime.monday));

        end = start.add(const Duration(days: 7));

      case _ReportPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);

        end = DateTime(now.year, now.month + 1, 1);

      case _ReportPeriod.thisYear:
        start = DateTime(now.year, 1, 1);

        end = DateTime(now.year + 1, 1, 1);

      case _ReportPeriod.custom:
        return;
    }

    void applyChanges() {
      _selectedPeriod = period;
      _start = start;
      _end = end;
      _refreshStreams();
    }

    if (updateState) {
      setState(applyChanges);
    } else {
      applyChanges();
    }
  }

  Future<void> _selectCustomPeriod() async {
    final now = DateTime.now();

    final currentVisibleEnd = _end.subtract(const Duration(days: 1));

    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _customRange ?? DateTimeRange(start: _start, end: currentVisibleEnd),
      helpText: 'Selecciona el periodo del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
      fieldStartLabelText: 'Fecha inicial',
      fieldEndLabelText: 'Fecha final',
      errorFormatText: 'Fecha no válida',
      errorInvalidText: 'El rango no es válido',
      errorInvalidRangeText: 'La fecha final debe ser posterior a la inicial',
    );

    if (selectedRange == null || !mounted) {
      return;
    }

    final normalizedStart = DateTime(
      selectedRange.start.year,
      selectedRange.start.month,
      selectedRange.start.day,
    );

    final normalizedVisibleEnd = DateTime(
      selectedRange.end.year,
      selectedRange.end.month,
      selectedRange.end.day,
    );

    final exclusiveEnd = normalizedVisibleEnd.add(const Duration(days: 1));

    setState(() {
      _selectedPeriod = _ReportPeriod.custom;

      _customRange = DateTimeRange(
        start: normalizedStart,
        end: normalizedVisibleEnd,
      );

      _start = normalizedStart;
      _end = exclusiveEnd;

      _refreshStreams();
    });
  }

  void _refreshStreams() {
    _summaryStream = widget.database.watchBusinessReportSummary(
      start: _start,
      end: _end,
    );

    _productsStream = widget.database.watchProductSalesReport(
      start: _start,
      end: _end,
    );
  }

  Future<void> _exportReport({
    required BusinessReportSummary summary,
    required List<ProductSalesReport> products,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final file = await ReportCsvExporter.export(
        summary: summary,
        products: products,
        start: _start,
        end: _end,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isExporting = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF15803D),
              size: 38,
            ),
            title: const Text('Reporte exportado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('El archivo CSV se guardó correctamente en:'),
                const SizedBox(height: 12),
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
        _isExporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el reporte: $error')),
      );
    }
  }

  Future<void> _exportPdfReport({
    required BusinessReportSummary summary,
    required List<ProductSalesReport> products,
  }) async {
    if (_isExportingPdf) {
      return;
    }

    setState(() {
      _isExportingPdf = true;
    });

    try {
      final file = await ReportPdfExporter.export(
        summary: summary,
        products: products,
        start: _start,
        end: _end,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isExportingPdf = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFBE123C),
              size: 38,
            ),
            title: const Text('PDF exportado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('El reporte se guardó correctamente en:'),
                const SizedBox(height: 12),
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
        _isExportingPdf = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el PDF: $error')),
      );
    }
  }
}

class _ReportPeriodFilters extends StatelessWidget {
  final _ReportPeriod selectedPeriod;
  final ValueChanged<_ReportPeriod> onSelected;

  const _ReportPeriodFilters({
    required this.selectedPeriod,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Hoy'),
              selected: selectedPeriod == _ReportPeriod.today,
              onSelected: (_) {
                onSelected(_ReportPeriod.today);
              },
            ),
            ChoiceChip(
              label: const Text('Esta semana'),
              selected: selectedPeriod == _ReportPeriod.thisWeek,
              onSelected: (_) {
                onSelected(_ReportPeriod.thisWeek);
              },
            ),
            ChoiceChip(
              label: const Text('Este mes'),
              selected: selectedPeriod == _ReportPeriod.thisMonth,
              onSelected: (_) {
                onSelected(_ReportPeriod.thisMonth);
              },
            ),
            ChoiceChip(
              label: const Text('Este año'),
              selected: selectedPeriod == _ReportPeriod.thisYear,
              onSelected: (_) {
                onSelected(_ReportPeriod.thisYear);
              },
            ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('Personalizado'),
              selected: selectedPeriod == _ReportPeriod.custom,
              onSelected: (_) {
                onSelected(_ReportPeriod.custom);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPeriodCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const _SelectedPeriodCard({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    final visibleEnd = end.subtract(const Duration(days: 1));

    final sameDay = DateUtils.isSameDay(start, visibleEnd);

    final label = sameDay
        ? formatter.format(start)
        : '${formatter.format(start)} al '
              '${formatter.format(visibleEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Periodo analizado: $label',
                style: const TextStyle(
                  color: Color(0xFF1E40AF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsContent extends StatelessWidget {
  final BusinessReportSummary summary;
  final List<ProductSalesReport> products;
  final DateTime start;
  final DateTime end;
  final bool isExporting;
  final bool isExportingPdf;
  final VoidCallback onExport;
  final VoidCallback onExportPdf;

  const _ReportsContent({
    required this.summary,
    required this.products,
    required this.start,
    required this.end,
    required this.isExporting,
    required this.isExportingPdf,
    required this.onExport,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _ReportSummaryGrid(summary: summary),
        const SizedBox(height: 16),
        _ReportExportCard(
          start: start,
          end: end,
          isExporting: isExporting,
          isExportingPdf: isExportingPdf,
          onExport: onExport,
          onExportPdf: onExportPdf,
        ),
        const SizedBox(height: 16),
        _SalesActivityCard(summary: summary),
        if (summary.hasIncompleteHistoricalCosts) ...[
          const SizedBox(height: 16),
          _IncompleteCostsWarning(
            salesCount: summary.salesWithoutHistoricalCost,
          ),
        ],
        const SizedBox(height: 16),
        _ProductsReportCard(products: products),
      ],
    );
  }
}

class _ReportSummaryGrid extends StatelessWidget {
  final BusinessReportSummary summary;

  const _ReportSummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final netProfitIsPositive = summary.netProfitCents >= 0;

    final cards = [
      _ReportSummaryCard(
        title: 'Ventas netas',
        value: formatCents(summary.salesTotalCents),
        subtitle: '${summary.completedSalesCount} ventas completadas',
        icon: Icons.point_of_sale_outlined,
        foregroundColor: const Color(0xFF1D4ED8),
        backgroundColor: const Color(0xFFEFF6FF),
      ),
      _ReportSummaryCard(
        title: 'Costo vendido',
        value: formatCents(summary.costOfGoodsSoldCents),
        subtitle: 'Costo histórico conocido',
        icon: Icons.inventory_2_outlined,
        foregroundColor: const Color(0xFFC2410C),
        backgroundColor: const Color(0xFFFFF7ED),
      ),
      _ReportSummaryCard(
        title: 'Utilidad bruta',
        value: formatCents(summary.grossProfitCents),
        subtitle: 'Ventas menos costo vendido',
        icon: Icons.trending_up_outlined,
        foregroundColor: const Color(0xFF15803D),
        backgroundColor: const Color(0xFFECFDF3),
      ),
      _ReportSummaryCard(
        title: 'Gastos',
        value: formatCents(summary.expensesCents),
        subtitle: 'Egresos registrados en Gastos',
        icon: Icons.receipt_long_outlined,
        foregroundColor: const Color(0xFFBE123C),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
      _ReportSummaryCard(
        title: 'Utilidad neta',
        value: formatCents(summary.netProfitCents),
        subtitle: 'Utilidad bruta menos gastos',
        icon: netProfitIsPositive
            ? Icons.account_balance_wallet_outlined
            : Icons.trending_down_outlined,
        foregroundColor: netProfitIsPositive
            ? const Color(0xFF15803D)
            : const Color(0xFFBE123C),
        backgroundColor: netProfitIsPositive
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFFF1F2),
      ),
      _ReportSummaryCard(
        title: 'Ticket promedio',
        value: formatCents(summary.averageTicketCents),
        subtitle: 'Promedio por venta completada',
        icon: Icons.calculate_outlined,
        foregroundColor: const Color(0xFF7C3AED),
        backgroundColor: const Color(0xFFF5F3FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = switch (constraints.maxWidth) {
          >= 1000 => 3,
          >= 620 => 2,
          _ => 1,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, index) {
            return cards[index];
          },
        );
      },
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ReportSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: foregroundColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportExportCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final bool isExporting;
  final bool isExportingPdf;
  final VoidCallback onExport;
  final VoidCallback onExportPdf;

  const _ReportExportCard({
    required this.start,
    required this.end,
    required this.isExporting,
    required this.isExportingPdf,
    required this.onExport,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    final visibleEnd = end.subtract(const Duration(days: 1));

    final periodLabel = DateUtils.isSameDay(start, visibleEnd)
        ? formatter.format(start)
        : '${formatter.format(start)} al '
              '${formatter.format(visibleEnd)}';

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final information = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.download_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exportar reporte',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Genera archivos CSV y PDF del periodo '
                        '$periodLabel.',
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

            final csvButton = FilledButton.icon(
              onPressed: isExporting ? null : onExport,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.table_view_outlined),
              label: Text(isExporting ? 'Exportando CSV...' : 'Exportar CSV'),
            );

            final pdfButton = FilledButton.icon(
              onPressed: isExportingPdf ? null : onExportPdf,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
              ),
              icon: isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                isExportingPdf ? 'Exportando PDF...' : 'Exportar PDF',
              ),
            );

            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [csvButton, const SizedBox(width: 10), pdfButton],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                const SizedBox(height: 18),
                csvButton,
                const SizedBox(height: 10),
                pdfButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalesActivityCard extends StatelessWidget {
  final BusinessReportSummary summary;

  const _SalesActivityCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityItem(
        label: 'Ventas completadas',
        value: summary.completedSalesCount.toString(),
        icon: Icons.check_circle_outline,
        foregroundColor: const Color(0xFF15803D),
        backgroundColor: const Color(0xFFECFDF3),
      ),
      _ActivityItem(
        label: 'Ventas canceladas',
        value: summary.cancelledSalesCount.toString(),
        icon: Icons.cancel_outlined,
        foregroundColor: const Color(0xFFBE123C),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
      _ActivityItem(
        label: 'Unidades vendidas',
        value: summary.soldUnits.toString(),
        icon: Icons.shopping_bag_outlined,
        foregroundColor: const Color(0xFF1D4ED8),
        backgroundColor: const Color(0xFFEFF6FF),
      ),
      _ActivityItem(
        label: 'Descuentos aplicados',
        value: formatCents(summary.discountsCents),
        icon: Icons.discount_outlined,
        foregroundColor: const Color(0xFFB45309),
        backgroundColor: const Color(0xFFFFFBEB),
      ),
    ];

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReportSectionTitle(
              icon: Icons.analytics_outlined,
              title: 'Actividad del periodo',
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 850) {
                  return Row(
                    children: [
                      Expanded(child: items[0]),
                      const SizedBox(width: 12),
                      Expanded(child: items[1]),
                      const SizedBox(width: 12),
                      Expanded(child: items[2]),
                      const SizedBox(width: 12),
                      Expanded(child: items[3]),
                    ],
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      items[index],
                      if (index < items.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ActivityItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteCostsWarning extends StatelessWidget {
  final int salesCount;

  const _IncompleteCostsWarning({required this.salesCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBEB),
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 30,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información histórica incompleta',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$salesCount '
                    '${salesCount == 1 ? 'venta anterior no tiene' : 'ventas anteriores no tienen'} '
                    'costo histórico. La utilidad bruta y neta del periodo '
                    'puede aparecer más alta de lo real.',
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsReportCard extends StatelessWidget {
  final List<ProductSalesReport> products;

  const _ProductsReportCard({required this.products});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReportSectionTitle(
              icon: Icons.emoji_events_outlined,
              title: 'Productos más vendidos',
            ),
            const SizedBox(height: 7),
            Text(
              'Los importes por producto se muestran antes del descuento general de la venta.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            if (products.isEmpty)
              const _EmptyProductReport()
            else
              ListView.separated(
                itemCount: products.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _ProductReportRow(
                    report: products[index],
                    position: index + 1,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductReportRow extends StatelessWidget {
  final ProductSalesReport report;
  final int position;

  const _ProductReportRow({required this.report, required this.position});

  @override
  Widget build(BuildContext context) {
    final sku = report.sku?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: position <= 3
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '#$position',
              style: TextStyle(
                color: position <= 3
                    ? const Color(0xFFB45309)
                    : const Color(0xFF1D4ED8),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (sku?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    'SKU: $sku',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProductReportChip(
                      icon: Icons.shopping_bag_outlined,
                      label: '${report.quantitySold} unidades',
                    ),
                    _ProductReportChip(
                      icon: Icons.payments_outlined,
                      label:
                          'Importe: ${formatCents(report.salesSubtotalCents)}',
                    ),
                    _ProductReportChip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Costo: ${formatCents(report.knownCostCents)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Utilidad bruta conocida: '
                  '${formatCents(report.knownGrossProfitCents)}',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (report.hasMissingHistoricalCost) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Este producto tiene ventas sin costo histórico.',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductReportChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProductReportChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E40AF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ReportSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _EmptyProductReport extends StatelessWidget {
  const _EmptyProductReport();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.bar_chart_outlined,
            size: 55,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 13),
          Text(
            'No hay ventas completadas en este periodo.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  final String message;

  const _ReportsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'No fue posible generar el reporte',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
