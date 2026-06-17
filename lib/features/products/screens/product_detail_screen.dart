import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int productId;

  const ProductDetailScreen({
    super.key,
    required this.database,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: database.watchProductById(productId),
      builder: (context, snapshot) {
        final product = snapshot.data;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: const Text('Detalle del producto'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (product != null)
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(
                          database: database,
                          product: product,
                        ),
                      ),
                    );

                    if (updated == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Producto actualizado.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          bottomNavigationBar: product == null
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => _openStockAdjustment(context, product),
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('Ajustar stock'),
                  ),
                ),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<Product?> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Text('Error: ${snapshot.error}'),
      );
    }

    final product = snapshot.data;

    if (product == null) {
      return const Center(
        child: Text('Producto no encontrado.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _ProductSummaryCard(product: product),
        const SizedBox(height: 16),
        _InventoryCard(product: product),
        const SizedBox(height: 16),
        _MovementsCard(
          database: database,
          productId: product.id,
        ),
      ],
    );
  }

  Future<void> _openStockAdjustment(
    BuildContext context,
    Product product,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _StockAdjustmentSheet(
          database: database,
          product: product,
        );
      },
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock actualizado correctamente.'),
        ),
      );
    }
  }
}

class _ProductSummaryCard extends StatelessWidget {
  final Product product;

  const _ProductSummaryCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final marginCents = product.salePriceCents - product.purchasePriceCents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.indigo,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description?.isNotEmpty == true
                            ? product.description!
                            : 'Sin descripción',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  label: 'SKU',
                  value: product.sku?.isNotEmpty == true ? product.sku! : 'N/A',
                ),
                _InfoPill(
                  label: 'Código',
                  value: product.barcode?.isNotEmpty == true
                      ? product.barcode!
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricBox(
                    title: 'Compra',
                    value: formatCents(product.purchasePriceCents),
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricBox(
                    title: 'Venta',
                    value: formatCents(product.salePriceCents),
                    icon: Icons.sell_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricBox(
              title: 'Ganancia estimada por unidad',
              value: formatCents(marginCents),
              icon: Icons.trending_up_outlined,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final Product product;

  const _InventoryCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.currentStock <= product.minStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.warehouse_outlined,
              title: 'Inventario',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricBox(
                    title: 'Stock actual',
                    value: product.currentStock.toString(),
                    icon: Icons.inventory_outlined,
                    danger: isLowStock,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricBox(
                    title: 'Stock mínimo',
                    value: product.minStock.toString(),
                    icon: Icons.notification_important_outlined,
                  ),
                ),
              ],
            ),
            if (isLowStock) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Este producto está en stock bajo.',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementsCard extends StatelessWidget {
  final AppDatabase database;
  final int productId;

  const _MovementsCard({
    required this.database,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.history_outlined,
              title: 'Historial de movimientos',
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<InventoryMovement>>(
              stream: database.watchProductMovements(productId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final movements = snapshot.data ?? [];

                if (movements.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Sin movimientos todavía.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final movement in movements)
                      _MovementTile(movement: movement),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryMovement movement;

  const _MovementTile({
    required this.movement,
  });

  @override
  Widget build(BuildContext context) {
    final quantityText = movement.quantity > 0
        ? '+${movement.quantity}'
        : movement.quantity.toString();

    final isEntry = movement.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isEntry
                ? Colors.green.withOpacity(0.12)
                : Colors.redAccent.withOpacity(0.12),
            child: Icon(
              isEntry ? Icons.arrow_upward : Icons.arrow_downward,
              color: isEntry ? Colors.green : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movementLabel(movement.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(movement.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                if (movement.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    movement.note!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quantityText,
                style: TextStyle(
                  color: isEntry ? Colors.green : Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stock: ${movement.stockAfterMovement}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'purchase_entry':
        return 'Entrada por compra';
      case 'sale_exit':
        return 'Salida por venta';
      case 'manual_adjustment':
        return 'Ajuste manual';
      case 'return_entry':
        return 'Devolución';
      default:
        return 'Movimiento';
    }
  }
}

class _StockAdjustmentSheet extends StatefulWidget {
  final AppDatabase database;
  final Product product;

  const _StockAdjustmentSheet({
    required this.database,
    required this.product,
  });

  @override
  State<_StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends State<_StockAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newStockController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _newStockController.text = widget.product.currentStock.toString();
  }

  @override
  void dispose() {
    _newStockController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.tune_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ajustar stock',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.product.name,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _newStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nueva existencia real',
                hintText: 'Ej. 25',
                prefixIcon: Icon(Icons.inventory_outlined),
              ),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');

                if (number == null) {
                  return 'Escribe una cantidad válida';
                }

                if (number < 0) {
                  return 'El stock no puede ser negativo';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota',
                hintText: 'Ej. Conteo físico, merma, corrección...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAdjustment,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar ajuste'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAdjustment() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final newStock = int.parse(_newStockController.text.trim());
    final difference = newStock - widget.product.currentStock;

    if (difference == 0) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.database.addInventoryMovement(
        productId: widget.product.id,
        type: 'manual_adjustment',
        quantity: difference,
        note: _noteController.text.trim().isEmpty
            ? 'Ajuste manual de inventario'
            : _noteController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo ajustar el stock: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool danger;
  final bool fullWidth;

  const _MetricBox({
    required this.title,
    required this.value,
    required this.icon,
    this.danger = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Theme.of(context).colorScheme.primary;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
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

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}