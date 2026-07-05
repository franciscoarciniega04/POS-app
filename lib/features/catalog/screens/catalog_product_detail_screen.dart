import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class CatalogProductDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int productId;

  const CatalogProductDetailScreen({
    super.key,
    required this.database,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProductCatalogItem?>(
      stream: database.watchCatalogProductById(productId),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: const Text('Detalle del producto'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<ProductCatalogItem?> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          'No se pudo cargar el producto: '
          '${snapshot.error}',
        ),
      );
    }

    final item = snapshot.data;

    if (item == null) {
      return const Center(child: Text('El producto ya no está disponible.'));
    }

    final product = item.product;
    final description = product.description?.trim();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final image = _ProductImage(imageBytes: product.imageBytes);

                  final information = Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryBadge(label: item.categoryName),
                        const SizedBox(height: 14),
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Text(
                          formatCents(product.salePriceCents),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF15803D),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _StockBadge(
                          stock: product.currentStock,
                          allowNegativeStock: product.allowNegativeStock,
                        ),
                        if (product.sku?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  if (constraints.maxWidth >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 390, height: 430, child: image),
                        Expanded(child: information),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: image,
                      ),
                      information,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Uint8List? imageBytes;

  const _ProductImage({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const _ImagePlaceholder();
        },
      );
    }

    return const _ImagePlaceholder();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 88,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  final bool allowNegativeStock;

  const _StockBadge({required this.stock, required this.allowNegativeStock});

  @override
  Widget build(BuildContext context) {
    final available = stock > 0;

    final label = allowNegativeStock
        ? 'Disponible bajo pedido'
        : available
        ? '$stock disponibles'
        : 'Agotado';

    final foreground = allowNegativeStock
        ? const Color(0xFFC2410C)
        : available
        ? const Color(0xFF15803D)
        : const Color(0xFFBE123C);

    final background = allowNegativeStock
        ? const Color(0xFFFFF7ED)
        : available
        ? const Color(0xFFECFDF3)
        : const Color(0xFFFFF1F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w900),
      ),
    );
  }
}
