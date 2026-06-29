import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int purchaseId;

  const PurchaseDetailScreen({
    super.key,
    required this.database,
    required this.purchaseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('Compra #$purchaseId'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<Purchase?>(
        stream: database.watchPurchaseById(purchaseId),
        builder: (context, purchaseSnapshot) {
          if (purchaseSnapshot.connectionState == ConnectionState.waiting &&
              !purchaseSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (purchaseSnapshot.hasError) {
            return _PurchaseDetailError(
              message: purchaseSnapshot.error.toString(),
            );
          }

          final purchase = purchaseSnapshot.data;

          if (purchase == null) {
            return const _PurchaseNotFound();
          }

          return StreamBuilder<List<PurchaseItemDetail>>(
            stream: database.watchPurchaseItemsWithProducts(purchaseId),
            builder: (context, itemsSnapshot) {
              if (itemsSnapshot.connectionState == ConnectionState.waiting &&
                  !itemsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (itemsSnapshot.hasError) {
                return _PurchaseDetailError(
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
                      _PurchaseHeaderCard(
                        purchase: purchase,
                        itemCount: items.length,
                      ),
                      const SizedBox(height: 16),
                      _PurchaseInformationCard(purchase: purchase),
                      const SizedBox(height: 16),
                      _PurchaseItemsCard(items: items),
                      if (purchase.status == 'completed') ...[
                        const SizedBox(height: 16),
                        _CancelPurchaseCard(
                          database: database,
                          purchase: purchase,
                        ),
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

class _PurchaseHeaderCard extends StatelessWidget {
  final Purchase purchase;
  final int itemCount;

  const _PurchaseHeaderCard({required this.purchase, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final isCompleted = purchase.status == 'completed';

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            final purchaseIcon = Container(
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
                    ? Icons.shopping_cart_checkout_outlined
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
                  'Compra #${purchase.id}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  purchase.supplierName?.trim().isNotEmpty == true
                      ? purchase.supplierName!
                      : 'Proveedor no disponible',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                  textAlign: isWide ? TextAlign.start : TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: isWide
                      ? WrapAlignment.start
                      : WrapAlignment.center,
                  children: [
                    _PurchaseStatusChip(status: purchase.status),
                    _PurchaseInformationChip(
                      icon: Icons.inventory_2_outlined,
                      label:
                          '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
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
                  formatCents(purchase.totalCents),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF15803D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  purchaseIcon,
                  const SizedBox(width: 18),
                  Expanded(child: information),
                  const SizedBox(width: 20),
                  total,
                ],
              );
            }

            return Column(
              children: [
                purchaseIcon,
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

class _PurchaseInformationCard extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseInformationCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');

    final note = purchase.note?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Información de la compra',
            ),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              label: 'Proveedor',
              value: purchase.supplierName?.trim().isNotEmpty == true
                  ? purchase.supplierName!
                  : 'No disponible',
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Fecha',
              value: dateFormatter.format(purchase.createdAt.toLocal()),
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: Icons.tag_outlined,
              label: 'Folio interno',
              value: '#${purchase.id}',
            ),
            const Divider(height: 26),
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Nota o referencia',
              value: note?.isNotEmpty == true ? note! : 'Sin notas',
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemsCard extends StatelessWidget {
  final List<PurchaseItemDetail> items;

  const _PurchaseItemsCard({required this.items});

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
              title: 'Productos comprados',
              trailing: Text(
                '${items.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF15803D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const _EmptyPurchaseItems()
            else
              ListView.separated(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _PurchaseItemDetailCard(detail: items[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemDetailCard extends StatelessWidget {
  final PurchaseItemDetail detail;

  const _PurchaseItemDetailCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final item = detail.purchaseItem;
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
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF15803D),
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
                    _PurchaseInformationChip(
                      icon: Icons.numbers_outlined,
                      label: 'Cantidad: ${item.quantity}',
                    ),
                    _PurchaseInformationChip(
                      icon: Icons.payments_outlined,
                      label: 'Costo: ${formatCents(item.unitCostCents)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Subtotal: ${formatCents(item.subtotalCents)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF15803D),
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
            color: const Color(0xFFECFDF3),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF15803D)),
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

class _PurchaseStatusChip extends StatelessWidget {
  final String status;

  const _PurchaseStatusChip({required this.status});

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

class _PurchaseInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PurchaseInformationChip({required this.icon, required this.label});

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

class _EmptyPurchaseItems extends StatelessWidget {
  const _EmptyPurchaseItems();

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
            'Esta compra no tiene productos registrados.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PurchaseNotFound extends StatelessWidget {
  const _PurchaseNotFound();

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
            Text('No se encontró la compra.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDetailError extends StatelessWidget {
  final String message;

  const _PurchaseDetailError({required this.message});

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
              'No fue posible cargar la compra.',
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

class _CancelPurchaseCard extends StatefulWidget {
  final AppDatabase database;
  final Purchase purchase;

  const _CancelPurchaseCard({required this.database, required this.purchase});

  @override
  State<_CancelPurchaseCard> createState() => _CancelPurchaseCardState();
}

class _CancelPurchaseCardState extends State<_CancelPurchaseCard> {
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
                  'Cancelar esta compra',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'La cancelación descontará del inventario '
                  'todos los productos recibidos en esta compra. '
                  'La compra y sus partidas conservarán su historial.',
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
              label: Text(_isCancelling ? 'Cancelando...' : 'Cancelar compra'),
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
          title: Text('Cancelar compra #${widget.purchase.id}'),
          content: const Text(
            'Esta acción revertirá la entrada de inventario. '
            'No se podrá cancelar si alguno de los productos '
            'ya no tiene suficiente stock disponible.',
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
      await widget.database.cancelPurchase(widget.purchase.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Compra #${widget.purchase.id} cancelada correctamente.',
          ),
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
        SnackBar(content: Text('No se pudo cancelar la compra: $error')),
      );
    }
  }
}
