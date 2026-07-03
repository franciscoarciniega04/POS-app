import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../customers/screens/customer_detail_screen.dart';
import 'order_form_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.database,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerOrderWithCustomer?>(
      stream: database.watchCustomerOrderById(orderId),
      builder: (context, orderSnapshot) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: Text('Pedido #$orderId'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: _buildBody(context, orderSnapshot),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<CustomerOrderWithCustomer?> orderSnapshot,
  ) {
    if (orderSnapshot.connectionState == ConnectionState.waiting &&
        !orderSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orderSnapshot.hasError) {
      return _ErrorState(
        message: 'No se pudo cargar el pedido: ${orderSnapshot.error}',
      );
    }

    final orderData = orderSnapshot.data;

    if (orderData == null) {
      return const _ErrorState(message: 'El pedido ya no existe.');
    }

    return StreamBuilder<List<CustomerOrderItemDetail>>(
      stream: database.watchCustomerOrderItems(orderId),
      builder: (context, itemSnapshot) {
        if (itemSnapshot.connectionState == ConnectionState.waiting &&
            !itemSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (itemSnapshot.hasError) {
          return _ErrorState(
            message:
                'No se pudieron cargar los productos: ${itemSnapshot.error}',
          );
        }

        final items = itemSnapshot.data ?? const <CustomerOrderItemDetail>[];

        return _OrderDetailContent(
          database: database,
          orderData: orderData,
          items: items,
        );
      },
    );
  }
}

class _OrderDetailContent extends StatelessWidget {
  final AppDatabase database;
  final CustomerOrderWithCustomer orderData;
  final List<CustomerOrderItemDetail> items;

  const _OrderDetailContent({
    required this.database,
    required this.orderData,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final order = orderData.order;
    final customer = orderData.customer;
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    final requestedUnits = items.fold<int>(
      0,
      (total, item) => total + item.orderItem.quantityRequested,
    );

    final fulfilledUnits = items.fold<int>(
      0,
      (total, item) => total + item.orderItem.quantityFulfilled,
    );

    final pendingUnits = items.fold<int>(
      0,
      (total, item) => total + item.pendingQuantity,
    );

    final canCancel =
        order.status == CustomerOrderStatus.pending ||
        order.status == CustomerOrderStatus.partiallyFulfilled;

    final canEdit =
        order.status == CustomerOrderStatus.pending ||
        order.status == CustomerOrderStatus.partiallyFulfilled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: _statusBackground(order.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _statusIcon(order.status),
                            color: _statusForeground(order.status),
                            size: 31,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pedido #${order.id}',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 7),
                              _StatusBadge(status: order.status),
                              const SizedBox(height: 8),
                              Text(
                                'Registrado: ${dateFormatter.format(order.createdAt)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (canEdit || canCancel) ...[
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final editButton = FilledButton.icon(
                            onPressed: canEdit
                                ? () {
                                    _editOrder(context);
                                  }
                                : null,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar pedido'),
                          );

                          final cancelButton = OutlinedButton.icon(
                            onPressed: canCancel
                                ? () {
                                    _cancelOrder(context, order);
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFBE123C),
                              side: const BorderSide(color: Color(0xFFBE123C)),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancelar pedido'),
                          );

                          if (constraints.maxWidth >= 560) {
                            return Row(
                              children: [
                                Expanded(child: editButton),
                                const SizedBox(width: 12),
                                Expanded(child: cancelButton),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              editButton,
                              const SizedBox(height: 10),
                              cancelButton,
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CustomerCard(
              customer: customer,
              onOpen: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(
                      database: database,
                      customerId: customer.id,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _SummaryCard(
                    title: 'Solicitadas',
                    value: '$requestedUnits',
                    icon: Icons.shopping_basket_outlined,
                    foreground: const Color(0xFF1D4ED8),
                    background: const Color(0xFFEFF6FF),
                  ),
                  _SummaryCard(
                    title: 'Surtidas',
                    value: '$fulfilledUnits',
                    icon: Icons.check_circle_outline,
                    foreground: const Color(0xFF15803D),
                    background: const Color(0xFFECFDF3),
                  ),
                  _SummaryCard(
                    title: 'Pendientes',
                    value: '$pendingUnits',
                    icon: Icons.hourglass_bottom_outlined,
                    foreground: const Color(0xFFB45309),
                    background: const Color(0xFFFFFBEB),
                  ),
                ];

                if (constraints.maxWidth >= 700) {
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
                    const SizedBox(height: 10),
                    cards[1],
                    const SizedBox(height: 10),
                    cards[2],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas generales',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _displayValue(order.notes),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos del pedido',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      const Text('El pedido no contiene productos.')
                    else
                      ...List.generate(items.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == items.length - 1 ? 0 : 12,
                          ),
                          child: _OrderItemCard(
                            detail: items[index],
                            position: index + 1,
                            isCancelled:
                                order.status == CustomerOrderStatus.cancelled,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Este pedido todavía no modifica el inventario. En el siguiente módulo podrás marcar los productos conseguidos y convertirlos en una compra.',
                      style: TextStyle(color: Color(0xFF1E40AF), height: 1.4),
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

  Future<void> _editOrder(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(
          database: database,
          orderToEdit: orderData,
          initialItems: items,
        ),
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context, CustomerOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB45309),
            size: 42,
          ),
          title: const Text('Cancelar pedido'),
          content: const Text(
            'El pedido se conservará en el historial, pero sus productos dejarán de aparecer como pendientes de surtir.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar pedido'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await database.cancelCustomerOrder(order.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido cancelado.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar el pedido: $error')),
      );
    }
  }

  String _displayValue(String? value) {
    final cleanValue = value?.trim();

    if (cleanValue == null || cleanValue.isEmpty) {
      return 'Sin notas';
    }

    return cleanValue;
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onOpen;

  const _CustomerCard({required this.customer, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.person_outline, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone == null || phone.isEmpty
                          ? 'Sin teléfono registrado'
                          : phone,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.foreground,
    required this.background,
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: foreground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 22,
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

class _OrderItemCard extends StatelessWidget {
  final CustomerOrderItemDetail detail;
  final int position;
  final bool isCancelled;

  const _OrderItemCard({
    required this.detail,
    required this.position,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final item = detail.orderItem;
    final sku = detail.product.sku?.trim();
    final requested = item.quantityRequested;
    final fulfilled = item.quantityFulfilled;
    final progress = requested <= 0 ? 0.0 : fulfilled / requested;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (sku != null && sku.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'SKU: $sku',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _ItemStatusBadge(
                isCancelled: isCancelled,
                isCompleted: detail.isFullyFulfilled,
                hasProgress: fulfilled > 0,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuantityValue(label: 'Solicitadas', value: requested),
              ),
              Expanded(
                child: _QuantityValue(label: 'Surtidas', value: fulfilled),
              ),
              Expanded(
                child: _QuantityValue(
                  label: 'Pendientes',
                  value: detail.pendingQuantity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          if (item.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              'Nota: ${item.notes!.trim()}',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityValue extends StatelessWidget {
  final String label;
  final int value;

  const _QuantityValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }
}

class _ItemStatusBadge extends StatelessWidget {
  final bool isCancelled;
  final bool isCompleted;
  final bool hasProgress;

  const _ItemStatusBadge({
    required this.isCancelled,
    required this.isCompleted,
    required this.hasProgress,
  });

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color foreground;
    late final Color background;

    if (isCancelled) {
      label = 'Cancelado';
      foreground = const Color(0xFF64748B);
      background = const Color(0xFFF1F5F9);
    } else if (isCompleted) {
      label = 'Surtido';
      foreground = const Color(0xFF15803D);
      background = const Color(0xFFECFDF3);
    } else if (hasProgress) {
      label = 'Parcial';
      foreground = const Color(0xFFB45309);
      background = const Color(0xFFFFFBEB);
    } else {
      label = 'Pendiente';
      foreground = const Color(0xFF1D4ED8);
      background = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        CustomerOrderStatus.label(status),
        style: TextStyle(
          color: _statusForeground(status),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _statusForeground(String status) {
  return switch (status) {
    CustomerOrderStatus.pending => const Color(0xFF1D4ED8),
    CustomerOrderStatus.partiallyFulfilled => const Color(0xFFB45309),
    CustomerOrderStatus.fulfilled => const Color(0xFF15803D),
    CustomerOrderStatus.cancelled => const Color(0xFF64748B),
    _ => const Color(0xFF475569),
  };
}

Color _statusBackground(String status) {
  return switch (status) {
    CustomerOrderStatus.pending => const Color(0xFFEFF6FF),
    CustomerOrderStatus.partiallyFulfilled => const Color(0xFFFFFBEB),
    CustomerOrderStatus.fulfilled => const Color(0xFFECFDF3),
    CustomerOrderStatus.cancelled => const Color(0xFFF1F5F9),
    _ => const Color(0xFFF1F5F9),
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    CustomerOrderStatus.pending => Icons.hourglass_bottom_outlined,
    CustomerOrderStatus.partiallyFulfilled => Icons.inventory_outlined,
    CustomerOrderStatus.fulfilled => Icons.check_circle_outline,
    CustomerOrderStatus.cancelled => Icons.cancel_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
