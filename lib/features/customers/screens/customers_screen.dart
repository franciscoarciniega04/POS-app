import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

enum _CustomerFilter { active, inactive, all }

enum _CustomerAction { edit, changeStatus }

class CustomersScreen extends StatefulWidget {
  final AppDatabase database;

  const CustomersScreen({super.key, required this.database});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  _CustomerFilter _selectedFilter = _CustomerFilter.active;

  late Stream<List<Customer>> _customersStream;

  @override
  void initState() {
    super.initState();

    _refreshStream();

    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCustomer,
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Nuevo cliente'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              _CustomerFiltersCard(
                searchController: _searchController,
                selectedFilter: _selectedFilter,
                onFilterChanged: _changeFilter,
              ),
              Expanded(
                child: StreamBuilder<List<Customer>>(
                  stream: _customersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No se pudieron cargar los clientes: '
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final customers = snapshot.data ?? const <Customer>[];

                    final visibleCustomers = _filterCustomers(customers);

                    if (visibleCustomers.isEmpty) {
                      return _EmptyCustomersState(
                        hasSearch: _searchController.text.trim().isNotEmpty,
                        filter: _selectedFilter,
                        onCreate: _createCustomer,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: visibleCustomers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = visibleCustomers[index];

                        return _CustomerCard(
                          customer: customer,
                          onTap: () {
                            _openDetail(customer);
                          },
                          onAction: (action) {
                            switch (action) {
                              case _CustomerAction.edit:
                                _openEdit(customer);

                              case _CustomerAction.changeStatus:
                                _changeStatus(customer);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshSearch() {
    setState(() {});
  }

  void _refreshStream() {
    _customersStream = widget.database.watchAllCustomers(
      includeInactive: _selectedFilter != _CustomerFilter.active,
    );
  }

  void _changeFilter(_CustomerFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _refreshStream();
    });
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final search = _searchController.text.trim().toLowerCase();

    return customers.where((customer) {
      final matchesStatus = switch (_selectedFilter) {
        _CustomerFilter.active => customer.isActive,
        _CustomerFilter.inactive => !customer.isActive,
        _CustomerFilter.all => true,
      };

      if (!matchesStatus) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final values = [
        customer.name,
        customer.phone ?? '',
        customer.email ?? '',
        customer.address ?? '',
      ].join(' ').toLowerCase();

      return values.contains(search);
    }).toList();
  }

  Future<void> _createCustomer() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(database: widget.database),
      ),
    );
  }

  Future<void> _openEdit(Customer customer) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerFormScreen(database: widget.database, customer: customer),
      ),
    );
  }

  Future<void> _openDetail(Customer customer) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          database: widget.database,
          customerId: customer.id,
        ),
      ),
    );
  }

  Future<void> _changeStatus(Customer customer) async {
    final newStatus = !customer.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(newStatus ? 'Reactivar cliente' : 'Desactivar cliente'),
          content: Text(
            newStatus
                ? '¿Deseas reactivar a ${customer.name}?'
                : '¿Deseas desactivar a ${customer.name}? Su historial se conservará.',
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
              style: FilledButton.styleFrom(
                backgroundColor: newStatus
                    ? const Color(0xFF15803D)
                    : const Color(0xFFBE123C),
                foregroundColor: Colors.white,
              ),
              child: Text(newStatus ? 'Reactivar' : 'Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.database.setCustomerActive(
        customerId: customer.id,
        isActive: newStatus,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Cliente reactivado.' : 'Cliente desactivado.',
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

class _CustomerFiltersCard extends StatelessWidget {
  final TextEditingController searchController;

  final _CustomerFilter selectedFilter;
  final ValueChanged<_CustomerFilter> onFilterChanged;

  const _CustomerFiltersCard({
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar cliente',
                  hintText: 'Nombre, teléfono, correo o dirección',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Activos'),
                      selected: selectedFilter == _CustomerFilter.active,
                      onSelected: (_) {
                        onFilterChanged(_CustomerFilter.active);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Inactivos'),
                      selected: selectedFilter == _CustomerFilter.inactive,
                      onSelected: (_) {
                        onFilterChanged(_CustomerFilter.inactive);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: selectedFilter == _CustomerFilter.all,
                      onSelected: (_) {
                        onFilterChanged(_CustomerFilter.all);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final ValueChanged<_CustomerAction> onAction;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final contactValues = <String>[];

    final phone = customer.phone?.trim();
    final email = customer.email?.trim();

    if (phone != null && phone.isNotEmpty) {
      contactValues.add(phone);
    }

    if (email != null && email.isNotEmpty) {
      contactValues.add(email);
    }

    final contact = contactValues.isEmpty
        ? 'Sin datos de contacto'
        : contactValues.join(' · ');

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: customer.isActive
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF1F5F9),
                child: Text(
                  customer.name.trim().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: customer.isActive
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CustomerStatusChip(isActive: customer.isActive),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CustomerAction>(
                tooltip: 'Opciones',
                onSelected: onAction,
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(
                      value: _CustomerAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _CustomerAction.changeStatus,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          customer.isActive
                              ? Icons.person_off_outlined
                              : Icons.person_add_alt_outlined,
                        ),
                        title: Text(
                          customer.isActive ? 'Desactivar' : 'Reactivar',
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

class _CustomerStatusChip extends StatelessWidget {
  final bool isActive;

  const _CustomerStatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF3) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCustomersState extends StatelessWidget {
  final bool hasSearch;
  final _CustomerFilter filter;
  final VoidCallback onCreate;

  const _EmptyCustomersState({
    required this.hasSearch,
    required this.filter,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final message = hasSearch
        ? 'No se encontraron clientes con esa búsqueda.'
        : switch (filter) {
            _CustomerFilter.active => 'Todavía no hay clientes activos.',
            _CustomerFilter.inactive => 'No hay clientes inactivos.',
            _CustomerFilter.all => 'Todavía no hay clientes registrados.',
          };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline,
              size: 68,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (!hasSearch && filter != _CustomerFilter.inactive) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Registrar cliente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
