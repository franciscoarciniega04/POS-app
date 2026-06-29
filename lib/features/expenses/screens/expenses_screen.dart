import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'expense_form_screen.dart';

enum _ExpensePeriodFilter { all, today, thisMonth }

class ExpensesScreen extends StatefulWidget {
  final AppDatabase database;

  const ExpensesScreen({super.key, required this.database});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final Stream<List<Expense>> _expensesStream;

  String _searchText = '';
  String? _selectedCategory;

  _ExpensePeriodFilter _selectedPeriod = _ExpensePeriodFilter.all;

  @override
  void initState() {
    super.initState();

    _expensesStream = widget.database.watchAllExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Gastos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExpenseForm,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo gasto'),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _expensesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ExpenseErrorState(message: snapshot.error.toString());
          }

          final expenses = snapshot.data ?? [];

          final categories =
              expenses
                  .map((expense) => expense.category.trim())
                  .where((category) => category.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort(
                  (first, second) =>
                      first.toLowerCase().compareTo(second.toLowerCase()),
                );

          final filteredExpenses = expenses
              .where(_matchesPeriod)
              .where(_matchesCategory)
              .where(_matchesSearch)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  _ExpensesSummary(expenses: expenses),
                  _ExpensePeriodFilters(
                    selectedFilter: _selectedPeriod,
                    onChanged: (filter) {
                      setState(() {
                        _selectedPeriod = filter;
                      });
                    },
                  ),
                  if (categories.isNotEmpty)
                    _ExpenseCategoryFilters(
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onChanged: (category) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  _ExpenseSearchField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: _buildContent(
                      allExpenses: expenses,
                      filteredExpenses: filteredExpenses,
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
    required List<Expense> allExpenses,
    required List<Expense> filteredExpenses,
  }) {
    if (allExpenses.isEmpty) {
      return _EmptyExpensesState(onCreateExpense: _openExpenseForm);
    }

    if (filteredExpenses.isEmpty) {
      return const _NoExpenseResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredExpenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _ExpenseCard(expense: filteredExpenses[index]);
      },
    );
  }

  bool _matchesPeriod(Expense expense) {
    final expenseDate = expense.createdAt.toLocal();
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case _ExpensePeriodFilter.all:
        return true;

      case _ExpensePeriodFilter.today:
        return DateUtils.isSameDay(expenseDate, now);

      case _ExpensePeriodFilter.thisMonth:
        return expenseDate.year == now.year && expenseDate.month == now.month;
    }
  }

  bool _matchesCategory(Expense expense) {
    if (_selectedCategory == null) {
      return true;
    }

    return expense.category == _selectedCategory;
  }

  bool _matchesSearch(Expense expense) {
    if (_searchText.isEmpty) {
      return true;
    }

    final values = [
      expense.id.toString(),
      '#${expense.id}',
      expense.category,
      expense.description ?? '',
      formatCents(expense.amountCents),
    ];

    return values.any((value) => value.toLowerCase().contains(_searchText));
  }

  Future<void> _openExpenseForm() async {
    final expenseId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(database: widget.database),
      ),
    );

    if (expenseId == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gasto #$expenseId registrado correctamente.')),
    );
  }
}

class _ExpensesSummary extends StatelessWidget {
  final List<Expense> expenses;

  const _ExpensesSummary({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final totalCents = expenses.fold<int>(
      0,
      (total, expense) => total + expense.amountCents,
    );

    final monthExpenses = expenses.where((expense) {
      final date = expense.createdAt.toLocal();

      return date.year == now.year && date.month == now.month;
    });

    final monthTotalCents = monthExpenses.fold<int>(
      0,
      (total, expense) => total + expense.amountCents,
    );

    final cards = [
      _ExpenseSummaryCard(
        title: 'Total registrado',
        value: formatCents(totalCents),
        icon: Icons.account_balance_wallet_outlined,
        foregroundColor: const Color(0xFFBE123C),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
      _ExpenseSummaryCard(
        title: 'Gastos del mes',
        value: formatCents(monthTotalCents),
        icon: Icons.calendar_month_outlined,
        foregroundColor: const Color(0xFFB45309),
        backgroundColor: const Color(0xFFFFFBEB),
      ),
      _ExpenseSummaryCard(
        title: 'Movimientos',
        value: expenses.length.toString(),
        icon: Icons.receipt_long_outlined,
        foregroundColor: const Color(0xFF1D4ED8),
        backgroundColor: const Color(0xFFEFF6FF),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 850) {
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
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
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ExpenseSummaryCard({
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
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: foregroundColor),
            ),
            const SizedBox(width: 13),
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

class _ExpensePeriodFilters extends StatelessWidget {
  final _ExpensePeriodFilter selectedFilter;
  final ValueChanged<_ExpensePeriodFilter> onChanged;

  const _ExpensePeriodFilters({
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
              label: const Text('Todos'),
              selected: selectedFilter == _ExpensePeriodFilter.all,
              onSelected: (_) {
                onChanged(_ExpensePeriodFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Hoy'),
              selected: selectedFilter == _ExpensePeriodFilter.today,
              onSelected: (_) {
                onChanged(_ExpensePeriodFilter.today);
              },
            ),
            ChoiceChip(
              label: const Text('Este mes'),
              selected: selectedFilter == _ExpensePeriodFilter.thisMonth,
              onSelected: (_) {
                onChanged(_ExpensePeriodFilter.thisMonth);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCategoryFilters extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onChanged;

  const _ExpenseCategoryFilters({
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas las categorías'),
              selected: selectedCategory == null,
              onSelected: (_) {
                onChanged(null);
              },
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (_) {
                  onChanged(category);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpenseSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _ExpenseSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por categoría o descripción',
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

class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy · HH:mm');

    final description = expense.description?.trim();

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
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Color(0xFFBE123C),
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
                          expense.category,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        formatCents(expense.amountCents),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFBE123C),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gasto #${expense.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (description?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ExpenseDateChip(
                    date: dateFormatter.format(expense.createdAt.toLocal()),
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

class _ExpenseDateChip extends StatelessWidget {
  final String date;

  const _ExpenseDateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            date,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  final VoidCallback onCreateExpense;

  const _EmptyExpensesState({required this.onCreateExpense});

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
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Color(0xFFBE123C),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes gastos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra los egresos del negocio para calcular correctamente la utilidad.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateExpense,
              icon: const Icon(Icons.add),
              label: const Text('Registrar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoExpenseResults extends StatelessWidget {
  const _NoExpenseResults();

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
              'No encontramos gastos con los filtros seleccionados.',
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

class _ExpenseErrorState extends StatelessWidget {
  final String message;

  const _ExpenseErrorState({required this.message});

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
              'No fue posible cargar los gastos',
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
