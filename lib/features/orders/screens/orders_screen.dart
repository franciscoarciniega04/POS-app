import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'fulfill_orders_screen.dart';

enum _OrderFilter { pending, partiallyFulfilled, fulfilled, cancelled, all }

class OrdersScreen extends StatefulWidget {
  final AppDatabase database;

  const OrdersScreen({super.key, required this.database});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();

  late final Stream<List<CustomerOrderWithCustomer>> _ordersStream;

  _OrderFilter _selectedFilter = _OrderFilter.pending;

  @override
  void initState() {
    super.initState();

    _ordersStream = widget.database.watchAllCustomerOrders();
    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Pedidos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _openFulfillment,
              icon: const Icon(Icons.shopping_cart_checkout_outlined),
              label: const Text('Surtir pedidos'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createOrder,
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('Nuevo pedido'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _OrderFiltersCard(
                searchController: _searchController,
                selectedFilter: _selectedFilter,
                onFilterChanged: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
              Expanded(
                child: StreamBuilder<List<CustomerOrderWithCustomer>>(
                  stream: _ordersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'No se pudieron cargar los pedidos: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final orders =
                        snapshot.data ?? const <CustomerOrderWithCustomer>[];
                    final visibleOrders = _filterOrders(orders);

                    if (visibleOrders.isEmpty) {
                      return _EmptyOrdersState(
                        hasSearch: _searchController.text.trim().isNotEmpty,
                        filter: _selectedFilter,
                        onCreate: _createOrder,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: visibleOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final orderData = visibleOrders[index];

                        return _OrderCard(
                          orderData: orderData,
                          onTap: () {
                            _openOrder(orderData.order.id);
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

  void _refreshSearch() {
    setState(() {});
  }

  List<CustomerOrderWithCustomer> _filterOrders(
    List<CustomerOrderWithCustomer> orders,
  ) {
    final search = _searchController.text.trim().toLowerCase();

    return orders.where((orderData) {
      final order = orderData.order;
      final customer = orderData.customer;

      final matchesStatus = switch (_selectedFilter) {
        _OrderFilter.pending => order.status == CustomerOrderStatus.pending,
        _OrderFilter.partiallyFulfilled =>
          order.status == CustomerOrderStatus.partiallyFulfilled,
        _OrderFilter.fulfilled => order.status == CustomerOrderStatus.fulfilled,
        _OrderFilter.cancelled => order.status == CustomerOrderStatus.cancelled,
        _OrderFilter.all => true,
      };

      if (!matchesStatus) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final values = [
        order.id.toString(),
        customer.name,
        customer.phone ?? '',
        order.notes ?? '',
        CustomerOrderStatus.label(order.status),
      ].join(' ').toLowerCase();

      return values.contains(search);
    }).toList();
  }

  Future<void> _createOrder() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(database: widget.database),
      ),
    );
  }

  Future<void> _openOrder(int orderId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailScreen(database: widget.database, orderId: orderId),
      ),
    );
  }

  Future<void> _openFulfillment() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FulfillOrdersScreen(database: widget.database),
      ),
    );
  }
}

class _OrderFiltersCard extends StatelessWidget {
  final TextEditingController searchController;
  final _OrderFilter selectedFilter;
  final ValueChanged<_OrderFilter> onFilterChanged;

  const _OrderFiltersCard({
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar pedido',
                  hintText: 'Número, cliente, teléfono o nota',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(
                      label: 'Pendientes',
                      value: _OrderFilter.pending,
                    ),
                    _filterChip(
                      label: 'Parciales',
                      value: _OrderFilter.partiallyFulfilled,
                    ),
                    _filterChip(
                      label: 'Surtidos',
                      value: _OrderFilter.fulfilled,
                    ),
                    _filterChip(
                      label: 'Cancelados',
                      value: _OrderFilter.cancelled,
                    ),
                    _filterChip(label: 'Todos', value: _OrderFilter.all),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required _OrderFilter value}) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedFilter == value,
      onSelected: (_) {
        onFilterChanged(value);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrderWithCustomer orderData;
  final VoidCallback onTap;

  const _OrderCard({required this.orderData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final order = orderData.order;
    final customer = orderData.customer;
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final notes = order.notes?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusBackground(order.status),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _statusIcon(order.status),
                  color: _statusForeground(order.status),
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
                            'Pedido #${order.id} · ${customer.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateFormatter.format(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        CustomerOrderStatus.label(status),
        style: TextStyle(
          color: _statusForeground(status),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final bool hasSearch;
  final _OrderFilter filter;
  final VoidCallback onCreate;

  const _EmptyOrdersState({
    required this.hasSearch,
    required this.filter,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final message = hasSearch
        ? 'No se encontraron pedidos con esa búsqueda.'
        : switch (filter) {
            _OrderFilter.pending => 'No hay pedidos pendientes.',
            _OrderFilter.partiallyFulfilled =>
              'No hay pedidos parcialmente surtidos.',
            _OrderFilter.fulfilled => 'No hay pedidos surtidos.',
            _OrderFilter.cancelled => 'No hay pedidos cancelados.',
            _OrderFilter.all => 'Todavía no hay pedidos registrados.',
          };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 68,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (!hasSearch &&
                (filter == _OrderFilter.pending ||
                    filter == _OrderFilter.all)) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Crear pedido'),
              ),
            ],
          ],
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
