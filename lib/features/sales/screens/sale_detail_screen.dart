import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class SaleDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int saleId;

  const SaleDetailScreen({
    super.key,
    required this.database,
    required this.saleId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('Venta #$saleId'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<Sale?>(
        stream: database.watchSaleById(saleId),
        builder: (context, saleSnapshot) {
          if (saleSnapshot.connectionState == ConnectionState.waiting &&
              !saleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (saleSnapshot.hasError) {
            return _SaleDetailError(message: saleSnapshot.error.toString());
          }

          final sale = saleSnapshot.data;

          if (sale == null) {
            return const _SaleNotFound();
          }

          return StreamBuilder<List<SaleItemDetail>>(
            stream: database.watchSaleItemsWithProducts(saleId),
            builder: (context, itemsSnapshot) {
              if (itemsSnapshot.connectionState == ConnectionState.waiting &&
                  !itemsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (itemsSnapshot.hasError) {
                return _SaleDetailError(
                  message: itemsSnapshot.error.toString(),
                );
              }

              final items = itemsSnapshot.data ?? [];

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      _SaleHeaderCard(sale: sale, itemCount: items.length),
                      const SizedBox(height: 16),
                      _SaleInformationCard(sale: sale),
                      const SizedBox(height: 16),
                      _SaleTotalsCard(sale: sale),
                      const SizedBox(height: 16),
                      _SaleItemsCard(items: items),
                      if (sale.status == 'completed') ...[
                        const SizedBox(height: 16),
                        _CancelSaleCard(database: database, sale: sale),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SaleHeaderCard extends StatelessWidget {
  final Sale sale;
  final int itemCount;

  const _SaleHeaderCard({required this.sale, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final isCompleted = sale.status == 'completed';
    final customerName = sale.customerName?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            final saleIcon = Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFECFDF3)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCompleted
                    ? Icons.point_of_sale_outlined
                    : Icons.cancel_outlined,
                color: isCompleted
                    ? const Color(0xFF15803D)
                    : const Color(0xFFBE123C),
                size: 32,
              ),
            );

            final information = Column(
              crossAxisAlignment: isWide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'Venta #${sale.id}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  customerName?.isNotEmpty == true
                      ? customerName!
                      : 'Público general',
                  textAlign: isWide ? TextAlign.start : TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: isWide
                      ? WrapAlignment.start
                      : WrapAlignment.center,
                  children: [
                    _SaleStatusChip(status: sale.status),
                    _SaleInformationChip(
                      icon: Icons.inventory_2_outlined,
                      label:
                          '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
                    ),
                    _SaleInformationChip(
                      icon: _paymentMethodIcon(sale.paymentMethod),
                      label: _paymentMethodLabel(sale.paymentMethod),
                    ),
                  ],
                ),
              ],
            );

            final total = Column(
              crossAxisAlignment: isWide
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'Total',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCents(sale.totalCents),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isCompleted
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  saleIcon,
                  const SizedBox(width: 18),
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  total,
                ],
              );
            }

            return Column(
              children: [
                saleIcon,
                const SizedBox(height: 14),
                information,
                const SizedBox(height: 20),
                total,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SaleInformationCard extends StatelessWidget {
  final Sale sale;

  const _SaleInformationCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');

    final customerName = sale.customerName?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Información de la venta',
            ),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Cliente',
              value: customerName?.isNotEmpty == true
                  ? customerName!
                  : 'Público general',
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Fecha',
              value: dateFormatter.format(sale.createdAt.toLocal()),
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: Icons.tag_outlined,
              label: 'Folio interno',
              value: '#${sale.id}',
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: _paymentMethodIcon(sale.paymentMethod),
              label: 'Método de pago',
              value: _paymentMethodLabel(sale.paymentMethod),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleTotalsCard extends StatelessWidget {
  final Sale sale;

  const _SaleTotalsCard({required this.sale});

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
            const _SectionTitle(
              icon: Icons.calculate_outlined,
              title: 'Resumen de importes',
            ),
            const SizedBox(height: 18),
            _AmountRow(
              label: 'Subtotal',
              value: formatCents(sale.subtotalCents),
            ),
            const SizedBox(height: 12),
            _AmountRow(
              label: 'Descuento',
              value: '-${formatCents(sale.discountCents)}',
              valueColor: sale.discountCents > 0
                  ? const Color(0xFFB45309)
                  : null,
            ),
            const Divider(height: 28),
            _AmountRow(
              label: 'Total',
              value: formatCents(sale.totalCents),
              emphasize: true,
              valueColor: sale.status == 'completed'
                  ? const Color(0xFF15803D)
                  : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasize
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
                : Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: emphasize
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }
}

class _SaleItemsCard extends StatelessWidget {
  final List<SaleItemDetail> items;

  const _SaleItemsCard({required this.items});

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
            _SectionTitle(
              icon: Icons.inventory_2_outlined,
              title: 'Productos vendidos',
              trailing: Text(
                items.length.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFC2410C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const _EmptySaleItems()
            else
              ListView.separated(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _SaleItemDetailCard(detail: items[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleItemDetailCard extends StatelessWidget {
  final SaleItemDetail detail;

  const _SaleItemDetailCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final item = detail.saleItem;
    final product = detail.product;
    final sku = product.sku?.trim();

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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFC2410C),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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
                    _SaleInformationChip(
                      icon: Icons.numbers_outlined,
                      label: 'Cantidad: ${item.quantity}',
                    ),
                    _SaleInformationChip(
                      icon: Icons.sell_outlined,
                      label: 'Precio: ${formatCents(item.unitPriceCents)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Subtotal: ${formatCents(item.subtotalCents)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFC2410C),
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFFC2410C)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFC2410C).withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9A3412)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A3412),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySaleItems extends StatelessWidget {
  const _EmptySaleItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 52, color: Colors.blueGrey),
          SizedBox(height: 12),
          Text(
            'Esta venta no tiene productos registrados.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SaleNotFound extends StatelessWidget {
  const _SaleNotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 64, color: Colors.blueGrey),
            SizedBox(height: 14),
            Text('No se encontró la venta.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SaleDetailError extends StatelessWidget {
  final String message;

  const _SaleDetailError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              'No fue posible cargar la venta.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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

class _CancelSaleCard extends StatefulWidget {
  final AppDatabase database;
  final Sale sale;

  const _CancelSaleCard({required this.database, required this.sale});

  @override
  State<_CancelSaleCard> createState() => _CancelSaleCardState();
}

class _CancelSaleCardState extends State<_CancelSaleCard> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7F7),
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final information = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancelar esta venta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Los productos vendidos regresarán al inventario. '
                  'La venta y sus partidas se conservarán en el historial.',
                  style: TextStyle(color: Color(0xFF7F1D1D), height: 1.4),
                ),
              ],
            );

            final button = FilledButton.icon(
              onPressed: _isCancelling ? null : _confirmCancellation,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              icon: _isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(_isCancelling ? 'Cancelando...' : 'Cancelar venta'),
            );

            if (constraints.maxWidth >= 620) {
              return Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  button,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 38,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(height: 12),
                information,
                const SizedBox(height: 18),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB91C1C),
          ),
          title: Text('Cancelar venta #${widget.sale.id}'),
          content: const Text(
            'Esta acción devolverá al inventario todos los productos '
            'incluidos en la venta. La operación no podrá cancelarse '
            'por segunda vez.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Regresar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar cancelación'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      await widget.database.cancelSale(widget.sale.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venta #${widget.sale.id} cancelada correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCancelling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la venta: $error')),
      );
    }
  }
}
