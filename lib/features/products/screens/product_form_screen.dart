import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';

class ProductFormScreen extends StatefulWidget {
  final AppDatabase database;
  final Product? product;

  const ProductFormScreen({
    super.key,
    required this.database,
    this.product,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _initialStockController = TextEditingController();
  final _minStockController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku ?? '';
      _barcodeController.text = product.barcode ?? '';
      _descriptionController.text = product.description ?? '';
      _purchasePriceController.text = _centsToMoneyText(product.purchasePriceCents);
      _salePriceController.text = _centsToMoneyText(product.salePriceCents);
      _minStockController.text = product.minStock.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _initialStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar producto' : 'Nuevo producto';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveProduct,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Guardando...' : 'Guardar producto'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Información general',
              icon: Icons.inventory_2_outlined,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    hintText: 'Ej. Coca-Cola 600 ml',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe el nombre del producto';
                    }

                    if (value.trim().length < 2) {
                      return 'El nombre es demasiado corto';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    hintText: 'Ej. REF-001',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Código de barras',
                    hintText: 'Opcional',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Notas o detalles del producto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Precios',
              icon: Icons.sell_outlined,
              children: [
                TextFormField(
                  controller: _purchasePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio de compra',
                    prefixText: r'$ ',
                    hintText: '0.00',
                  ),
                  validator: _validateMoney,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _salePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio de venta',
                    prefixText: r'$ ',
                    hintText: '0.00',
                  ),
                  validator: _validateMoney,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Inventario',
              icon: Icons.warehouse_outlined,
              children: [
                if (!_isEditing) ...[
                  TextFormField(
                    controller: _initialStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock inicial',
                      hintText: '0',
                    ),
                    validator: _validateInteger,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _minStockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock mínimo',
                    hintText: 'Ej. 5',
                  ),
                  validator: _validateInteger,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Para modificar la existencia actual usa “Ajustar stock” desde el detalle del producto.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String? _validateMoney(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final cents = _moneyTextToCents(value);

    if (cents < 0) {
      return 'El precio no puede ser negativo';
    }

    return null;
  }

  String? _validateInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = int.tryParse(value.trim());

    if (number == null) {
      return 'Escribe un número válido';
    }

    if (number < 0) {
      return 'No puede ser negativo';
    }

    return null;
  }

  Future<void> _saveProduct() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final purchasePriceCents = _moneyTextToCents(
        _purchasePriceController.text,
      );

      final salePriceCents = _moneyTextToCents(
        _salePriceController.text,
      );

      final minStock = _textToInt(_minStockController.text);

      if (_isEditing) {
        await widget.database.updateProductInfo(
          id: widget.product!.id,
          name: _nameController.text.trim(),
          sku: _optionalString(_skuController.text),
          barcode: _optionalString(_barcodeController.text),
          description: _optionalString(_descriptionController.text),
          purchasePriceCents: purchasePriceCents,
          salePriceCents: salePriceCents,
          minStock: minStock,
        );
      } else {
        final initialStock = _textToInt(_initialStockController.text);

        final productId = await widget.database.insertProduct(
          ProductsCompanion(
            name: Value(_nameController.text.trim()),
            sku: Value(_optionalString(_skuController.text)),
            barcode: Value(_optionalString(_barcodeController.text)),
            description: Value(_optionalString(_descriptionController.text)),
            purchasePriceCents: Value(purchasePriceCents),
            salePriceCents: Value(salePriceCents),
            minStock: Value(minStock),
          ),
        );

        if (initialStock > 0) {
          await widget.database.addInventoryMovement(
            productId: productId,
            type: 'manual_adjustment',
            quantity: initialStock,
            note: 'Stock inicial del producto',
          );
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $error'),
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

  String? _optionalString(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  int _textToInt(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  int _moneyTextToCents(String value) {
    var cleaned = value.trim();

    if (cleaned.isEmpty) return 0;

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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}