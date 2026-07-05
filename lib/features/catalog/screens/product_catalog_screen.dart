import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import '../../categories/screens/categories_screen.dart';
import 'catalog_product_detail_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  final AppDatabase database;

  const ProductCatalogScreen({super.key, required this.database});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _searchController = TextEditingController();

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Catálogo de productos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Administrar categorías',
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<ProductCategory>>(
        stream: widget.database.watchProductCategories(),
        builder: (context, categorySnapshot) {
          final categories = categorySnapshot.data ?? const <ProductCategory>[];

          return StreamBuilder<List<ProductCatalogItem>>(
            stream: widget.database.watchCatalogProducts(),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting &&
                  !productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (productSnapshot.hasError) {
                return Center(
                  child: Text(
                    'No se pudo cargar el catálogo: '
                    '${productSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final allProducts =
                  productSnapshot.data ?? const <ProductCatalogItem>[];

              final visibleProducts = allProducts
                  .where(_matchesCategory)
                  .where(_matchesSearch)
                  .toList();

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    children: [
                      _CatalogFilters(
                        searchController: _searchController,
                        categories: categories,
                        selectedCategoryId: _selectedCategoryId,
                        hasUncategorized: allProducts.any(
                          (item) =>
                              item.category == null || !item.category!.isActive,
                        ),
                        onCategorySelected: (categoryId) {
                          setState(() {
                            _selectedCategoryId = categoryId;
                          });
                        },
                      ),
                      Expanded(
                        child: visibleProducts.isEmpty
                            ? const _EmptyCatalog()
                            : _CatalogGroups(
                                products: visibleProducts,
                                onOpenProduct: _openProduct,
                              ),
                      ),
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

  bool _matchesCategory(ProductCatalogItem item) {
    final selected = _selectedCategoryId;

    if (selected == null) {
      return true;
    }

    if (selected == 0) {
      return item.category == null || !item.category!.isActive;
    }

    return item.category?.id == selected;
  }

  bool _matchesSearch(ProductCatalogItem item) {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final product = item.product;

    return [
      product.name,
      product.description ?? '',
      product.sku ?? '',
      product.barcode ?? '',
      item.categoryName,
    ].join(' ').toLowerCase().contains(query);
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _openCategories() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(database: widget.database),
      ),
    );
  }

  Future<void> _openProduct(ProductCatalogItem item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogProductDetailScreen(
          database: widget.database,
          productId: item.product.id,
        ),
      ),
    );
  }
}

class _CatalogFilters extends StatelessWidget {
  final TextEditingController searchController;

  final List<ProductCategory> categories;
  final int? selectedCategoryId;
  final bool hasUncategorized;
  final ValueChanged<int?> onCategorySelected;

  const _CatalogFilters({
    required this.searchController,
    required this.categories,
    required this.selectedCategoryId,
    required this.hasUncategorized,
    required this.onCategorySelected,
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
                  labelText: 'Buscar en el catálogo',
                  hintText: 'Nombre, descripción, SKU o categoría',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: selectedCategoryId == null,
                        onSelected: (_) {
                          onCategorySelected(null);
                        },
                      ),
                      if (hasUncategorized) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Sin categoría'),
                          selected: selectedCategoryId == 0,
                          onSelected: (_) {
                            onCategorySelected(0);
                          },
                        ),
                      ],
                      for (final category in categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(category.name),
                          selected: selectedCategoryId == category.id,
                          onSelected: (_) {
                            onCategorySelected(category.id);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogGroups extends StatelessWidget {
  final List<ProductCatalogItem> products;
  final ValueChanged<ProductCatalogItem> onOpenProduct;

  const _CatalogGroups({required this.products, required this.onOpenProduct});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ProductCatalogItem>>{};

    for (final item in products) {
      grouped.putIfAbsent(item.categoryName, () => []).add(item);
    }

    final groupNames = grouped.keys.toList()
      ..sort((first, second) => first.compareTo(second));

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          >= 1180 => 4,
          >= 850 => 3,
          >= 560 => 2,
          _ => 1,
        };

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          itemCount: groupNames.length,
          itemBuilder: (context, index) {
            final groupName = groupNames[index];

            final groupProducts = grouped[groupName]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          groupName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${groupProducts.length} productos',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupProducts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 365,
                    ),
                    itemBuilder: (context, itemIndex) {
                      final item = groupProducts[itemIndex];

                      return _CatalogProductCard(
                        item: item,
                        onTap: () {
                          onOpenProduct(item);
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  final ProductCatalogItem item;
  final VoidCallback onTap;

  const _CatalogProductCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    final description = product.description?.trim();

    final hasStock = product.currentStock > 0;
    final usesFlexibleStock = product.allowNegativeStock;

    final stockLabel = usesFlexibleStock
        ? 'Disponible bajo pedido'
        : hasStock
        ? '${product.currentStock} disponibles'
        : 'Agotado';

    final stockForeground = usesFlexibleStock
        ? const Color(0xFFC2410C)
        : hasStock
        ? const Color(0xFF15803D)
        : const Color(0xFFBE123C);

    final stockBackground = usesFlexibleStock
        ? const Color(0xFFFFF7ED)
        : hasStock
        ? const Color(0xFFECFDF3)
        : const Color(0xFFFFF1F2);

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: product.imageBytes != null
                    ? Image.memory(
                        product.imageBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const _CardImagePlaceholder();
                        },
                      )
                    : const _CardImagePlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description?.isNotEmpty == true
                        ? description!
                        : 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatCents(product.salePriceCents),
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: stockBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          stockLabel,
                          style: TextStyle(
                            color: stockForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

class _CardImagePlaceholder extends StatelessWidget {
  const _CardImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 70,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 72,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay productos para mostrar en el catálogo.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
