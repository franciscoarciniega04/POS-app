import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'sale_form_screen.dart';
import 'sale_detail_screen.dart';

enum _SaleFilter { all, completed, cancelled }

class SalesScreen extends StatefulWidget {
  final AppDatabase database;

  const SalesScreen({super.key, required this.database});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final Stream<List<Sale>> _salesStream;

  String _searchText = '';
  _SaleFilter _selectedFilter = _SaleFilter.all;

  @override
  void initState() {
    super.initState();

    _salesStream = widget.database.watchAllSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Ventas'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSale,
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('Nueva venta'),
      ),
      body: StreamBuilder<List<Sale>>(
        stream: _salesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _SalesErrorState(message: snapshot.error.toString());
          }

          final sales = snapshot.data ?? [];

          final filteredSales = sales
              .where(_matchesSelectedFilter)
              .where(_matchesSearch)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  _SalesSummary(sales: sales),
                  _SalesFilters(
                    selectedFilter: _selectedFilter,
                    onChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                  _SalesSearchBox(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: _buildContent(
                      allSales: sales,
                      filteredSales: filteredSales,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required List<Sale> allSales,
    required List<Sale> filteredSales,
  }) {
    if (allSales.isEmpty) {
      return _EmptySalesState(onCreateSale: _openNewSale);
    }

    if (filteredSales.isEmpty) {
      return const _NoSalesFoundState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredSales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sale = filteredSales[index];

        return _SaleCard(sale: sale, onTap: () => _openSaleDetail(sale));
      },
    );
  }

  bool _matchesSelectedFilter(Sale sale) {
    switch (_selectedFilter) {
      case _SaleFilter.all:
        return true;

      case _SaleFilter.completed:
        return sale.status == 'completed';

      case _SaleFilter.cancelled:
        return sale.status == 'cancelled';
    }
  }

  bool _matchesSearch(Sale sale) {
    if (_searchText.isEmpty) {
      return true;
    }

    final customerName = sale.customerName ?? '';
    final paymentMethod = _paymentMethodLabel(sale.paymentMethod);

    final searchableValues = [
      sale.id.toString(),
      '#${sale.id}',
      customerName,
      sale.status,
      paymentMethod,
    ];

    return searchableValues.any(
      (value) => value.toLowerCase().contains(_searchText),
    );
  }

  Future<void> _openNewSale() async {
    final saleId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => SaleFormScreen(database: widget.database),
      ),
    );

    if (saleId == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Venta #$saleId registrada correctamente.')),
    );
  }

  void _openSaleDetail(Sale sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SaleDetailScreen(database: widget.database, saleId: sale.id),
      ),
    );
  }
}

class _SalesSummary extends StatelessWidget {
  final List<Sale> sales;

  const _SalesSummary({required this.sales});

  @override
  Widget build(BuildContext context) {
    final completedSales = sales.where((sale) => sale.status == 'completed');

    final completedCount = completedSales.length;

    final cancelledCount = sales
        .where((sale) => sale.status == 'cancelled')
        .length;

    final totalSoldCents = completedSales.fold<int>(
      0,
      (total, sale) => total + sale.totalCents,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            _SaleSummaryCard(
              title: 'Total vendido',
              value: formatCents(totalSoldCents),
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF15803D),
              backgroundColor: const Color(0xFFECFDF3),
            ),
            _SaleSummaryCard(
              title: 'Ventas completadas',
              value: completedCount.toString(),
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF1D4ED8),
              backgroundColor: const Color(0xFFEFF6FF),
            ),
            _SaleSummaryCard(
              title: 'Ventas canceladas',
              value: cancelledCount.toString(),
              icon: Icons.cancel_outlined,
              iconColor: const Color(0xFFBE123C),
              backgroundColor: const Color(0xFFFFF1F2),
            ),
          ];

          if (constraints.maxWidth >= 850) {
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ],
            );
          }

          return Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              cards[1],
              const SizedBox(height: 12),
              cards[2],
            ],
          );
        },
      ),
    );
  }
}

class _SaleSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _SaleSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
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

class _SalesFilters extends StatelessWidget {
  final _SaleFilter selectedFilter;
  final ValueChanged<_SaleFilter> onChanged;

  const _SalesFilters({required this.selectedFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: selectedFilter == _SaleFilter.all,
              onSelected: (_) {
                onChanged(_SaleFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Completadas'),
              selected: selectedFilter == _SaleFilter.completed,
              onSelected: (_) {
                onChanged(_SaleFilter.completed);
              },
            ),
            ChoiceChip(
              label: const Text('Canceladas'),
              selected: selectedFilter == _SaleFilter.cancelled,
              onSelected: (_) {
                onChanged(_SaleFilter.cancelled);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesSearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SalesSearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por folio, cliente o método de pago',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const _SaleCard({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');

    final customerName = sale.customerName?.trim();

    final isCompleted = sale.status == 'completed';

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.point_of_sale_outlined
                      : Icons.cancel_outlined,
                  color: isCompleted
                      ? const Color(0xFF15803D)
                      : const Color(0xFFBE123C),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Venta #${sale.id}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        _SaleStatusChip(status: sale.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName?.isNotEmpty == true
                          ? customerName!
                          : 'Público general',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SaleInformationChip(
                          icon: _paymentMethodIcon(sale.paymentMethod),
                          label: _paymentMethodLabel(sale.paymentMethod),
                        ),
                        _SaleInformationChip(
                          icon: Icons.calendar_today_outlined,
                          label: dateFormatter.format(sale.createdAt.toLocal()),
                        ),
                      ],
                    ),
                    if (sale.discountCents > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Descuento: ${formatCents(sale.discountCents)}',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${formatCents(sale.totalCents)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isCompleted
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleStatusChip extends StatelessWidget {
  final String status;

  const _SaleStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFECFDF3) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCompleted ? 'Completada' : 'Cancelada',
        style: TextStyle(
          color: isCompleted
              ? const Color(0xFF15803D)
              : const Color(0xFFBE123C),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SaleInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SaleInformationChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF1E4E79).withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1E4E79)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E4E79),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySalesState extends StatelessWidget {
  final VoidCallback onCreateSale;

  const _EmptySalesState({required this.onCreateSale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_outlined,
                size: 48,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes ventas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tu primera venta para descontar productos del inventario.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateSale,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Registrar venta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSalesFoundState extends StatelessWidget {
  const _NoSalesFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 70,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              'No encontramos ventas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otra búsqueda o cambia el filtro.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesErrorState extends StatelessWidget {
  final String message;

  const _SalesErrorState({required this.message});

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
              'No fue posible cargar las ventas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _paymentMethodLabel(String paymentMethod) {
  switch (paymentMethod) {
    case 'cash':
      return 'Efectivo';

    case 'card':
      return 'Tarjeta';

    case 'transfer':
      return 'Transferencia';

    case 'mixed':
      return 'Pago mixto';

    default:
      return paymentMethod;
  }
}

IconData _paymentMethodIcon(String paymentMethod) {
  switch (paymentMethod) {
    case 'cash':
      return Icons.payments_outlined;

    case 'card':
      return Icons.credit_card_outlined;

    case 'transfer':
      return Icons.account_balance_outlined;

    case 'mixed':
      return Icons.call_split_outlined;

    default:
      return Icons.payment_outlined;
  }
}
