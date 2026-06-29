import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import '../../products/screens/product_detail_screen.dart';

enum _InventoryStockFilter { all, lowStock, outOfStock, inactive }

enum _InventoryMovementFilter { all, purchases, sales, adjustments }

class InventoryScreen extends StatelessWidget {
  final AppDatabase database;

  const InventoryScreen({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Inventario'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Existencias'),
              Tab(icon: Icon(Icons.history_outlined), text: 'Movimientos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InventoryStockTab(database: database),
            _InventoryMovementsTab(database: database),
          ],
        ),
      ),
    );
  }
}

class _InventoryStockTab extends StatefulWidget {
  final AppDatabase database;

  const _InventoryStockTab({required this.database});

  @override
  State<_InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<_InventoryStockTab> {
  late final Stream<List<Product>> _productsStream;

  String _searchText = '';
  _InventoryStockFilter _selectedFilter = _InventoryStockFilter.all;

  @override
  void initState() {
    super.initState();

    _productsStream = widget.database.watchInventoryProducts();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _InventoryErrorState(message: snapshot.error.toString());
        }

        final products = snapshot.data ?? [];

        final filteredProducts = products
            .where(_matchesSelectedFilter)
            .where(_matchesSearch)
            .toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                _InventorySummary(products: products),
                _InventoryStockFilters(
                  selectedFilter: _selectedFilter,
                  onChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                _InventorySearchField(
                  hintText: 'Buscar por nombre, SKU o código de barras',
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.trim().toLowerCase();
                    });
                  },
                ),
                Expanded(
                  child: _buildProductsContent(
                    allProducts: products,
                    filteredProducts: filteredProducts,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsContent({
    required List<Product> allProducts,
    required List<Product> filteredProducts,
  }) {
    if (allProducts.isEmpty) {
      return const _EmptyInventoryState();
    }

    if (filteredProducts.isEmpty) {
      return const _NoInventoryResults(
        message: 'No encontramos productos con los filtros seleccionados.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: filteredProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = filteredProducts[index];

        return _ProductInventoryCard(
          product: product,
          onTap: () => _openProductDetail(product),
        );
      },
    );
  }

  bool _matchesSelectedFilter(Product product) {
    switch (_selectedFilter) {
      case _InventoryStockFilter.all:
        return true;

      case _InventoryStockFilter.lowStock:
        return product.isActive &&
            product.currentStock > 0 &&
            product.currentStock <= product.minStock;

      case _InventoryStockFilter.outOfStock:
        return product.currentStock <= 0;

      case _InventoryStockFilter.inactive:
        return !product.isActive;
    }
  }

  bool _matchesSearch(Product product) {
    if (_searchText.isEmpty) {
      return true;
    }

    final searchableValues = [
      product.name,
      product.sku ?? '',
      product.barcode ?? '',
      product.description ?? '',
    ];

    return searchableValues.any(
      (value) => value.toLowerCase().contains(_searchText),
    );
  }

  void _openProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          database: widget.database,
          productId: product.id,
        ),
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  final List<Product> products;

  const _InventorySummary({required this.products});

  @override
  Widget build(BuildContext context) {
    final activeProducts = products.where((product) => product.isActive);

    final outOfStockCount = activeProducts
        .where((product) => product.currentStock <= 0)
        .length;

    final lowStockCount = activeProducts
        .where(
          (product) =>
              product.currentStock > 0 &&
              product.currentStock <= product.minStock,
        )
        .length;

    final totalUnits = activeProducts.fold<int>(
      0,
      (total, product) =>
          total + (product.currentStock > 0 ? product.currentStock : 0),
    );

    final inventoryValueCents = activeProducts.fold<int>(0, (total, product) {
      final stock = product.currentStock > 0 ? product.currentStock : 0;

      return total + stock * product.purchasePriceCents;
    });

    final cards = [
      _InventorySummaryCard(
        title: 'Unidades disponibles',
        value: totalUnits.toString(),
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF1D4ED8),
        backgroundColor: const Color(0xFFEFF6FF),
      ),
      _InventorySummaryCard(
        title: 'Stock bajo',
        value: lowStockCount.toString(),
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFB45309),
        backgroundColor: const Color(0xFFFFFBEB),
      ),
      _InventorySummaryCard(
        title: 'Sin existencias',
        value: outOfStockCount.toString(),
        icon: Icons.remove_shopping_cart_outlined,
        iconColor: const Color(0xFFBE123C),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
      _InventorySummaryCard(
        title: 'Valor estimado',
        value: formatCents(inventoryValueCents),
        icon: Icons.account_balance_wallet_outlined,
        iconColor: const Color(0xFF15803D),
        backgroundColor: const Color(0xFFECFDF3),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 950) {
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            );
          }

          if (constraints.maxWidth >= 600) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
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
              const SizedBox(height: 12),
              cards[3],
            ],
          );
        },
      ),
    );
  }
}

class _InventorySummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _InventorySummaryCard({
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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

class _InventoryStockFilters extends StatelessWidget {
  final _InventoryStockFilter selectedFilter;
  final ValueChanged<_InventoryStockFilter> onChanged;

  const _InventoryStockFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

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
              label: const Text('Todos'),
              selected: selectedFilter == _InventoryStockFilter.all,
              onSelected: (_) {
                onChanged(_InventoryStockFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Stock bajo'),
              selected: selectedFilter == _InventoryStockFilter.lowStock,
              onSelected: (_) {
                onChanged(_InventoryStockFilter.lowStock);
              },
            ),
            ChoiceChip(
              label: const Text('Sin existencias'),
              selected: selectedFilter == _InventoryStockFilter.outOfStock,
              onSelected: (_) {
                onChanged(_InventoryStockFilter.outOfStock);
              },
            ),
            ChoiceChip(
              label: const Text('Inactivos'),
              selected: selectedFilter == _InventoryStockFilter.inactive,
              onSelected: (_) {
                onChanged(_InventoryStockFilter.inactive);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InventorySearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const _InventorySearchField({
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
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

class _ProductInventoryCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductInventoryCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sku = product.sku?.trim();
    final barcode = product.barcode?.trim();

    final inventoryValueCents = product.currentStock > 0
        ? product.currentStock * product.purchasePriceCents
        : 0;

    final isOutOfStock = product.currentStock <= 0;

    final isLowStock =
        product.currentStock > 0 && product.currentStock <= product.minStock;

    final foregroundColor = isOutOfStock
        ? const Color(0xFFBE123C)
        : isLowStock
        ? const Color(0xFFB45309)
        : const Color(0xFF15803D);

    final backgroundColor = isOutOfStock
        ? const Color(0xFFFFF1F2)
        : isLowStock
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFECFDF3);

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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: foregroundColor,
                  size: 29,
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
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        _StockStatusChip(product: product),
                      ],
                    ),
                    if (sku?.isNotEmpty == true ||
                        barcode?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (sku?.isNotEmpty == true) 'SKU: $sku',
                          if (barcode?.isNotEmpty == true) 'Código: $barcode',
                        ].join(' · '),
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
                        _InventoryInformationChip(
                          icon: Icons.inventory_outlined,
                          label: 'Stock: ${product.currentStock}',
                          foregroundColor: foregroundColor,
                          backgroundColor: backgroundColor,
                        ),
                        _InventoryInformationChip(
                          icon: Icons.low_priority_outlined,
                          label: 'Mínimo: ${product.minStock}',
                        ),
                        _InventoryInformationChip(
                          icon: Icons.payments_outlined,
                          label:
                              'Costo: ${formatCents(product.purchasePriceCents)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Valor en inventario: '
                      '${formatCents(inventoryValueCents)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
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

class _StockStatusChip extends StatelessWidget {
  final Product product;

  const _StockStatusChip({required this.product});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color foregroundColor;
    late final Color backgroundColor;

    if (!product.isActive) {
      label = 'Inactivo';
      foregroundColor = const Color(0xFF64748B);
      backgroundColor = const Color(0xFFF1F5F9);
    } else if (product.currentStock <= 0) {
      label = 'Agotado';
      foregroundColor = const Color(0xFFBE123C);
      backgroundColor = const Color(0xFFFFF1F2);
    } else if (product.currentStock <= product.minStock) {
      label = 'Stock bajo';
      foregroundColor = const Color(0xFFB45309);
      backgroundColor = const Color(0xFFFFFBEB);
    } else {
      label = 'Disponible';
      foregroundColor = const Color(0xFF15803D);
      backgroundColor = const Color(0xFFECFDF3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InventoryInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _InventoryInformationChip({
    required this.icon,
    required this.label,
    this.foregroundColor = const Color(0xFF1E4E79),
    this.backgroundColor = const Color(0xFFEFF6FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryMovementsTab extends StatefulWidget {
  final AppDatabase database;

  const _InventoryMovementsTab({required this.database});

  @override
  State<_InventoryMovementsTab> createState() => _InventoryMovementsTabState();
}

class _InventoryMovementsTabState extends State<_InventoryMovementsTab> {
  late final Stream<List<InventoryMovementDetail>> _movementsStream;

  String _searchText = '';

  _InventoryMovementFilter _selectedFilter = _InventoryMovementFilter.all;

  @override
  void initState() {
    super.initState();

    _movementsStream = widget.database.watchAllInventoryMovements();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryMovementDetail>>(
      stream: _movementsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _InventoryErrorState(message: snapshot.error.toString());
        }

        final movements = snapshot.data ?? [];

        final filteredMovements = movements
            .where(_matchesSelectedFilter)
            .where(_matchesSearch)
            .toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                _InventoryMovementFilters(
                  selectedFilter: _selectedFilter,
                  onChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                _InventorySearchField(
                  hintText: 'Buscar por producto, tipo o referencia',
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.trim().toLowerCase();
                    });
                  },
                ),
                Expanded(
                  child: _buildMovementsContent(
                    allMovements: movements,
                    filteredMovements: filteredMovements,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovementsContent({
    required List<InventoryMovementDetail> allMovements,
    required List<InventoryMovementDetail> filteredMovements,
  }) {
    if (allMovements.isEmpty) {
      return const _NoInventoryResults(
        message: 'Todavía no hay movimientos de inventario.',
      );
    }

    if (filteredMovements.isEmpty) {
      return const _NoInventoryResults(
        message: 'No encontramos movimientos con los filtros seleccionados.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: filteredMovements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _InventoryMovementCard(detail: filteredMovements[index]);
      },
    );
  }

  bool _matchesSelectedFilter(InventoryMovementDetail detail) {
    final type = detail.movement.type;

    switch (_selectedFilter) {
      case _InventoryMovementFilter.all:
        return true;

      case _InventoryMovementFilter.purchases:
        return type.startsWith('purchase');

      case _InventoryMovementFilter.sales:
        return type.startsWith('sale');

      case _InventoryMovementFilter.adjustments:
        return !type.startsWith('purchase') && !type.startsWith('sale');
    }
  }

  bool _matchesSearch(InventoryMovementDetail detail) {
    if (_searchText.isEmpty) {
      return true;
    }

    final searchableValues = [
      detail.product.name,
      detail.product.sku ?? '',
      detail.product.barcode ?? '',
      detail.movement.type,
      _movementLabel(detail.movement.type),
      detail.movement.note ?? '',
    ];

    return searchableValues.any(
      (value) => value.toLowerCase().contains(_searchText),
    );
  }
}

class _InventoryMovementFilters extends StatelessWidget {
  final _InventoryMovementFilter selectedFilter;
  final ValueChanged<_InventoryMovementFilter> onChanged;

  const _InventoryMovementFilters({
    required this.selectedFilter,
    required this.onChanged,
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
              label: const Text('Todos'),
              selected: selectedFilter == _InventoryMovementFilter.all,
              onSelected: (_) {
                onChanged(_InventoryMovementFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Compras'),
              selected: selectedFilter == _InventoryMovementFilter.purchases,
              onSelected: (_) {
                onChanged(_InventoryMovementFilter.purchases);
              },
            ),
            ChoiceChip(
              label: const Text('Ventas'),
              selected: selectedFilter == _InventoryMovementFilter.sales,
              onSelected: (_) {
                onChanged(_InventoryMovementFilter.sales);
              },
            ),
            ChoiceChip(
              label: const Text('Ajustes'),
              selected: selectedFilter == _InventoryMovementFilter.adjustments,
              onSelected: (_) {
                onChanged(_InventoryMovementFilter.adjustments);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMovementCard extends StatelessWidget {
  final InventoryMovementDetail detail;

  const _InventoryMovementCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final movement = detail.movement;
    final product = detail.product;
    final visual = _movementVisual(movement.type);

    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');

    final note = movement.note?.trim();

    final quantityText = movement.quantity > 0
        ? '+${movement.quantity}'
        : movement.quantity.toString();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(visual.icon, color: visual.foregroundColor),
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
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        quantityText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: visual.foregroundColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visual.label,
                    style: TextStyle(
                      color: visual.foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InventoryInformationChip(
                        icon: Icons.inventory_outlined,
                        label: 'Stock final: ${movement.stockAfterMovement}',
                      ),
                      _InventoryInformationChip(
                        icon: Icons.calendar_today_outlined,
                        label: dateFormatter.format(
                          movement.createdAt.toLocal(),
                        ),
                      ),
                    ],
                  ),
                  if (note?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      note!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementVisual {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _MovementVisual({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

_MovementVisual _movementVisual(String type) {
  switch (type) {
    case 'purchase_entry':
      return const _MovementVisual(
        label: 'Entrada por compra',
        icon: Icons.shopping_cart_checkout_outlined,
        foregroundColor: Color(0xFF15803D),
        backgroundColor: Color(0xFFECFDF3),
      );

    case 'purchase_cancellation':
      return const _MovementVisual(
        label: 'Cancelación de compra',
        icon: Icons.remove_shopping_cart_outlined,
        foregroundColor: Color(0xFFBE123C),
        backgroundColor: Color(0xFFFFF1F2),
      );

    case 'sale_exit':
      return const _MovementVisual(
        label: 'Salida por venta',
        icon: Icons.point_of_sale_outlined,
        foregroundColor: Color(0xFFC2410C),
        backgroundColor: Color(0xFFFFF7ED),
      );

    case 'sale_cancellation':
      return const _MovementVisual(
        label: 'Devolución por cancelación de venta',
        icon: Icons.assignment_return_outlined,
        foregroundColor: Color(0xFF1D4ED8),
        backgroundColor: Color(0xFFEFF6FF),
      );

    case 'initial_stock':
      return const _MovementVisual(
        label: 'Stock inicial',
        icon: Icons.inventory_2_outlined,
        foregroundColor: Color(0xFF4338CA),
        backgroundColor: Color(0xFFEEF2FF),
      );

    case 'adjustment_in':
      return const _MovementVisual(
        label: 'Ajuste de entrada',
        icon: Icons.add_circle_outline,
        foregroundColor: Color(0xFF15803D),
        backgroundColor: Color(0xFFECFDF3),
      );

    case 'adjustment_out':
      return const _MovementVisual(
        label: 'Ajuste de salida',
        icon: Icons.remove_circle_outline,
        foregroundColor: Color(0xFFBE123C),
        backgroundColor: Color(0xFFFFF1F2),
      );

    default:
      return const _MovementVisual(
        label: 'Movimiento de inventario',
        icon: Icons.sync_alt_outlined,
        foregroundColor: Color(0xFF475569),
        backgroundColor: Color(0xFFF1F5F9),
      );
  }
}

String _movementLabel(String type) {
  return _movementVisual(type).label;
}

class _EmptyInventoryState extends StatelessWidget {
  const _EmptyInventoryState();

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
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes productos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea productos para comenzar a controlar las existencias.',
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

class _NoInventoryResults extends StatelessWidget {
  final String message;

  const _NoInventoryResults({required this.message});

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
              message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryErrorState extends StatelessWidget {
  final String message;

  const _InventoryErrorState({required this.message});

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
              'No fue posible cargar el inventario',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
