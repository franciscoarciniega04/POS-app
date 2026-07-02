import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import 'customer_form_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final AppDatabase database;
  final int customerId;

  const CustomerDetailScreen({
    super.key,
    required this.database,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Customer?>(
      stream: database.watchCustomerById(customerId),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: const Text('Detalle del cliente'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<Customer?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar el cliente: '
            '${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final customer = snapshot.data;

    if (customer == null) {
      return const Center(child: Text('El cliente ya no existe.'));
    }

    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: customer.isActive
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF1F5F9),
                          child: Text(
                            customer.name.trim().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: customer.isActive
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF64748B),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              _StatusBadge(isActive: customer.isActive),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final editButton = OutlinedButton.icon(
                          onPressed: () {
                            _openEdit(context, customer);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar cliente'),
                        );

                        final statusButton = FilledButton.icon(
                          onPressed: () {
                            _changeStatus(context, customer);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: customer.isActive
                                ? const Color(0xFFBE123C)
                                : const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            customer.isActive
                                ? Icons.person_off_outlined
                                : Icons.person_add_alt_outlined,
                          ),
                          label: Text(
                            customer.isActive ? 'Desactivar' : 'Reactivar',
                          ),
                        );

                        if (constraints.maxWidth >= 520) {
                          return Row(
                            children: [
                              Expanded(child: editButton),
                              const SizedBox(width: 12),
                              Expanded(child: statusButton),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            editButton,
                            const SizedBox(height: 10),
                            statusButton,
                          ],
                        );
                      },
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
                    Text(
                      'Datos de contacto',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _CustomerInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: _displayValue(customer.phone),
                    ),
                    const Divider(height: 28),
                    _CustomerInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: _displayValue(customer.email),
                    ),
                    const Divider(height: 28),
                    _CustomerInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Dirección',
                      value: _displayValue(customer.address),
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
                    Text(
                      'Notas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _displayValue(customer.notes),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFF8FAFC),
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _CustomerDateRow(
                      label: 'Registrado',
                      value: dateFormatter.format(customer.createdAt),
                    ),
                    const SizedBox(height: 9),
                    _CustomerDateRow(
                      label: 'Última modificación',
                      value: dateFormatter.format(customer.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayValue(String? value) {
    final cleanValue = value?.trim();

    if (cleanValue == null || cleanValue.isEmpty) {
      return 'No registrado';
    }

    return cleanValue;
  }

  Future<void> _openEdit(BuildContext context, Customer customer) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerFormScreen(database: database, customer: customer),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, Customer customer) async {
    final newStatus = !customer.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            newStatus
                ? Icons.person_add_alt_outlined
                : Icons.person_off_outlined,
            color: newStatus
                ? const Color(0xFF15803D)
                : const Color(0xFFBE123C),
            size: 40,
          ),
          title: Text(newStatus ? 'Reactivar cliente' : 'Desactivar cliente'),
          content: Text(
            newStatus
                ? 'El cliente volverá a aparecer entre los clientes activos.'
                : 'El cliente dejará de aparecer en la lista de activos, pero conservará su historial.',
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await database.setCustomerActive(
        customerId: customer.id,
        isActive: newStatus,
      );

      if (!context.mounted) {
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
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF3) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CustomerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerDateRow extends StatelessWidget {
  final String label;
  final String value;

  const _CustomerDateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
