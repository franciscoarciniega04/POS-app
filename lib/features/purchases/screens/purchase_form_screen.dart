import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class PurchaseFormScreen extends StatefulWidget {
  final AppDatabase database;

  const PurchaseFormScreen({super.key, required this.database});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _supplierController = TextEditingController();
  final _noteController = TextEditingController();

  final List<_PurchaseDraftItem> _items = [];

  bool _isSaving = false;

  int get _totalCents {
    return _items.fold<int>(0, (total, item) => total + item.subtotalCents);
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Nueva compra'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _PurchaseBottomBar(
        totalCents: _totalCents,
        itemCount: _items.length,
        isSaving: _isSaving,
        onSave: _items.isEmpty ? null : _savePurchase,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
              children: [
                _PurchaseSectionCard(
                  title: 'Datos de la compra',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    TextFormField(
                      controller: _supplierController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor',
                        hintText: 'Ej. Distribuidora del Centro',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Nota o referencia',
                        hintText: 'Ej. Factura 1234, compra de contado...',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PurchaseSectionCard(
                  title: 'Productos comprados',
                  icon: Icons.inventory_2_outlined,
                  trailing: OutlinedButton.icon(
                    onPressed: () => _openItemSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar producto'),
                  ),
                  children: [
                    if (_items.isEmpty)
                      _EmptyPurchaseItems(onAddProduct: () => _openItemSheet())
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < _items.length;
                            index++
                          ) ...[
                            _PurchaseItemCard(
                              item: _items[index],
                              onEdit: () {
                                _openItemSheet(
                                  item: _items[index],
                                  index: index,
                                );
                              },
                              onRemove: () => _removeItem(index),
                            ),
                            if (index < _items.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openItemSheet({_PurchaseDraftItem? item, int? index}) async {
    final excludedProductIds = _items
        .map((currentItem) => currentItem.product.id)
        .toSet();

    // Si estamos editando una línea, permitimos conservar su producto.
    if (item != null) {
      excludedProductIds.remove(item.product.id);
    }

    final result = await showModalBottomSheet<_PurchaseDraftItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) {
        return _PurchaseItemSheet(
          database: widget.database,
          initialItem: item,
          excludedProductIds: excludedProductIds,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  void _removeItem(int index) {
    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedItem.product.name} fue eliminado.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (!mounted) return;

            setState(() {
              final safeIndex = index.clamp(0, _items.length);
              _items.insert(safeIndex, removedItem);
            });
          },
        ),
      ),
    );
  }

  Future<void> _savePurchase() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto a la compra.'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final purchaseId = await widget.database.createPurchase(
        supplierName: _supplierController.text,
        note: _noteController.text,
        items: _items
            .map(
              (item) => PurchaseLineInput(
                productId: item.product.id,
                quantity: item.quantity,
                unitCostCents: item.unitCostCents,
              ),
            )
            .toList(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, purchaseId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la compra: $error')),
      );
    }
  }
}

class _PurchaseDraftItem {
  final Product product;
  final int quantity;
  final int unitCostCents;

  const _PurchaseDraftItem({
    required this.product,
    required this.quantity,
    required this.unitCostCents,
  });

  int get subtotalCents => quantity * unitCostCents;
}

class _PurchaseSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _PurchaseSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

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
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EmptyPurchaseItems extends StatelessWidget {
  final VoidCallback onAddProduct;

  const _EmptyPurchaseItems({required this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_shopping_cart_outlined,
              color: Color(0xFF15803D),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Agrega productos a la compra',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Selecciona un producto, indica la cantidad recibida y su costo unitario.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemCard extends StatelessWidget {
  final _PurchaseDraftItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _PurchaseItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sku = item.product.sku?.trim();

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
            width: 52,
            height: 52,
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
                  item.product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sku != null && sku.isNotEmpty) ...[
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
                    _ItemInformationChip(
                      icon: Icons.numbers_outlined,
                      label: 'Cantidad: ${item.quantity}',
                    ),
                    _ItemInformationChip(
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
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;

                case 'remove':
                  onRemove();
                  break;
              }
            },
            itemBuilder: (_) {
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    title: Text('Eliminar'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _ItemInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ItemInformationChip({required this.icon, required this.label});

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

class _PurchaseBottomBar extends StatelessWidget {
  final int totalCents;
  final int itemCount;
  final bool isSaving;
  final VoidCallback? onSave;

  const _PurchaseBottomBar({
    required this.totalCents,
    required this.itemCount,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 560;

            final totalWidget = Column(
              crossAxisAlignment: isWide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: ${formatCents(totalCents)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            );

            final saveButton = FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Guardando...' : 'Registrar compra'),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: totalWidget),
                  const SizedBox(width: 20),
                  saveButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [totalWidget, const SizedBox(height: 12), saveButton],
            );
          },
        ),
      ),
    );
  }
}

class _PurchaseItemSheet extends StatefulWidget {
  final AppDatabase database;
  final _PurchaseDraftItem? initialItem;
  final Set<int> excludedProductIds;

  const _PurchaseItemSheet({
    required this.database,
    required this.excludedProductIds,
    this.initialItem,
  });

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
  final _formKey = GlobalKey<FormState>();

  late final Stream<List<Product>> _productsStream;

  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();

  Product? _selectedProduct;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();

    _productsStream = widget.database.watchAllProducts();

    final initialItem = widget.initialItem;

    if (initialItem != null) {
      _selectedProduct = initialItem.product;
      _quantityController.text = initialItem.quantity.toString();
      _unitCostController.text = _centsToMoneyText(initialItem.unitCostCents);
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 320,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 320,
            child: Center(
              child: Text(
                'No se pudieron cargar los productos: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final availableProducts =
            (snapshot.data ?? [])
                .where((product) => product.isActive)
                .where(
                  (product) =>
                      !widget.excludedProductIds.contains(product.id) ||
                      product.id == _selectedProduct?.id,
                )
                .toList()
              ..sort(
                (first, second) => first.name.toLowerCase().compareTo(
                  second.name.toLowerCase(),
                ),
              );

        if (availableProducts.isEmpty) {
          return const SizedBox(height: 320, child: _NoAvailableProducts());
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, keyboardInset + 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Editar producto' : 'Agregar producto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona el producto recibido y captura su costo de compra.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _selectedProduct?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  hint: const Text('Selecciona un producto'),
                  items: availableProducts.map((product) {
                    return DropdownMenuItem<int>(
                      value: product.id,
                      child: Text(
                        '${product.name} · Stock ${product.currentStock}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (productId) {
                    if (productId == null) {
                      return;
                    }

                    Product? selectedProduct;

                    for (final product in availableProducts) {
                      if (product.id == productId) {
                        selectedProduct = product;
                        break;
                      }
                    }

                    if (selectedProduct == null) {
                      return;
                    }

                    final productChanged =
                        selectedProduct.id != _selectedProduct?.id;

                    setState(() {
                      _selectedProduct = selectedProduct;

                      if (productChanged) {
                        _unitCostController.text = _centsToMoneyText(
                          selectedProduct!.purchasePriceCents,
                        );
                      }
                    });
                  },
                  validator: (productId) {
                    if (productId == null) {
                      return 'Selecciona un producto';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad recibida',
                    hintText: 'Ej. 10',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');

                    if (quantity == null) {
                      return 'Escribe una cantidad válida';
                    }

                    if (quantity <= 0) {
                      return 'La cantidad debe ser mayor que cero';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario',
                    hintText: '0.00',
                    prefixText: r'$ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe el costo unitario';
                    }

                    final costCents = _moneyTextToCents(value);

                    if (costCents < 0) {
                      return 'El costo no puede ser negativo';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveItem,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _isEditing ? 'Guardar cambios' : 'Agregar a la compra',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveItem() {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _selectedProduct == null) {
      return;
    }

    final quantity = int.parse(_quantityController.text.trim());

    final unitCostCents = _moneyTextToCents(_unitCostController.text);

    Navigator.pop(
      context,
      _PurchaseDraftItem(
        product: _selectedProduct!,
        quantity: quantity,
        unitCostCents: unitCostCents,
      ),
    );
  }

  int _moneyTextToCents(String value) {
    var cleaned = value.trim();

    if (cleaned.isEmpty) {
      return 0;
    }

    cleaned = cleaned.replaceAll(RegExp(r'[^\d,.-]'), '');

    if (cleaned.contains(',') && !cleaned.contains('.')) {
      cleaned = cleaned.replaceAll(',', '.');
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }

    final amount = double.tryParse(cleaned) ?? 0;

    return (amount * 100).round();
  }

  String _centsToMoneyText(int cents) {
    return (cents / 100).toStringAsFixed(2);
  }
}

class _NoAvailableProducts extends StatelessWidget {
  const _NoAvailableProducts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 58,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay productos disponibles',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              'Crea productos activos o elimina uno de la compra para seleccionarlo nuevamente.',
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
