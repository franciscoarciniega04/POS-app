import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'cash_transaction_form_screen.dart';

enum _CashTypeFilter { all, income, expense }

enum _CashPeriodFilter { all, today, thisMonth }

class CashScreen extends StatefulWidget {
  final AppDatabase database;

  const CashScreen({super.key, required this.database});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late final Stream<List<CashTransaction>> _transactionsStream;

  String _searchText = '';

  _CashTypeFilter _selectedType = _CashTypeFilter.all;

  _CashPeriodFilter _selectedPeriod = _CashPeriodFilter.all;

  @override
  void initState() {
    super.initState();

    _transactionsStream = widget.database.watchAllCashTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Caja'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTransactionForm,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo movimiento'),
      ),
      body: StreamBuilder<List<CashTransaction>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _CashErrorState(message: snapshot.error.toString());
          }

          final transactions = snapshot.data ?? [];

          final filteredTransactions = transactions
              .where(_matchesPeriod)
              .where(_matchesType)
              .where(_matchesSearch)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  _CashSummary(transactions: transactions),
                  _CashPeriodFilters(
                    selectedFilter: _selectedPeriod,
                    onChanged: (filter) {
                      setState(() {
                        _selectedPeriod = filter;
                      });
                    },
                  ),
                  _CashTypeFilters(
                    selectedFilter: _selectedType,
                    onChanged: (filter) {
                      setState(() {
                        _selectedType = filter;
                      });
                    },
                  ),
                  _CashSearchField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: _buildContent(
                      allTransactions: transactions,
                      filteredTransactions: filteredTransactions,
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
    required List<CashTransaction> allTransactions,
    required List<CashTransaction> filteredTransactions,
  }) {
    if (allTransactions.isEmpty) {
      return _EmptyCashState(onCreateTransaction: _openTransactionForm);
    }

    if (filteredTransactions.isEmpty) {
      return const _NoCashResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredTransactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _CashTransactionCard(transaction: filteredTransactions[index]);
      },
    );
  }

  bool _matchesPeriod(CashTransaction transaction) {
    final transactionDate = transaction.createdAt.toLocal();

    final now = DateTime.now();

    switch (_selectedPeriod) {
      case _CashPeriodFilter.all:
        return true;

      case _CashPeriodFilter.today:
        return DateUtils.isSameDay(transactionDate, now);

      case _CashPeriodFilter.thisMonth:
        return transactionDate.year == now.year &&
            transactionDate.month == now.month;
    }
  }

  bool _matchesType(CashTransaction transaction) {
    switch (_selectedType) {
      case _CashTypeFilter.all:
        return true;

      case _CashTypeFilter.income:
        return transaction.type == 'income';

      case _CashTypeFilter.expense:
        return transaction.type == 'expense';
    }
  }

  bool _matchesSearch(CashTransaction transaction) {
    if (_searchText.isEmpty) {
      return true;
    }

    final values = [
      transaction.id.toString(),
      '#${transaction.id}',
      transaction.type,
      _cashTypeLabel(transaction.type),
      transaction.concept,
      transaction.note ?? '',
      formatCents(transaction.amountCents),
    ];

    return values.any((value) => value.toLowerCase().contains(_searchText));
  }

  Future<void> _openTransactionForm() async {
    final transactionId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CashTransactionFormScreen(database: widget.database),
      ),
    );

    if (transactionId == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Movimiento #$transactionId registrado correctamente.'),
      ),
    );
  }
}

class _CashSummary extends StatelessWidget {
  final List<CashTransaction> transactions;

  const _CashSummary({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final totalIncomeCents = transactions
        .where((transaction) => transaction.type == 'income')
        .fold<int>(0, (total, transaction) => total + transaction.amountCents);

    final totalExpenseCents = transactions
        .where((transaction) => transaction.type == 'expense')
        .fold<int>(0, (total, transaction) => total + transaction.amountCents);

    final balanceCents = totalIncomeCents - totalExpenseCents;

    final monthBalanceCents = transactions
        .where((transaction) {
          final date = transaction.createdAt.toLocal();

          return date.year == now.year && date.month == now.month;
        })
        .fold<int>(0, (total, transaction) {
          if (transaction.type == 'income') {
            return total + transaction.amountCents;
          }

          if (transaction.type == 'expense') {
            return total - transaction.amountCents;
          }

          return total;
        });

    final cards = [
      _CashSummaryCard(
        title: 'Saldo calculado',
        value: formatCents(balanceCents),
        icon: Icons.account_balance_wallet_outlined,
        foregroundColor: balanceCents >= 0
            ? const Color(0xFF15803D)
            : const Color(0xFFBE123C),
        backgroundColor: balanceCents >= 0
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFFF1F2),
      ),
      _CashSummaryCard(
        title: 'Ingresos',
        value: formatCents(totalIncomeCents),
        icon: Icons.arrow_downward_rounded,
        foregroundColor: const Color(0xFF15803D),
        backgroundColor: const Color(0xFFECFDF3),
      ),
      _CashSummaryCard(
        title: 'Egresos',
        value: formatCents(totalExpenseCents),
        icon: Icons.arrow_upward_rounded,
        foregroundColor: const Color(0xFFBE123C),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
      _CashSummaryCard(
        title: 'Saldo del mes',
        value: formatCents(monthBalanceCents),
        icon: Icons.calendar_month_outlined,
        foregroundColor: const Color(0xFF1D4ED8),
        backgroundColor: const Color(0xFFEFF6FF),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 950) {
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            );
          }

          if (constraints.maxWidth >= 600) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              cards[1],
              const SizedBox(height: 12),
              cards[2],
              const SizedBox(height: 12),
              cards[3],
            ],
          );
        },
      ),
    );
  }
}

class _CashSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _CashSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: foregroundColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foregroundColor,
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

class _CashPeriodFilters extends StatelessWidget {
  final _CashPeriodFilter selectedFilter;
  final ValueChanged<_CashPeriodFilter> onChanged;

  const _CashPeriodFilters({
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
              label: const Text('Todo el historial'),
              selected: selectedFilter == _CashPeriodFilter.all,
              onSelected: (_) {
                onChanged(_CashPeriodFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Hoy'),
              selected: selectedFilter == _CashPeriodFilter.today,
              onSelected: (_) {
                onChanged(_CashPeriodFilter.today);
              },
            ),
            ChoiceChip(
              label: const Text('Este mes'),
              selected: selectedFilter == _CashPeriodFilter.thisMonth,
              onSelected: (_) {
                onChanged(_CashPeriodFilter.thisMonth);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CashTypeFilters extends StatelessWidget {
  final _CashTypeFilter selectedFilter;
  final ValueChanged<_CashTypeFilter> onChanged;

  const _CashTypeFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: selectedFilter == _CashTypeFilter.all,
              onSelected: (_) {
                onChanged(_CashTypeFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Ingresos'),
              selected: selectedFilter == _CashTypeFilter.income,
              onSelected: (_) {
                onChanged(_CashTypeFilter.income);
              },
            ),
            ChoiceChip(
              label: const Text('Egresos'),
              selected: selectedFilter == _CashTypeFilter.expense,
              onSelected: (_) {
                onChanged(_CashTypeFilter.expense);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CashSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _CashSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por concepto o nota',
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

class _CashTransactionCard extends StatelessWidget {
  final CashTransaction transaction;

  const _CashTransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final visual = _cashVisual(transaction.type);

    final formatter = DateFormat('dd/MM/yyyy · HH:mm');

    final note = transaction.note?.trim();

    final amountText = transaction.type == 'income'
        ? '+${formatCents(transaction.amountCents)}'
        : '-${formatCents(transaction.amountCents)}';

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(visual.icon, color: visual.foregroundColor),
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
                          transaction.concept,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        amountText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: visual.foregroundColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${visual.label} · Movimiento #${transaction.id}',
                    style: TextStyle(
                      color: visual.foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (note?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      note!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatter.format(transaction.createdAt.toLocal()),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _CashVisual {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _CashVisual({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

_CashVisual _cashVisual(String type) {
  switch (type) {
    case 'income':
      return const _CashVisual(
        label: 'Ingreso',
        icon: Icons.arrow_downward_rounded,
        foregroundColor: Color(0xFF15803D),
        backgroundColor: Color(0xFFECFDF3),
      );

    case 'expense':
      return const _CashVisual(
        label: 'Egreso',
        icon: Icons.arrow_upward_rounded,
        foregroundColor: Color(0xFFBE123C),
        backgroundColor: Color(0xFFFFF1F2),
      );

    default:
      return const _CashVisual(
        label: 'Movimiento',
        icon: Icons.swap_vert_outlined,
        foregroundColor: Color(0xFF475569),
        backgroundColor: Color(0xFFF1F5F9),
      );
  }
}

String _cashTypeLabel(String type) {
  return _cashVisual(type).label;
}

class _EmptyCashState extends StatelessWidget {
  final VoidCallback onCreateTransaction;

  const _EmptyCashState({required this.onCreateTransaction});

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
                color: Color(0xFFECFDF3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no hay movimientos de caja',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Las ventas, compras, gastos y movimientos manuales aparecerán aquí.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Registrar movimiento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCashResults extends StatelessWidget {
  const _NoCashResults();

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
              size: 68,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 14),
            Text(
              'No encontramos movimientos con los filtros seleccionados.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashErrorState extends StatelessWidget {
  final String message;

  const _CashErrorState({required this.message});

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
            Text(
              'No fue posible cargar la caja',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
