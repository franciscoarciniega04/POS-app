import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import 'supplier_form_screen.dart';

enum _SupplierFilter { active, inactive, all }

enum _SupplierAction { edit, toggleStatus }

class SuppliersScreen extends StatefulWidget {
  final AppDatabase database;

  const SuppliersScreen({super.key, required this.database});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final Stream<List<Supplier>> _suppliersStream;

  String _searchText = '';
  _SupplierFilter _selectedFilter = _SupplierFilter.active;

  @override
  void initState() {
    super.initState();

    _suppliersStream = widget.database.watchSuppliers(includeInactive: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Proveedores'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSupplierForm(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nuevo proveedor'),
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: _suppliersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _SupplierErrorState(message: snapshot.error.toString());
          }

          final suppliers = snapshot.data ?? [];

          final filteredSuppliers = suppliers
              .where(_matchesSelectedFilter)
              .where(_matchesSearch)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  _SuppliersSummary(suppliers: suppliers),
                  _SupplierFilters(
                    selectedFilter: _selectedFilter,
                    onChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                  _SupplierSearchBox(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: _buildContent(
                      allSuppliers: suppliers,
                      filteredSuppliers: filteredSuppliers,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required List<Supplier> allSuppliers,
    required List<Supplier> filteredSuppliers,
  }) {
    if (allSuppliers.isEmpty) {
      return _EmptySuppliersState(onCreateSupplier: () => _openSupplierForm());
    }

    if (filteredSuppliers.isEmpty) {
      return const _NoSuppliersFoundState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredSuppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final supplier = filteredSuppliers[index];

        return _SupplierCard(
          supplier: supplier,
          onEdit: () => _openSupplierForm(supplier: supplier),
          onToggleStatus: () => _confirmToggleStatus(supplier),
        );
      },
    );
  }

  bool _matchesSelectedFilter(Supplier supplier) {
    switch (_selectedFilter) {
      case _SupplierFilter.active:
        return supplier.isActive;

      case _SupplierFilter.inactive:
        return !supplier.isActive;

      case _SupplierFilter.all:
        return true;
    }
  }

  bool _matchesSearch(Supplier supplier) {
    if (_searchText.isEmpty) {
      return true;
    }

    final values = [
      supplier.name,
      supplier.contactName ?? '',
      supplier.phone ?? '',
      supplier.email ?? '',
      supplier.taxId ?? '',
      supplier.address ?? '',
    ];

    return values.any((value) => value.toLowerCase().contains(_searchText));
  }

  Future<void> _openSupplierForm({Supplier? supplier}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SupplierFormScreen(database: widget.database, supplier: supplier),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          supplier == null
              ? 'Proveedor creado correctamente.'
              : 'Proveedor actualizado correctamente.',
        ),
      ),
    );
  }

  Future<void> _confirmToggleStatus(Supplier supplier) async {
    final willActivate = !supplier.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            willActivate ? 'Reactivar proveedor' : 'Desactivar proveedor',
          ),
          content: Text(
            willActivate
                ? '¿Quieres volver a activar a "${supplier.name}"?'
                : '¿Quieres desactivar a "${supplier.name}"? Ya no aparecerá al registrar compras nuevas, pero conservará su historial.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(willActivate ? 'Reactivar' : 'Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.database.setSupplierActive(
        supplierId: supplier.id,
        isActive: willActivate,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willActivate
                ? '${supplier.name} fue reactivado.'
                : '${supplier.name} fue desactivado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    }
  }
}

class _SuppliersSummary extends StatelessWidget {
  final List<Supplier> suppliers;

  const _SuppliersSummary({required this.suppliers});

  @override
  Widget build(BuildContext context) {
    final activeCount = suppliers.where((supplier) => supplier.isActive).length;

    final inactiveCount = suppliers.length - activeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          final activeCard = _SupplierSummaryCard(
            title: 'Proveedores activos',
            value: activeCount.toString(),
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF15803D),
            backgroundColor: const Color(0xFFECFDF3),
          );

          final inactiveCard = _SupplierSummaryCard(
            title: 'Proveedores inactivos',
            value: inactiveCount.toString(),
            icon: Icons.pause_circle_outline,
            iconColor: const Color(0xFF64748B),
            backgroundColor: const Color(0xFFF1F5F9),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: activeCard),
                const SizedBox(width: 12),
                Expanded(child: inactiveCard),
              ],
            );
          }

          return Column(
            children: [activeCard, const SizedBox(height: 12), inactiveCard],
          );
        },
      ),
    );
  }
}

class _SupplierSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _SupplierSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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

class _SupplierFilters extends StatelessWidget {
  final _SupplierFilter selectedFilter;
  final ValueChanged<_SupplierFilter> onChanged;

  const _SupplierFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Activos'),
              selected: selectedFilter == _SupplierFilter.active,
              onSelected: (_) {
                onChanged(_SupplierFilter.active);
              },
            ),
            ChoiceChip(
              label: const Text('Inactivos'),
              selected: selectedFilter == _SupplierFilter.inactive,
              onSelected: (_) {
                onChanged(_SupplierFilter.inactive);
              },
            ),
            ChoiceChip(
              label: const Text('Todos'),
              selected: selectedFilter == _SupplierFilter.all,
              onSelected: (_) {
                onChanged(_SupplierFilter.all);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierSearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SupplierSearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, RFC, contacto o teléfono',
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

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final contactName = supplier.contactName?.trim();
    final phone = supplier.phone?.trim();
    final email = supplier.email?.trim();
    final taxId = supplier.taxId?.trim();

    final hasContactInformation =
        contactName?.isNotEmpty == true ||
        phone?.isNotEmpty == true ||
        email?.isNotEmpty == true;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: supplier.isActive
                      ? const Color(0xFFF0FDFA)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: supplier.isActive
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _SupplierStatusChip(isActive: supplier.isActive),
                      ],
                    ),
                    if (taxId?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'RFC: $taxId',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (hasContactInformation)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (contactName?.isNotEmpty == true)
                            _SupplierContactItem(
                              icon: Icons.person_outline,
                              text: contactName!,
                            ),
                          if (phone?.isNotEmpty == true)
                            _SupplierContactItem(
                              icon: Icons.phone_outlined,
                              text: phone!,
                            ),
                          if (email?.isNotEmpty == true)
                            _SupplierContactItem(
                              icon: Icons.email_outlined,
                              text: email!,
                            ),
                        ],
                      )
                    else
                      Text(
                        'Sin datos de contacto',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_SupplierAction>(
                tooltip: 'Opciones',
                onSelected: (action) {
                  switch (action) {
                    case _SupplierAction.edit:
                      onEdit();
                      break;

                    case _SupplierAction.toggleStatus:
                      onToggleStatus();
                      break;
                  }
                },
                itemBuilder: (_) {
                  return [
                    const PopupMenuItem(
                      value: _SupplierAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SupplierAction.toggleStatus,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          supplier.isActive
                              ? Icons.block_outlined
                              : Icons.refresh_outlined,
                        ),
                        title: Text(
                          supplier.isActive ? 'Desactivar' : 'Reactivar',
                        ),
                      ),
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

class _SupplierStatusChip extends StatelessWidget {
  final bool isActive;

  const _SupplierStatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isActive
        ? const Color(0xFFECFDF3)
        : const Color(0xFFF1F5F9);

    final foregroundColor = isActive
        ? const Color(0xFF15803D)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupplierContactItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SupplierContactItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF475569)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptySuppliersState extends StatelessWidget {
  final VoidCallback onCreateSupplier;

  const _EmptySuppliersState({required this.onCreateSupplier});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDFA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 48,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes proveedores',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra proveedores para seleccionarlos al crear una compra.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateSupplier,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Registrar proveedor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSuppliersFoundState extends StatelessWidget {
  const _NoSuppliersFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 70,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              'No encontramos proveedores',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otra búsqueda o cambia el filtro.',
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

class _SupplierErrorState extends StatelessWidget {
  final String message;

  const _SupplierErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'No fue posible cargar los proveedores',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
