import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';

class CashTransactionFormScreen extends StatefulWidget {
  final AppDatabase database;

  const CashTransactionFormScreen({super.key, required this.database});

  @override
  State<CashTransactionFormScreen> createState() =>
      _CashTransactionFormScreenState();
}

class _CashTransactionFormScreenState extends State<CashTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _conceptController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'income';
  bool _isSaving = false;

  bool get _isIncome => _type == 'income';

  int get _currentAmountCents {
    return _tryMoneyTextToCents(_amountController.text) ?? 0;
  }

  Color get _mainColor {
    return _isIncome ? const Color(0xFF15803D) : const Color(0xFFBE123C);
  }

  Color get _softColor {
    return _isIncome ? const Color(0xFFECFDF3) : const Color(0xFFFFF1F2);
  }

  @override
  void dispose() {
    _conceptController.dispose();
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Movimiento de caja'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _CashSaveBar(
        amountCents: _currentAmountCents,
        type: _type,
        isSaving: _isSaving,
        onSave: _saveTransaction,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              children: [
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
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _softColor,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                _isIncome
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: _mainColor,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                'Datos del movimiento',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de movimiento',
                            prefixIcon: Icon(Icons.swap_vert_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('Ingreso'),
                            ),
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('Egreso'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _type = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _conceptController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Concepto',
                            hintText: 'Ej. Aportación inicial',
                            prefixIcon: Icon(Icons.short_text_outlined),
                          ),
                          validator: (value) {
                            final concept = value?.trim() ?? '';

                            if (concept.isEmpty) {
                              return 'Escribe el concepto';
                            }

                            if (concept.length > 120) {
                              return 'El concepto no puede superar 120 caracteres';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
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
                              return 'Escribe el importe';
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Nota',
                            hintText: 'Opcional · Detalles del movimiento',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: _softColor,
                  surfaceTintColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: _mainColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isIncome
                                ? 'El importe aumentará el saldo calculado de caja.'
                                : 'El importe disminuirá el saldo calculado de caja.',
                            style: TextStyle(color: _mainColor, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isSaving) {
      return;
    }

    final amountCents = _tryMoneyTextToCents(_amountController.text);

    if (amountCents == null || amountCents <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final transactionId = await widget.database.createCashTransaction(
        type: _type,
        concept: _conceptController.text,
        amountCents: amountCents,
        note: _noteController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, transactionId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el movimiento: $error')),
      );
    }
  }
}

class _CashSaveBar extends StatelessWidget {
  final int amountCents;
  final String type;
  final bool isSaving;
  final VoidCallback onSave;

  const _CashSaveBar({
    required this.amountCents,
    required this.type,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 'income';

    final mainColor = isIncome
        ? const Color(0xFF15803D)
        : const Color(0xFFBE123C);

    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final amount = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: constraints.maxWidth >= 580
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  isIncome ? 'Ingreso a caja' : 'Egreso de caja',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 3),
                Text(
                  formatCents(amountCents),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: mainColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );

            final button = FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: mainColor,
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
              label: Text(isSaving ? 'Registrando...' : 'Registrar movimiento'),
            );

            if (constraints.maxWidth >= 580) {
              return Row(
                children: [
                  Expanded(child: amount),
                  const SizedBox(width: 20),
                  button,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [amount, const SizedBox(height: 12), button],
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
