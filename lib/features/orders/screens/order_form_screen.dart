import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/local/app_database.dart';
import 'order_detail_screen.dart';

class OrderFormScreen extends StatefulWidget {
  final AppDatabase database;
  final int? initialCustomerId;

  final CustomerOrderWithCustomer? orderToEdit;
  final List<CustomerOrderItemDetail> initialItems;

  const OrderFormScreen({
    super.key,
    required this.database,
    this.initialCustomerId,
    this.orderToEdit,
    this.initialItems = const <CustomerOrderItemDetail>[],
  });

  bool get isEditing {
    return orderToEdit != null;
  }

  bool get hasFulfilledItems {
    return initialItems.any((item) => item.orderItem.quantityFulfilled > 0);
  }

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  late final Stream<List<Customer>> _customersStream;
  late final Stream<List<Product>> _productsStream;

  final List<_OrderLineDraft> _lines = [];

  int? _selectedCustomerId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _selectedCustomerId =
        widget.orderToEdit?.order.customerId ?? widget.initialCustomerId;

    _notesController.text = widget.orderToEdit?.order.notes ?? '';

    _customersStream = widget.database.watchAllCustomers(
      includeInactive: widget.isEditing,
    );

    _productsStream = widget.database.watchInventoryProducts(
      includeInactive: widget.isEditing,
    );

    for (final detail in widget.initialItems) {
      _lines.add(
        _OrderLineDraft(
          product: detail.product,
          quantity: detail.orderItem.quantityRequested,
          notes: detail.orderItem.notes,
          fulfilledQuantity: detail.orderItem.quantityFulfilled,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Editar pedido #${widget.orderToEdit!.order.id}'
              : 'Nuevo pedido',
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Customer>>(
        stream: _customersStream,
        builder: (context, customerSnapshot) {
          if (customerSnapshot.connectionState == ConnectionState.waiting &&
              !customerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (customerSnapshot.hasError) {
            return _LoadError(
              message:
                  'No se pudieron cargar los clientes: ${customerSnapshot.error}',
            );
          }

          final customers = customerSnapshot.data ?? const <Customer>[];

          return StreamBuilder<List<Product>>(
            stream: _productsStream,
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting &&
                  !productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (productSnapshot.hasError) {
                return _LoadError(
                  message:
                      'No se pudieron cargar los productos: ${productSnapshot.error}',
                );
              }

              final products = productSnapshot.data ?? const <Product>[];

              if (customers.isEmpty) {
                return const _MissingDataState(
                  icon: Icons.people_outline,
                  title: 'No hay clientes activos',
                  message:
                      'Registra o reactiva un cliente antes de crear un pedido.',
                );
              }

              if (products.isEmpty) {
                return const _MissingDataState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No hay productos activos',
                  message:
                      'Registra o reactiva productos antes de crear un pedido.',
                );
              }

              return _buildForm(customers: customers, products: products);
            },
          );
        },
      ),
    );
  }

  Widget _buildForm({
    required List<Customer> customers,
    required List<Product> products,
  }) {
    final availableCustomerIds = customers.map((item) => item.id).toSet();

    if (_selectedCustomerId != null &&
        !availableCustomerIds.contains(_selectedCustomerId)) {
      _selectedCustomerId = null;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                        icon: Icons.person_outline,
                        title: 'Cliente y observaciones',
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        key: ValueKey(_selectedCustomerId),
                        initialValue: _selectedCustomerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Cliente',
                          prefixIcon: const Icon(Icons.people_outline),
                          helperText:
                              widget.isEditing && widget.hasFulfilledItems
                              ? 'El cliente no puede cambiarse porque ya hay productos surtidos.'
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        items: customers.map((customer) {
                          return DropdownMenuItem<int>(
                            value: customer.id,
                            child: Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged:
                            _isSaving ||
                                (widget.isEditing && widget.hasFulfilledItems)
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCustomerId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Selecciona el cliente del pedido.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notas generales',
                          hintText:
                              'Fecha prometida, instrucciones o referencias del pedido.',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionTitle(
                              icon: Icons.shopping_basket_outlined,
                              title: 'Productos solicitados',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    _addProduct(products);
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar producto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'El pedido no cambia existencias. El inventario aumentará únicamente cuando los productos surtidos se conviertan en una compra.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_lines.isEmpty)
                        const _EmptyLinesState()
                      else
                        ...List.generate(_lines.length, (index) {
                          final line = _lines[index];

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _lines.length - 1 ? 0 : 12,
                            ),
                            child: _OrderLineCard(
                              line: line,
                              position: index + 1,
                              enabled: !_isSaving,
                              onRemove: () {
                                _removeLine(index);
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Guardando pedido...'
                        : widget.isEditing
                        ? 'Guardar cambios'
                        : 'Registrar pedido',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct(List<Product> products) async {
    final selectedIds = _lines.map((line) => line.product.id).toSet();
    final availableProducts = products
        .where(
          (product) => product.isActive && !selectedIds.contains(product.id),
        )
        .toList();

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya agregaste todos los productos disponibles.'),
        ),
      );
      return;
    }

    final product = await _showProductPicker(availableProducts);

    if (product == null || !mounted) {
      return;
    }

    setState(() {
      _lines.add(_OrderLineDraft(product: product));
    });
  }

  Future<Product?> _showProductPicker(List<Product> products) async {
    final searchController = TextEditingController();

    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final search = searchController.text.trim().toLowerCase();
            final filteredProducts = products.where((product) {
              final values = [
                product.name,
                product.sku ?? '',
              ].join(' ').toLowerCase();

              return search.isEmpty || values.contains(search);
            }).toList();

            return AlertDialog(
              title: const Text('Seleccionar producto'),
              content: SizedBox(
                width: 620,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Buscar producto',
                        hintText: 'Nombre o SKU',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron productos.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredProducts.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final sku = product.sku?.trim();

                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(product.name),
                                  subtitle: Text(
                                    [
                                      if (sku != null && sku.isNotEmpty)
                                        'SKU: $sku',
                                      'Existencia actual: ${product.currentStock}',
                                    ].join(' · '),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(dialogContext, product);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    return selectedProduct;
  }

  void _removeLine(int index) {
    final line = _lines[index];

    if (line.fulfilledQuantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puedes quitar ${line.product.name} porque ya tiene '
            '${line.fulfilledQuantity} unidades surtidas.',
          ),
        ),
      );

      return;
    }

    final removedLine = _lines.removeAt(index);
    removedLine.dispose();

    setState(() {});
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto al pedido.')),
      );
      return;
    }

    final inputs = <CustomerOrderLineInput>[];

    for (final line in _lines) {
      final quantity = int.tryParse(line.quantityController.text.trim());

      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Escribe una cantidad válida para ${line.product.name}.',
            ),
          ),
        );
        return;
      }

      if (quantity < line.fulfilledQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La cantidad de ${line.product.name} no puede ser menor '
              'que las ${line.fulfilledQuantity} unidades que ya fueron surtidas.',
            ),
          ),
        );

        return;
      }

      inputs.add(
        CustomerOrderLineInput(
          productId: line.product.id,
          quantity: quantity,
          notes: line.notesController.text,
        ),
      );
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        await widget.database.updateCustomerOrder(
          orderId: widget.orderToEdit!.order.id,
          customerId: _selectedCustomerId!,
          items: inputs,
          notes: _notesController.text,
        );

        if (!mounted) {
          return;
        }

        Navigator.pop(context, true);
      } else {
        final orderId = await widget.database.createCustomerOrder(
          customerId: _selectedCustomerId!,
          items: inputs,
          notes: _notesController.text,
        );

        if (!mounted) {
          return;
        }

        await Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailScreen(database: widget.database, orderId: orderId),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'No se pudo actualizar el pedido: $error'
                : 'No se pudo registrar el pedido: $error',
          ),
        ),
      );
    }
  }
}

class _OrderLineDraft {
  final Product product;
  final int fulfilledQuantity;

  final TextEditingController quantityController;
  final TextEditingController notesController;

  _OrderLineDraft({
    required this.product,
    int quantity = 1,
    String? notes,
    this.fulfilledQuantity = 0,
  }) : quantityController = TextEditingController(text: quantity.toString()),
       notesController = TextEditingController(text: notes ?? '');

  void dispose() {
    quantityController.dispose();
    notesController.dispose();
  }
}

class _OrderLineCard extends StatelessWidget {
  final _OrderLineDraft line;
  final int position;
  final bool enabled;
  final VoidCallback onRemove;

  const _OrderLineCard({
    required this.line,
    required this.position,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sku = line.product.sku?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (sku != null && sku.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'SKU: $sku',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      'Existencia actual: ${line.product.currentStock}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFBE123C),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final quantityField = TextFormField(
                controller: line.quantityController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Cantidad solicitada',
                  prefixIcon: const Icon(Icons.numbers),
                  helperText: line.fulfilledQuantity > 0
                      ? 'Ya surtido: ${line.fulfilledQuantity}'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');

                  if (quantity == null || quantity <= 0) {
                    return 'Cantidad inválida.';
                  }

                  if (quantity < line.fulfilledQuantity) {
                    return 'Mínimo: ${line.fulfilledQuantity}.';
                  }

                  return null;
                },
              );

              final notesField = TextFormField(
                controller: line.notesController,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota del producto',
                  hintText: 'Medida, color, marca o presentación.',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
              );

              if (constraints.maxWidth >= 620) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 210, child: quantityField),
                    const SizedBox(width: 14),
                    Expanded(child: notesField),
                  ],
                );
              }

              return Column(
                children: [
                  quantityField,
                  const SizedBox(height: 12),
                  notesField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _EmptyLinesState extends StatelessWidget {
  const _EmptyLinesState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.playlist_add_outlined, size: 54, color: Color(0xFF64748B)),
          SizedBox(height: 12),
          Text(
            'Agrega los productos que solicitó el cliente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MissingDataState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MissingDataState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 68, color: const Color(0xFF64748B)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;

  const _LoadError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
