import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import '../../purchases/screens/purchase_detail_screen.dart';

class FulfillOrdersScreen extends StatefulWidget {
  final AppDatabase database;

  const FulfillOrdersScreen({super.key, required this.database});

  @override
  State<FulfillOrdersScreen> createState() => _FulfillOrdersScreenState();
}

class _FulfillOrdersScreenState extends State<FulfillOrdersScreen> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<int, _FulfillmentDraft> _drafts = {};

  late Future<_FulfillmentPageData> _dataFuture;

  int? _selectedSupplierId;
  bool _draftsInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    _noteController.dispose();

    for (final draft in _drafts.values) {
      draft.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Surtir pedidos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_FulfillmentPageData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _LoadError(
              message:
                  'No se pudieron cargar los productos pendientes: '
                  '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final data = snapshot.data;

          if (data == null) {
            return _LoadError(
              message: 'No se pudo cargar la información.',
              onRetry: _reload,
            );
          }

          _initializeDrafts(data.pendingItems);

          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(_FulfillmentPageData data) {
    if (data.pendingItems.isEmpty) {
      return const _EmptyPendingState();
    }

    final availableSupplierIds = data.suppliers.map((item) => item.id).toSet();

    if (_selectedSupplierId != null &&
        !availableSupplierIds.contains(_selectedSupplierId)) {
      _selectedSupplierId = null;
    }

    final visibleItems = _filterItems(data.pendingItems);
    final selectedCount = _drafts.values
        .where((draft) => draft.selected)
        .length;
    final selectedTotal = _calculateSelectedTotal();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _PurchaseHeaderCard(
                    suppliers: data.suppliers,
                    selectedSupplierId: _selectedSupplierId,
                    noteController: _noteController,
                    enabled: !_isSaving,
                    onSupplierChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _SelectionSummaryCard(
                    totalPendingLines: data.pendingItems.length,
                    selectedLines: selectedCount,
                    totalCents: selectedTotal,
                    onSelectAllVisible: visibleItems.isEmpty
                        ? null
                        : () {
                            _setVisibleSelection(visibleItems, true);
                          },
                    onClearSelection: selectedCount == 0
                        ? null
                        : () {
                            _setAllSelection(false);
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar producto o cliente',
                      hintText: 'Producto, SKU, cliente o número de pedido',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visibleItems.isEmpty)
                    const _NoSearchResults()
                  else
                    ...visibleItems.map((item) {
                      final draft = _drafts[item.orderItem.id]!;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingOrderItemCard(
                          detail: item,
                          draft: draft,
                          enabled: !_isSaving,
                          onChanged: _refresh,
                        ),
                      );
                    }),
                ],
              ),
            ),
            _BottomActionBar(
              selectedCount: selectedCount,
              totalCents: selectedTotal,
              isSaving: _isSaving,
              onConfirm: selectedCount == 0
                  ? null
                  : () => _createPurchase(data),
            ),
          ],
        ),
      ),
    );
  }

  Future<_FulfillmentPageData> _loadData() async {
    final pendingItems = await widget.database.getPendingCustomerOrderItems();
    final suppliers = await widget.database.watchSuppliers().first;

    return _FulfillmentPageData(
      pendingItems: pendingItems,
      suppliers: suppliers,
    );
  }

  void _initializeDrafts(List<PendingCustomerOrderItemDetail> items) {
    if (_draftsInitialized) {
      return;
    }

    for (final detail in items) {
      final draft = _FulfillmentDraft(
        quantity: detail.pendingQuantity,
        unitCostCents: detail.product.purchasePriceCents,
      );

      draft.quantityController.addListener(_refresh);
      draft.costController.addListener(_refresh);
      _drafts[detail.orderItem.id] = draft;
    }

    _draftsInitialized = true;
  }

  List<PendingCustomerOrderItemDetail> _filterItems(
    List<PendingCustomerOrderItemDetail> items,
  ) {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) {
      return items;
    }

    return items.where((detail) {
      final values = [
        detail.order.id.toString(),
        detail.customer.name,
        detail.customer.phone ?? '',
        detail.product.name,
        detail.product.sku ?? '',
        detail.product.barcode ?? '',
        detail.orderItem.notes ?? '',
      ].join(' ').toLowerCase();

      return values.contains(search);
    }).toList();
  }

  int _calculateSelectedTotal() {
    var total = 0;

    for (final draft in _drafts.values) {
      if (!draft.selected) {
        continue;
      }

      final quantity = int.tryParse(draft.quantityController.text.trim()) ?? 0;
      final cost = _parseMoneyToCents(draft.costController.text) ?? 0;
      total += quantity * cost;
    }

    return total;
  }

  void _setVisibleSelection(
    List<PendingCustomerOrderItemDetail> items,
    bool selected,
  ) {
    setState(() {
      for (final detail in items) {
        _drafts[detail.orderItem.id]?.selected = selected;
      }
    });
  }

  void _setAllSelection(bool selected) {
    setState(() {
      for (final draft in _drafts.values) {
        draft.selected = selected;
      }
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _reload() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }

    setState(() {
      _drafts.clear();
      _draftsInitialized = false;
      _selectedSupplierId = null;
      _dataFuture = _loadData();
    });
  }

  Future<void> _createPurchase(_FulfillmentPageData data) async {
    if (_isSaving) {
      return;
    }

    final supplierId = _selectedSupplierId;

    if (supplierId == null) {
      _showMessage('Selecciona el proveedor de la compra.');
      return;
    }

    final itemsById = {
      for (final item in data.pendingItems) item.orderItem.id: item,
    };

    final inputs = <OrderFulfillmentLineInput>[];

    for (final entry in _drafts.entries) {
      final draft = entry.value;

      if (!draft.selected) {
        continue;
      }

      final detail = itemsById[entry.key];

      if (detail == null) {
        _showMessage(
          'Uno de los productos seleccionados ya no está pendiente.',
        );
        return;
      }

      final quantity = int.tryParse(draft.quantityController.text.trim());

      if (quantity == null || quantity <= 0) {
        _showMessage(
          'Escribe una cantidad válida para "${detail.product.name}".',
        );
        return;
      }

      if (quantity > detail.pendingQuantity) {
        _showMessage(
          'La cantidad de "${detail.product.name}" no puede superar '
          '${detail.pendingQuantity}.',
        );
        return;
      }

      final unitCostCents = _parseMoneyToCents(draft.costController.text);

      if (unitCostCents == null || unitCostCents < 0) {
        _showMessage('Escribe un costo válido para "${detail.product.name}".');
        return;
      }

      inputs.add(
        OrderFulfillmentLineInput(
          orderItemId: detail.orderItem.id,
          quantity: quantity,
          unitCostCents: unitCostCents,
        ),
      );
    }

    if (inputs.isEmpty) {
      _showMessage('Selecciona al menos un producto.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.shopping_cart_checkout_outlined,
            color: Color(0xFF15803D),
            size: 42,
          ),
          title: const Text('Crear compra'),
          content: Text(
            'Se creará una compra con ${inputs.length} '
            '${inputs.length == 1 ? 'partida seleccionada' : 'partidas seleccionadas'} '
            'por un total de ${formatCents(_calculateSelectedTotal())}.\n\n'
            'El inventario y la caja se actualizarán al confirmar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Crear compra'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final purchaseId = await widget.database
          .createPurchaseFromOrderFulfillment(
            supplierId: supplierId,
            note: _noteController.text,
            items: inputs,
          );

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseDetailScreen(
            database: widget.database,
            purchaseId: purchaseId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage('No se pudo crear la compra: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _parseMoneyToCents(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    final amount = double.tryParse(normalized);

    if (amount == null || !amount.isFinite) {
      return null;
    }

    return (amount * 100).round();
  }
}

class _FulfillmentPageData {
  final List<PendingCustomerOrderItemDetail> pendingItems;
  final List<Supplier> suppliers;

  const _FulfillmentPageData({
    required this.pendingItems,
    required this.suppliers,
  });
}

class _FulfillmentDraft {
  bool selected = false;
  final TextEditingController quantityController;
  final TextEditingController costController;

  _FulfillmentDraft({required int quantity, required int unitCostCents})
    : quantityController = TextEditingController(text: quantity.toString()),
      costController = TextEditingController(
        text: (unitCostCents / 100).toStringAsFixed(2),
      );

  void dispose() {
    quantityController.dispose();
    costController.dispose();
  }
}

class _PurchaseHeaderCard extends StatelessWidget {
  final List<Supplier> suppliers;
  final int? selectedSupplierId;
  final TextEditingController noteController;
  final bool enabled;
  final ValueChanged<int?> onSupplierChanged;

  const _PurchaseHeaderCard({
    required this.suppliers,
    required this.selectedSupplierId,
    required this.noteController,
    required this.enabled,
    required this.onSupplierChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos de la compra',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            if (suppliers.isEmpty)
              const _NoSuppliersWarning()
            else
              DropdownButtonFormField<int>(
                initialValue: selectedSupplierId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Proveedor',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                  border: OutlineInputBorder(),
                ),
                items: suppliers.map((supplier) {
                  return DropdownMenuItem<int>(
                    value: supplier.id,
                    child: Text(
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: enabled ? onSupplierChanged : null,
              ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              enabled: enabled,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota de la compra',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  final int totalPendingLines;
  final int selectedLines;
  final int totalCents;
  final VoidCallback? onSelectAllVisible;
  final VoidCallback? onClearSelection;

  const _SelectionSummaryCard({
    required this.totalPendingLines,
    required this.selectedLines,
    required this.totalCents,
    required this.onSelectAllVisible,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEFF6FF),
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SummaryValue(
              label: 'Pendientes',
              value: totalPendingLines.toString(),
            ),
            _SummaryValue(
              label: 'Seleccionados',
              value: selectedLines.toString(),
            ),
            _SummaryValue(
              label: 'Total estimado',
              value: formatCents(totalCents),
            ),
            OutlinedButton.icon(
              onPressed: onSelectAllVisible,
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Seleccionar visibles'),
            ),
            TextButton(
              onPressed: onClearSelection,
              child: const Text('Limpiar selección'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOrderItemCard extends StatelessWidget {
  final PendingCustomerOrderItemDetail detail;
  final _FulfillmentDraft draft;
  final bool enabled;
  final VoidCallback onChanged;

  const _PendingOrderItemCard({
    required this.detail,
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final notes = detail.orderItem.notes?.trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: draft.selected,
                  onChanged: enabled
                      ? (value) {
                          draft.selected = value ?? false;
                          onChanged();
                        }
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.product.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Pedido #${detail.order.id} · ${detail.customer.name}',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Solicitado: ${detail.orderItem.quantityRequested} · '
                        'Ya surtido: ${detail.orderItem.quantityFulfilled} · '
                        'Pendiente: ${detail.pendingQuantity}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Nota: $notes',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final quantityField = TextField(
                  controller: draft.quantityController,
                  enabled: enabled && draft.selected,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Cantidad conseguida',
                    helperText: 'Máximo ${detail.pendingQuantity}',
                    prefixIcon: const Icon(Icons.numbers_outlined),
                    border: const OutlineInputBorder(),
                  ),
                );

                final costField = TextField(
                  controller: draft.costController,
                  enabled: enabled && draft.selected,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario',
                    prefixText: r'$ ',
                    prefixIcon: Icon(Icons.attach_money_outlined),
                    border: OutlineInputBorder(),
                  ),
                );

                if (constraints.maxWidth >= 620) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 14),
                      Expanded(child: costField),
                    ],
                  );
                }

                return Column(
                  children: [
                    quantityField,
                    const SizedBox(height: 14),
                    costField,
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

class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCents;
  final bool isSaving;
  final VoidCallback? onConfirm;

  const _BottomActionBar({
    required this.selectedCount,
    required this.totalCents,
    required this.isSaving,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$selectedCount seleccionados',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatCents(totalCents),
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isSaving ? null : onConfirm,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout_outlined),
                label: Text(isSaving ? 'Creando compra...' : 'Crear compra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSuppliersWarning extends StatelessWidget {
  const _NoSuppliersWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'No hay proveedores activos. Registra o reactiva uno antes de crear la compra.',
        style: TextStyle(color: Color(0xFF92400E)),
      ),
    );
  }
}

class _EmptyPendingState extends StatelessWidget {
  const _EmptyPendingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_outlined, size: 72, color: Color(0xFF15803D)),
            SizedBox(height: 16),
            Text(
              'No hay productos pendientes por surtir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('No hay resultados para esa búsqueda.')),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
