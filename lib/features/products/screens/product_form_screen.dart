import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../data/local/app_database.dart';
import '../../categories/screens/categories_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final AppDatabase database;
  final Product? product;

  const ProductFormScreen({super.key, required this.database, this.product});

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

  int? _selectedCategoryId;
  Uint8List? _imageBytes;
  bool _showInCatalog = true;
  bool _allowNegativeStock = false;
  bool _isSaving = false;
  bool _isProcessingImage = false;

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

      _purchasePriceController.text = _centsToMoneyText(
        product.purchasePriceCents,
      );

      _salePriceController.text = _centsToMoneyText(product.salePriceCents);

      _minStockController.text = product.minStock.toString();

      _selectedCategoryId = product.categoryId;

      _imageBytes = product.imageBytes;
      _showInCatalog = product.showInCatalog;
      _allowNegativeStock = product.allowNegativeStock;
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
          onPressed: _isSaving || _isProcessingImage ? null : _saveProduct,
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
          label: Text(_isSaving ? 'Guardando...' : 'Guardar producto'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
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
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del producto',
                        hintText: 'Ej. Taladro inalámbrico',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Escribe el nombre del producto.';
                        }

                        if (text.length < 2) {
                          return 'El nombre es demasiado corto.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final skuField = TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(
                            labelText: 'SKU',
                            hintText: 'Ej. REF-001',
                          ),
                        );

                        final barcodeField = TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Código de barras',
                            hintText: 'Opcional',
                          ),
                        );

                        if (constraints.maxWidth >= 600) {
                          return Row(
                            children: [
                              Expanded(child: skuField),
                              const SizedBox(width: 14),
                              Expanded(child: barcodeField),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            skuField,
                            const SizedBox(height: 14),
                            barcodeField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Descripción breve',
                        hintText:
                            'Características principales que aparecerán en el catálogo.',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Catálogo visual',
                  icon: Icons.storefront_outlined,
                  children: [
                    StreamBuilder<List<ProductCategory>>(
                      stream: widget.database.watchProductCategories(
                        includeInactive: true,
                      ),
                      builder: (context, snapshot) {
                        final categories =
                            snapshot.data ?? const <ProductCategory>[];

                        final selectedExists =
                            _selectedCategoryId == null ||
                            categories.any(
                              (category) => category.id == _selectedCategoryId,
                            );

                        if (!selectedExists) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedCategoryId = null;
                              });
                            }
                          });
                        }

                        return DropdownButtonFormField<int?>(
                          initialValue: selectedExists
                              ? _selectedCategoryId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sin categoría'),
                            ),
                            ...categories.map((category) {
                              return DropdownMenuItem<int?>(
                                value: category.id,
                                enabled:
                                    category.isActive ||
                                    category.id == _selectedCategoryId,
                                child: Text(
                                  category.isActive
                                      ? category.name
                                      : '${category.name} (inactiva)',
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _openCategories,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Administrar categorías'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ImageSelector(
                      imageBytes: _imageBytes,
                      isProcessing: _isProcessingImage,
                      onSelect: _selectImage,
                      onRemove: _imageBytes == null
                          ? null
                          : () {
                              setState(() {
                                _imageBytes = null;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showInCatalog,
                      onChanged: (value) {
                        setState(() {
                          _showInCatalog = value;
                        });
                      },
                      title: const Text(
                        'Mostrar en catálogo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'El producto aparecerá en la pantalla visual mientras también esté activo.',
                      ),
                      secondary: const Icon(Icons.visibility_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Precios',
                  icon: Icons.sell_outlined,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final purchaseField = TextFormField(
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
                        );

                        final saleField = TextFormField(
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
                        );

                        if (constraints.maxWidth >= 600) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: purchaseField),
                              const SizedBox(width: 14),
                              Expanded(child: saleField),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            purchaseField,
                            const SizedBox(height: 14),
                            saleField,
                          ],
                        );
                      },
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
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: _allowNegativeStock
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _allowNegativeStock
                              ? const Color(0xFFFED7AA)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SwitchListTile(
                        value: _allowNegativeStock,
                        onChanged: (value) {
                          final currentStock =
                              widget.product?.currentStock ?? 0;

                          if (!value && currentStock < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Primero ajusta el stock de '
                                  '${widget.product!.name} '
                                  'a cero o a una cantidad '
                                  'positiva.',
                                ),
                              ),
                            );

                            return;
                          }

                          setState(() {
                            _allowNegativeStock = value;
                          });
                        },
                        title: const Text(
                          'Permitir existencias negativas',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          _allowNegativeStock
                              ? 'Las ventas y ajustes podrán dejar el stock por debajo de cero.'
                              : 'Las ventas se bloquearán cuando no haya existencias suficientes.',
                        ),
                        secondary: Icon(
                          _allowNegativeStock
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.inventory_outlined,
                          color: _allowNegativeStock
                              ? const Color(0xFFC2410C)
                              : null,
                        ),
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Para modificar la existencia actual usa “Ajustar stock” desde el detalle del producto.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
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
      return 'No puede ser negativo.';
    }

    return null;
  }

  String? _validateInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = int.tryParse(value.trim());

    if (number == null) {
      return 'Escribe un número válido.';
    }

    if (number < 0) {
      return 'No puede ser negativo.';
    }

    return null;
  }

  Future<void> _openCategories() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(database: widget.database),
      ),
    );
  }

  Future<void> _selectImage() async {
    if (_isProcessingImage) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.single.path;

      if (path == null || path.trim().isEmpty) {
        throw StateError('No se pudo obtener la ruta de la imagen.');
      }

      setState(() {
        _isProcessingImage = true;
      });

      final originalBytes = await File(path).readAsBytes();

      final decoded = img.decodeImage(originalBytes);

      if (decoded == null) {
        throw const FormatException(
          'El archivo seleccionado no es una imagen válida.',
        );
      }

      final oriented = img.bakeOrientation(decoded);

      const maxDimension = 1200;

      img.Image resized = oriented;

      if (oriented.width > maxDimension || oriented.height > maxDimension) {
        if (oriented.width >= oriented.height) {
          resized = img.copyResize(oriented, width: maxDimension);
        } else {
          resized = img.copyResize(oriented, height: maxDimension);
        }
      }

      final compressed = Uint8List.fromList(
        img.encodeJpg(resized, quality: 82),
      );

      const maxBytes = 3 * 1024 * 1024;

      if (compressed.lengthInBytes > maxBytes) {
        throw StateError(
          'La imagen sigue siendo demasiado grande después de comprimirla.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = compressed;
        _isProcessingImage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $error')),
      );
    }
  }

  Future<void> _saveProduct() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isSaving || _isProcessingImage) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final purchasePriceCents = _moneyTextToCents(
        _purchasePriceController.text,
      );

      final salePriceCents = _moneyTextToCents(_salePriceController.text);

      final minStock = _textToInt(_minStockController.text);

      if (_isEditing) {
        await widget.database.updateProductInfo(
          id: widget.product!.id,
          name: _nameController.text.trim(),
          sku: _optionalString(_skuController.text),
          barcode: _optionalString(_barcodeController.text),
          description: _optionalString(_descriptionController.text),
          categoryId: _selectedCategoryId,
          imageBytes: _imageBytes,
          showInCatalog: _showInCatalog,
          allowNegativeStock: _allowNegativeStock,
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
            categoryId: Value(_selectedCategoryId),
            imageBytes: Value(_imageBytes),
            showInCatalog: Value(_showInCatalog),
            allowNegativeStock: Value(_allowNegativeStock),
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

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
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

class _ImageSelector extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isProcessing;
  final VoidCallback onSelect;
  final VoidCallback? onRemove;

  const _ImageSelector({
    required this.imageBytes,
    required this.isProcessing,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen del producto',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: isProcessing
              ? const Center(child: CircularProgressIndicator())
              : imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.cover)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 64,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Todavía no hay una imagen',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: isProcessing ? null : onSelect,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                imageBytes == null ? 'Seleccionar imagen' : 'Cambiar imagen',
              ),
            ),
            if (onRemove != null)
              OutlinedButton.icon(
                onPressed: isProcessing ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar imagen'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Se aceptan JPG, PNG y WEBP. La imagen se comprime y se guarda dentro del respaldo de la base de datos.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
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
