import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  final AppDatabase database;

  const ProductsScreen({super.key, required this.database});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchText = '';

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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final products = snapshot.data ?? [];

                final activeProducts = products
                    .where((product) => product.isActive)
                    .where(_matchesSearch)
                    .toList();

                if (activeProducts.isEmpty) {
                  return _EmptyProductsState(
                    hasSearchText: _searchText.isNotEmpty,
                    onCreateProduct: _openCreateProductScreen,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: activeProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = activeProducts[index];

                    return _ProductCard(
                      product: product,
                      onDeactivate: () => _confirmDeactivate(product),
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

  bool _matchesSearch(Product product) {
    if (_searchText.isEmpty) return true;

    final name = product.name.toLowerCase();
    final sku = product.sku?.toLowerCase() ?? '';
    final barcode = product.barcode?.toLowerCase() ?? '';

    return name.contains(_searchText) ||
        sku.contains(_searchText) ||
        barcode.contains(_searchText);
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

  Future<void> _confirmDeactivate(Product product) async {
    final shouldDeactivate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desactivar producto'),
          content: Text(
            '¿Quieres desactivar "${product.name}"? No se borrará su historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar'),
            ),
          ],
        );
      },
    );

    if (shouldDeactivate != true) return;

    await widget.database.deactivateProduct(product.id);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} fue desactivado.')));
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
  final VoidCallback onDeactivate;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.currentStock <= product.minStock;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF4338CA),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (product.sku != null && product.sku!.isNotEmpty)
                          'SKU: ${product.sku}',
                        if (product.barcode != null &&
                            product.barcode!.isNotEmpty)
                          'Código: ${product.barcode}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.sell_outlined,
                          label: formatCents(product.salePriceCents),
                        ),
                        _InfoChip(
                          icon: Icons.inventory_outlined,
                          label: 'Stock: ${product.currentStock}',
                          danger: isLowStock,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deactivate') {
                    onDeactivate();
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Text('Desactivar'),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = danger
        ? const Color(0xFFFFE4E6)
        : const Color(0xFFEFF6FF);

    final foregroundColor = danger
        ? const Color(0xFFBE123C)
        : const Color(0xFF1E4E79);

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
  final VoidCallback onCreateProduct;

  const _EmptyProductsState({
    required this.hasSearchText,
    required this.onCreateProduct,
  });

  @override
  Widget build(BuildContext context) {
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
              hasSearchText
                  ? 'No encontramos productos'
                  : 'Todavía no tienes productos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchText
                  ? 'Prueba con otro nombre, SKU o código de barras.'
                  : 'Agrega tu primer producto para comenzar a vender y controlar inventario.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            if (!hasSearchText) ...[
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
}
