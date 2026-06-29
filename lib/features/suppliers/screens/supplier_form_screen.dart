import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';

class SupplierFormScreen extends StatefulWidget {
  final AppDatabase database;
  final Supplier? supplier;

  const SupplierFormScreen({super.key, required this.database, this.supplier});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();

    final supplier = widget.supplier;

    if (supplier != null) {
      _nameController.text = supplier.name;
      _contactNameController.text = supplier.contactName ?? '';
      _phoneController.text = supplier.phone ?? '';
      _emailController.text = supplier.email ?? '';
      _taxIdController.text = supplier.taxId ?? '';
      _addressController.text = supplier.address ?? '';
      _notesController.text = supplier.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar proveedor' : 'Nuevo proveedor'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 12,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveSupplier,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar proveedor'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _SupplierSectionCard(
                  title: 'Información general',
                  icon: Icons.business_outlined,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      maxLength: 150,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre o razón social',
                        hintText: 'Ej. Distribuidora del Centro',
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      validator: (value) {
                        final cleanValue = value?.trim() ?? '';

                        if (cleanValue.isEmpty) {
                          return 'Escribe el nombre del proveedor';
                        }

                        if (cleanValue.length < 2) {
                          return 'El nombre es demasiado corto';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _taxIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'RFC o identificador fiscal',
                        hintText: 'Opcional',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SupplierSectionCard(
                  title: 'Contacto',
                  icon: Icons.contact_phone_outlined,
                  children: [
                    TextFormField(
                      controller: _contactNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Persona de contacto',
                        hintText: 'Ej. Juan Pérez',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        hintText: 'Ej. 555 123 4567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        hintText: 'Ej. ventas@proveedor.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SupplierSectionCard(
                  title: 'Dirección y notas',
                  icon: Icons.location_on_outlined,
                  children: [
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        hintText: 'Calle, número, colonia, ciudad...',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        hintText: 'Condiciones, horarios, referencias...',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
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

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return null;
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Escribe un correo electrónico válido';
    }

    return null;
  }

  Future<void> _saveSupplier() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await widget.database.updateSupplierInfo(
          supplierId: widget.supplier!.id,
          name: _nameController.text,
          contactName: _contactNameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          taxId: _taxIdController.text,
          address: _addressController.text,
          notes: _notesController.text,
        );
      } else {
        await widget.database.createSupplier(
          name: _nameController.text,
          contactName: _contactNameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          taxId: _taxIdController.text,
          address: _addressController.text,
          notes: _notesController.text,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el proveedor: $error')),
      );
    }
  }
}

class _SupplierSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SupplierSectionCard({
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF0F766E)),
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
