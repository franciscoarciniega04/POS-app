import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class ExpenseFormScreen extends StatefulWidget {
  final AppDatabase database;

  const ExpenseFormScreen({super.key, required this.database});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  static const _categories = [
    'Renta',
    'Servicios',
    'Nómina',
    'Transporte',
    'Mantenimiento',
    'Papelería',
    'Impuestos',
    'Comisiones',
    'Publicidad',
    'Otra categoría',
  ];

  final _formKey = GlobalKey<FormState>();

  final _customCategoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCategory = 'Servicios';
  bool _isSaving = false;

  int get _currentAmountCents {
    return _tryMoneyTextToCents(_amountController.text) ?? 0;
  }

  String get _finalCategory {
    if (_selectedCategory == 'Otra categoría') {
      return _customCategoryController.text.trim();
    }

    return _selectedCategory;
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Nuevo gasto'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _ExpenseSaveBar(
        amountCents: _currentAmountCents,
        isSaving: _isSaving,
        onSave: _saveExpense,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
              children: [
                Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _ExpenseSectionTitle(
                          icon: Icons.receipt_long_outlined,
                          title: 'Información del gasto',
                        ),
                        const SizedBox(height: 22),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (category) {
                            if (category == null) {
                              return;
                            }

                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                        if (_selectedCategory == 'Otra categoría') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _customCategoryController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la categoría',
                              hintText: 'Ej. Seguridad',
                              prefixIcon: Icon(Icons.edit_outlined),
                            ),
                            validator: (value) {
                              final category = value?.trim() ?? '';

                              if (category.isEmpty) {
                                return 'Escribe la categoría del gasto';
                              }

                              if (category.length > 80) {
                                return 'La categoría no puede superar 80 caracteres';
                              }

                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Opcional · Agrega detalles del gasto',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Importe',
                            hintText: '0.00',
                            prefixText: r'$ ',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Escribe el importe del gasto';
                            }

                            final amountCents = _tryMoneyTextToCents(value);

                            if (amountCents == null) {
                              return 'Escribe un importe válido';
                            }

                            if (amountCents <= 0) {
                              return 'El importe debe ser mayor que cero';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _ExpenseInformationCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isSaving) {
      return;
    }

    final amountCents = _tryMoneyTextToCents(_amountController.text);

    if (amountCents == null || amountCents <= 0) {
      return;
    }

    final category = _finalCategory;

    if (category.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final expenseId = await widget.database.createExpense(
        category: category,
        description: _descriptionController.text,
        amountCents: amountCents,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, expenseId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el gasto: $error')),
      );
    }
  }
}

class _ExpenseSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ExpenseSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: const Color(0xFFBE123C)),
        ),
        const SizedBox(width: 13),
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

class _ExpenseInformationCard extends StatelessWidget {
  const _ExpenseInformationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBEB),
      surfaceTintColor: Colors.transparent,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Color(0xFFB45309)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Al guardar, el gasto también se registrará automáticamente '
                'como una salida de caja.',
                style: TextStyle(color: Color(0xFF78350F), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseSaveBar extends StatelessWidget {
  final int amountCents;
  final bool isSaving;
  final VoidCallback onSave;

  const _ExpenseSaveBar({
    required this.amountCents,
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
            final total = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: constraints.maxWidth >= 580
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'Importe del gasto',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 3),
                Text(
                  formatCents(amountCents),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFBE123C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );

            final button = FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Registrando...' : 'Registrar gasto'),
            );

            if (constraints.maxWidth >= 580) {
              return Row(
                children: [
                  Expanded(child: total),
                  const SizedBox(width: 20),
                  button,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [total, const SizedBox(height: 12), button],
            );
          },
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
