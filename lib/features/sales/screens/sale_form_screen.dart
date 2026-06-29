import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class SaleFormScreen extends StatefulWidget {
  final AppDatabase database;

  const SaleFormScreen({super.key, required this.database});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _discountController = TextEditingController(text: '0.00');

  final List<_SaleDraftItem> _items = [];

  String _paymentMethod = 'cash';
  bool _isSaving = false;

  int get _subtotalCents {
    return _items.fold<int>(0, (total, item) => total + item.subtotalCents);
  }

  int get _discountCents {
    return _tryMoneyTextToCents(_discountController.text) ?? 0;
  }

  int get _totalCents {
    final total = _subtotalCents - _discountCents;

    return total < 0 ? 0 : total;
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _discountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Nueva venta'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _SaleBottomBar(
        subtotalCents: _subtotalCents,
        discountCents: _discountCents,
        totalCents: _totalCents,
        itemCount: _items.length,
        isSaving: _isSaving,
        onSave: _items.isEmpty ? null : _saveSale,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
              children: [
                _SaleSectionCard(
                  title: 'Datos de la venta',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    TextFormField(
                      controller: _customerNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        hintText: 'Opcional · Público general',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                        prefixIcon: Icon(Icons.payment_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Efectivo'),
                        ),
                        DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transferencia'),
                        ),
                        DropdownMenuItem(
                          value: 'mixed',
                          child: Text('Pago mixto'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _paymentMethod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Descuento',
                        hintText: '0.00',
                        prefixText: r'$ ',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Escribe el descuento o utiliza 0';
                        }

                        final discountCents = _tryMoneyTextToCents(value);

                        if (discountCents == null) {
                          return 'Escribe un descuento válido';
                        }

                        if (discountCents < 0) {
                          return 'El descuento no puede ser negativo';
                        }

                        if (discountCents > _subtotalCents) {
                          return 'El descuento no puede superar el subtotal';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SaleSectionCard(
                  title: 'Productos vendidos',
                  icon: Icons.shopping_cart_outlined,
                  trailing: OutlinedButton.icon(
                    onPressed: () => _openItemSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar producto'),
                  ),
                  children: [
                    if (_items.isEmpty)
                      _EmptySaleItems(onAddProduct: () => _openItemSheet())
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < _items.length;
                            index++
                          ) ...[
                            _SaleItemCard(
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

  Future<void> _openItemSheet({_SaleDraftItem? item, int? index}) async {
    final excludedProductIds = _items
        .map((currentItem) => currentItem.product.id)
        .toSet();

    if (item != null) {
      excludedProductIds.remove(item.product.id);
    }

    final result = await showModalBottomSheet<_SaleDraftItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) {
        return _SaleItemSheet(
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
            if (!mounted) {
              return;
            }

            final safeIndex = index.clamp(0, _items.length);

            setState(() {
              _items.insert(safeIndex, removedItem);
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveSale() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto a la venta.'),
        ),
      );

      return;
    }

    final discountCents = _tryMoneyTextToCents(_discountController.text);

    if (discountCents == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saleId = await widget.database.createSale(
        customerName: _customerNameController.text,
        paymentMethod: _paymentMethod,
        discountCents: discountCents,
        items: _items
            .map(
              (item) => SaleLineInput(
                productId: item.product.id,
                quantity: item.quantity,
                unitPriceCents: item.unitPriceCents,
              ),
            )
            .toList(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, saleId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la venta: $error')),
      );
    }
  }
}

class _SaleDraftItem {
  final Product product;
  final int quantity;
  final int unitPriceCents;

  const _SaleDraftItem({
    required this.product,
    required this.quantity,
    required this.unitPriceCents,
  });

  int get subtotalCents {
    return quantity * unitPriceCents;
  }
}

class _SaleSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SaleSectionCard({
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFFC2410C)),
                ),
                const SizedBox(width: 12),
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

class _EmptySaleItems extends StatelessWidget {
  final VoidCallback onAddProduct;

  const _EmptySaleItems({required this.onAddProduct});

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
              color: Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_shopping_cart_outlined,
              color: Color(0xFFC2410C),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Agrega productos a la venta',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Selecciona un producto con existencias, indica la cantidad y su precio.',
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

class _SaleItemCard extends StatelessWidget {
  final _SaleDraftItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SaleItemCard({
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
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFC2410C),
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
                    _SaleInformationChip(
                      icon: Icons.numbers_outlined,
                      label: 'Cantidad: ${item.quantity}',
                    ),
                    _SaleInformationChip(
                      icon: Icons.payments_outlined,
                      label: 'Precio: ${formatCents(item.unitPriceCents)}',
                    ),
                    _SaleInformationChip(
                      icon: Icons.inventory_outlined,
                      label: 'Stock: ${item.product.currentStock}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Subtotal: ${formatCents(item.subtotalCents)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFC2410C),
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

class _SaleInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SaleInformationChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFC2410C).withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9A3412)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A3412),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleBottomBar extends StatelessWidget {
  final int subtotalCents;
  final int discountCents;
  final int totalCents;
  final int itemCount;
  final bool isSaving;
  final VoidCallback? onSave;

  const _SaleBottomBar({
    required this.subtotalCents,
    required this.discountCents,
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
            final isWide = constraints.maxWidth >= 650;

            final totals = Column(
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
                const SizedBox(height: 3),
                Text('Subtotal: ${formatCents(subtotalCents)}'),
                Text(
                  'Descuento: ${formatCents(discountCents)}',
                  style: const TextStyle(color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Total: ${formatCents(totalCents)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF15803D),
                    fontWeight: FontWeight.w900,
                  ),
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
                  : const Icon(Icons.point_of_sale_outlined),
              label: Text(isSaving ? 'Registrando...' : 'Registrar venta'),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: totals),
                  const SizedBox(width: 20),
                  saveButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [totals, const SizedBox(height: 12), saveButton],
            );
          },
        ),
      ),
    );
  }
}

class _SaleItemSheet extends StatefulWidget {
  final AppDatabase database;
  final _SaleDraftItem? initialItem;
  final Set<int> excludedProductIds;

  const _SaleItemSheet({
    required this.database,
    required this.excludedProductIds,
    this.initialItem,
  });

  @override
  State<_SaleItemSheet> createState() => _SaleItemSheetState();
}

class _SaleItemSheetState extends State<_SaleItemSheet> {
  final _formKey = GlobalKey<FormState>();

  late final Stream<List<Product>> _productsStream;

  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  Product? _selectedProduct;

  bool get _isEditing {
    return widget.initialItem != null;
  }

  @override
  void initState() {
    super.initState();

    _productsStream = widget.database.watchAllProducts();

    final initialItem = widget.initialItem;

    if (initialItem != null) {
      _selectedProduct = initialItem.product;
      _quantityController.text = initialItem.quantity.toString();
      _unitPriceController.text = _centsToMoneyText(initialItem.unitPriceCents);
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();

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
                .where((product) => product.currentStock > 0)
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
          return const SizedBox(height: 320, child: _NoProductsWithStock());
        }

        Product? currentSelectedProduct;

        for (final product in availableProducts) {
          if (product.id == _selectedProduct?.id) {
            currentSelectedProduct = product;
            break;
          }
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
                  'Selecciona un producto con existencias y captura la cantidad vendida.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  key: ValueKey(currentSelectedProduct?.id),
                  initialValue: currentSelectedProduct?.id,
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
                        _quantityController.text = '1';
                        _unitPriceController.text = _centsToMoneyText(
                          selectedProduct!.salePriceCents,
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
                if (_selectedProduct != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Existencias disponibles: ${_selectedProduct!.currentStock}',
                      style: const TextStyle(
                        color: Color(0xFF1E4E79),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad vendida',
                    hintText: 'Ej. 2',
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

                    final product = _selectedProduct;

                    if (product != null && quantity > product.currentStock) {
                      return 'Solo hay ${product.currentStock} unidades disponibles';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario',
                    hintText: '0.00',
                    prefixText: r'$ ',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe el precio unitario';
                    }

                    final priceCents = _tryMoneyTextToCents(value);

                    if (priceCents == null) {
                      return 'Escribe un precio válido';
                    }

                    if (priceCents < 0) {
                      return 'El precio no puede ser negativo';
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
                      _isEditing ? 'Guardar cambios' : 'Agregar a la venta',
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

    final unitPriceCents = _tryMoneyTextToCents(_unitPriceController.text);

    if (unitPriceCents == null) {
      return;
    }

    Navigator.pop(
      context,
      _SaleDraftItem(
        product: _selectedProduct!,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
      ),
    );
  }
}

class _NoProductsWithStock extends StatelessWidget {
  const _NoProductsWithStock();

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
              'No hay productos con existencias',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              'Registra una compra o ajusta el inventario antes de realizar la venta.',
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

int? _tryMoneyTextToCents(String value) {
  var cleaned = value.trim();

  if (cleaned.isEmpty) {
    return null;
  }

  cleaned = cleaned.replaceAll(RegExp(r'[^\d,.-]'), '');

  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.' || cleaned == ',') {
    return null;
  }

  if (cleaned.contains(',') && !cleaned.contains('.')) {
    cleaned = cleaned.replaceAll(',', '.');
  } else {
    cleaned = cleaned.replaceAll(',', '');
  }

  final amount = double.tryParse(cleaned);

  if (amount == null) {
    return null;
  }

  return (amount * 100).round();
}

String _centsToMoneyText(int cents) {
  return (cents / 100).toStringAsFixed(2);
}
