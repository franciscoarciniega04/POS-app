import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import '../../catalog/screens/product_catalog_screen.dart';
import '../../categories/screens/categories_screen.dart';
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

  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Productos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Catálogo visual',
            onPressed: _openCatalogScreen,
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Categorías',
            onPressed: _openCategoriesScreen,
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateProductScreen,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: StreamBuilder<List<ProductCategory>>(
        stream: widget.database.watchProductCategories(includeInactive: true),
        builder: (context, categorySnapshot) {
          final categories = categorySnapshot.data ?? const <ProductCategory>[];

          final categoryNames = {
            for (final category in categories)
              category.id: category.isActive
                  ? category.name
                  : '${category.name} (inactiva)',
          };

          return Column(
            children: [
              _ProductFilters(
                selectedFilter: _selectedFilter,
                onChanged: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
              _CategoryFilterBar(
                categories: categories,
                selectedCategoryId: _selectedCategoryId,
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
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
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No fue posible cargar los productos: '
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final products = snapshot.data ?? const <Product>[];

                    final filteredProducts = products
                        .where(_matchesSelectedFilter)
                        .where(_matchesCategory)
                        .where(
                          (product) => _matchesSearch(
                            product,
                            categoryNames[product.categoryId] ??
                                'Sin categoría',
                          ),
                        )
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

                        final categoryName =
                            categoryNames[product.categoryId] ??
                            'Sin categoría';

                        return _ProductCard(
                          product: product,
                          categoryName: categoryName,
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
          );
        },
      ),
    );
  }

  bool _matchesSelectedFilter(Product product) {
    return switch (_selectedFilter) {
      _ProductFilter.active => product.isActive,
      _ProductFilter.inactive => !product.isActive,
      _ProductFilter.all => true,
    };
  }

  bool _matchesCategory(Product product) {
    final selected = _selectedCategoryId;

    if (selected == null) {
      return true;
    }

    if (selected == 0) {
      return product.categoryId == null;
    }

    return product.categoryId == selected;
  }

  bool _matchesSearch(Product product, String categoryName) {
    if (_searchText.isEmpty) {
      return true;
    }

    final searchableValues = [
      product.name,
      product.sku ?? '',
      product.barcode ?? '',
      product.description ?? '',
      categoryName,
    ];

    return searchableValues.any(
      (value) => value.toLowerCase().contains(_searchText),
    );
  }

  Future<void> _openCatalogScreen() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCatalogScreen(database: widget.database),
      ),
    );
  }

  Future<void> _openCategoriesScreen() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(database: widget.database),
      ),
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
                ? '¿Quieres volver a activar "${product.name}"? '
                      'Volverá a estar disponible para compras y ventas.'
                : '¿Quieres desactivar "${product.name}"? '
                      'Ya no podrá seleccionarse en compras o ventas nuevas, '
                      'pero conservará todo su historial.',
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

class _CategoryFilterBar extends StatelessWidget {
  final List<ProductCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onChanged;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todas las categorías'),
                selected: selectedCategoryId == null,
                onSelected: (_) {
                  onChanged(null);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Sin categoría'),
                selected: selectedCategoryId == 0,
                onSelected: (_) {
                  onChanged(0);
                },
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    category.isActive
                        ? category.name
                        : '${category.name} (inactiva)',
                  ),
                  selected: selectedCategoryId == category.id,
                  onSelected: (_) {
                    onChanged(category.id);
                  },
                ),
              ],
            ],
          ),
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
          hintText: 'Buscar por nombre, categoría, SKU o código',
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
  final String categoryName;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = product.currentStock < 0;

    final isLowStock =
        product.isActive &&
        !product.allowNegativeStock &&
        product.currentStock <= product.minStock;

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
              _ProductThumbnail(product: product),
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
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (!product.isActive) ...[
                          const SizedBox(width: 8),
                          const _StatusChip(
                            label: 'Inactivo',
                            foreground: Color(0xFF64748B),
                            background: Color(0xFFF1F5F9),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: categoryName,
                          foreground: const Color(0xFF7C3AED),
                          background: const Color(0xFFF5F3FF),
                          icon: Icons.category_outlined,
                        ),
                        _StatusChip(
                          label: product.showInCatalog
                              ? 'Visible en catálogo'
                              : 'Oculto del catálogo',
                          foreground: product.showInCatalog
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                          background: product.showInCatalog
                              ? const Color(0xFFECFDF3)
                              : const Color(0xFFF1F5F9),
                          icon: product.showInCatalog
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        _StatusChip(
                          label: product.allowNegativeStock
                              ? 'Venta sin stock'
                              : 'Control de stock',
                          foreground: product.allowNegativeStock
                              ? const Color(0xFFC2410C)
                              : const Color(0xFF1E4E79),
                          background: product.allowNegativeStock
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFEFF6FF),
                          icon: product.allowNegativeStock
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.inventory_outlined,
                        ),
                      ],
                    ),
                    if (hasSku || hasBarcode) ...[
                      const SizedBox(height: 8),
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
                    if (product.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
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
                          icon: product.allowNegativeStock
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.inventory_outlined,
                          label: product.allowNegativeStock
                              ? 'Stock flexible: ${product.currentStock}'
                              : 'Stock: ${product.currentStock}',
                          danger: isNegative || isLowStock,
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

class _ProductThumbnail extends StatelessWidget {
  final Product product;

  const _ProductThumbnail({required this.product});

  @override
  Widget build(BuildContext context) {
    final bytes = product.imageBytes;

    return Container(
      width: 82,
      height: 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: product.isActive
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _ProductIcon(isActive: product.isActive);
              },
            )
          : _ProductIcon(isActive: product.isActive),
    );
  }
}

class _ProductIcon extends StatelessWidget {
  final bool isActive;

  const _ProductIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.inventory_2_outlined,
      color: isActive ? const Color(0xFF4338CA) : const Color(0xFF64748B),
      size: 34,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      return 'No hay resultados';
    }

    switch (selectedFilter) {
      case _ProductFilter.active:
        return hasAnyProducts
            ? 'No hay productos activos'
            : 'Todavía no hay productos';
      case _ProductFilter.inactive:
        return 'No hay productos inactivos';
      case _ProductFilter.all:
        return 'No hay productos para mostrar';
    }
  }

  String get _message {
    if (hasSearchText) {
      return 'Prueba con otro nombre, categoría, SKU o código.';
    }

    switch (selectedFilter) {
      case _ProductFilter.active:
        return hasAnyProducts
            ? 'Los productos existentes están inactivos.'
            : 'Agrega el primer producto para comenzar.';
      case _ProductFilter.inactive:
        return 'Cuando desactives un producto aparecerá aquí.';
      case _ProductFilter.all:
        return 'Agrega un producto para comenzar.';
    }
  }
}
