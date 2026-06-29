import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

enum _ProductFilter { active, inactive, all }

class ProductsScreen extends StatefulWidget {
  final AppDatabase database;

  const ProductsScreen({super.key, required this.database});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchText = '';
  _ProductFilter _selectedFilter = _ProductFilter.active;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Productos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateProductScreen,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: Column(
        children: [
          _ProductFilters(
            selectedFilter: _selectedFilter,
            onChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
          _SearchBox(
            onChanged: (value) {
              setState(() {
                _searchText = value.trim().toLowerCase();
              });
            },
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.database.watchAllProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No fue posible cargar los productos: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final products = snapshot.data ?? [];

                final filteredProducts = products
                    .where(_matchesSelectedFilter)
                    .where(_matchesSearch)
                    .toList();

                if (filteredProducts.isEmpty) {
                  return _EmptyProductsState(
                    hasSearchText: _searchText.isNotEmpty,
                    selectedFilter: _selectedFilter,
                    hasAnyProducts: products.isNotEmpty,
                    onCreateProduct: _openCreateProductScreen,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return _ProductCard(
                      product: product,
                      onToggleStatus: () {
                        _confirmToggleProductStatus(product);
                      },
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              database: widget.database,
                              productId: product.id,
                            ),
                          ),
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
    );
  }

  bool _matchesSelectedFilter(Product product) {
    switch (_selectedFilter) {
      case _ProductFilter.active:
        return product.isActive;
      case _ProductFilter.inactive:
        return !product.isActive;
      case _ProductFilter.all:
        return true;
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

  Future<void> _openCreateProductScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(database: widget.database),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto guardado correctamente.')),
      );
    }
  }

  Future<void> _confirmToggleProductStatus(Product product) async {
    final willActivate = !product.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            willActivate ? Icons.refresh_outlined : Icons.warning_amber_rounded,
            color: willActivate
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
          ),
          title: Text(
            willActivate ? 'Reactivar producto' : 'Desactivar producto',
          ),
          content: Text(
            willActivate
                ? '¿Quieres volver a activar "${product.name}"? Volverá a estar disponible para compras y ventas.'
                : '¿Quieres desactivar "${product.name}"? Ya no podrá seleccionarse en compras o ventas nuevas, pero conservará todo su historial.',
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
              child: Text(willActivate ? 'Reactivar' : 'Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.database.setProductActive(
        productId: product.id,
        isActive: willActivate,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willActivate
                ? '${product.name} fue reactivado.'
                : '${product.name} fue desactivado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado del producto: $error'),
        ),
      );
    }
  }
}

class _ProductFilters extends StatelessWidget {
  final _ProductFilter selectedFilter;
  final ValueChanged<_ProductFilter> onChanged;

  const _ProductFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Activos'),
              selected: selectedFilter == _ProductFilter.active,
              onSelected: (_) {
                onChanged(_ProductFilter.active);
              },
            ),
            ChoiceChip(
              label: const Text('Inactivos'),
              selected: selectedFilter == _ProductFilter.inactive,
              onSelected: (_) {
                onChanged(_ProductFilter.inactive);
              },
            ),
            ChoiceChip(
              label: const Text('Todos'),
              selected: selectedFilter == _ProductFilter.all,
              onSelected: (_) {
                onChanged(_ProductFilter.all);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, SKU o código de barras',
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock =
        product.isActive && product.currentStock <= product.minStock;

    final hasSku = product.sku?.trim().isNotEmpty == true;
    final hasBarcode = product.barcode?.trim().isNotEmpty == true;

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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: product.isActive
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: product.isActive
                      ? const Color(0xFF4338CA)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!product.isActive) ...[
                          const SizedBox(width: 8),
                          const _InactiveProductChip(),
                        ],
                      ],
                    ),
                    if (hasSku || hasBarcode) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (hasSku) 'SKU: ${product.sku}',
                          if (hasBarcode) 'Código: ${product.barcode}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.sell_outlined,
                          label: formatCents(product.salePriceCents),
                          muted: !product.isActive,
                        ),
                        _InfoChip(
                          icon: Icons.inventory_outlined,
                          label: 'Stock: ${product.currentStock}',
                          danger: isLowStock,
                          muted: !product.isActive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (value) {
                  if (value == 'toggle-status') {
                    onToggleStatus();
                  }
                },
                itemBuilder: (_) {
                  return [
                    PopupMenuItem(
                      value: 'toggle-status',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          product.isActive
                              ? Icons.block_outlined
                              : Icons.refresh_outlined,
                          color: product.isActive
                              ? const Color(0xFFB45309)
                              : const Color(0xFF15803D),
                        ),
                        title: Text(
                          product.isActive ? 'Desactivar' : 'Reactivar',
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveProductChip extends StatelessWidget {
  const _InactiveProductChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Inactivo',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final bool muted;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.danger = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color foregroundColor;

    if (muted) {
      backgroundColor = const Color(0xFFF1F5F9);
      foregroundColor = const Color(0xFF64748B);
    } else if (danger) {
      backgroundColor = const Color(0xFFFFE4E6);
      foregroundColor = const Color(0xFFBE123C);
    } else {
      backgroundColor = const Color(0xFFEFF6FF);
      foregroundColor = const Color(0xFF1E4E79);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final bool hasSearchText;
  final _ProductFilter selectedFilter;
  final bool hasAnyProducts;
  final VoidCallback onCreateProduct;

  const _EmptyProductsState({
    required this.hasSearchText,
    required this.selectedFilter,
    required this.hasAnyProducts,
    required this.onCreateProduct,
  });

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final message = _message;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchText
                  ? Icons.search_off_outlined
                  : Icons.inventory_2_outlined,
              size: 72,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            if (!hasAnyProducts && !hasSearchText) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _title {
    if (hasSearchText) {
      return 'No encontramos productos';
    }

    if (!hasAnyProducts) {
      return 'Todavía no tienes productos';
    }

    switch (selectedFilter) {
      case _ProductFilter.active:
        return 'No hay productos activos';
      case _ProductFilter.inactive:
        return 'No hay productos inactivos';
      case _ProductFilter.all:
        return 'No hay productos para mostrar';
    }
  }

  String get _message {
    if (hasSearchText) {
      return 'Prueba con otro nombre, SKU o código de barras.';
    }

    if (!hasAnyProducts) {
      return 'Agrega tu primer producto para comenzar a vender y controlar inventario.';
    }

    switch (selectedFilter) {
      case _ProductFilter.active:
        return 'Reactiva un producto o crea uno nuevo para verlo aquí.';
      case _ProductFilter.inactive:
        return 'Los productos que desactives aparecerán en esta sección.';
      case _ProductFilter.all:
        return 'No hay productos disponibles con el filtro actual.';
    }
  }
}
