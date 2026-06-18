import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/utils/money_formatter.dart';
import 'purchase_form_screen.dart';

class PurchasesScreen extends StatefulWidget {
  final AppDatabase database;

  const PurchasesScreen({super.key, required this.database});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final Stream<List<Purchase>> _purchasesStream;

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _purchasesStream = widget.database.watchAllPurchases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Compras'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPurchase,
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('Nueva compra'),
      ),
      body: StreamBuilder<List<Purchase>>(
        stream: _purchasesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final purchases = snapshot.data ?? [];

          final filteredPurchases = purchases.where(_matchesSearch).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  _PurchasesSummary(purchases: purchases),
                  _SearchBox(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: _buildContent(
                      purchases: purchases,
                      filteredPurchases: filteredPurchases,
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
    required List<Purchase> purchases,
    required List<Purchase> filteredPurchases,
  }) {
    if (purchases.isEmpty) {
      return _EmptyPurchasesState(onCreatePurchase: _openNewPurchase);
    }

    if (filteredPurchases.isEmpty) {
      return const _NoSearchResultsState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filteredPurchases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final purchase = filteredPurchases[index];

        return _PurchaseCard(
          purchase: purchase,
          onTap: () => _openPurchaseDetail(purchase),
        );
      },
    );
  }

  bool _matchesSearch(Purchase purchase) {
    if (_searchText.isEmpty) {
      return true;
    }

    final supplier = purchase.supplierName?.toLowerCase() ?? '';
    final purchaseNumber = purchase.id.toString();
    final status = purchase.status.toLowerCase();

    return supplier.contains(_searchText) ||
        purchaseNumber.contains(_searchText) ||
        status.contains(_searchText);
  }

  Future<void> _openNewPurchase() async {
    final purchaseId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseFormScreen(database: widget.database),
      ),
    );

    if (purchaseId == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compra #$purchaseId registrada correctamente.')),
    );
  }

  void _openPurchaseDetail(Purchase purchase) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Después construiremos el detalle de la compra #${purchase.id}.',
        ),
      ),
    );
  }
}

class _PurchasesSummary extends StatelessWidget {
  final List<Purchase> purchases;

  const _PurchasesSummary({required this.purchases});

  @override
  Widget build(BuildContext context) {
    final completedPurchases = purchases.where(
      (purchase) => purchase.status == 'completed',
    );

    final totalCents = completedPurchases.fold<int>(
      0,
      (total, purchase) => total + purchase.totalCents,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Compras registradas',
                    value: purchases.length.toString(),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Total comprado',
                    value: formatCents(totalCents),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _SummaryCard(
                title: 'Compras registradas',
                value: purchases.length.toString(),
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Total comprado',
                value: formatCents(totalCents),
                icon: Icons.payments_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: primaryColor),
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

class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por proveedor o número de compra',
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

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onTap;

  const _PurchaseCard({required this.purchase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final supplierName = purchase.supplierName?.trim();

    final displayedSupplier = supplierName == null || supplierName.isEmpty
        ? 'Proveedor no especificado'
        : supplierName;

    final isCancelled = purchase.status == 'cancelled';

    final statusColor = isCancelled ? Colors.redAccent : Colors.green;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shopping_cart_checkout_outlined,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Compra #${purchase.id}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          formatCents(purchase.totalCents),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayedSupplier,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PurchaseInformationChip(
                          icon: Icons.calendar_today_outlined,
                          label: DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(purchase.createdAt),
                        ),
                        _PurchaseInformationChip(
                          icon: isCancelled
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline,
                          label: isCancelled ? 'Cancelada' : 'Completada',
                          color: statusColor,
                        ),
                      ],
                    ),
                    if (purchase.note?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        purchase.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseInformationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _PurchaseInformationChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPurchasesState extends StatelessWidget {
  final VoidCallback onCreatePurchase;

  const _EmptyPurchasesState({required this.onCreatePurchase});

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
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_checkout_outlined,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tienes compras',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una compra para aumentar las existencias de tus productos y conservar su historial.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreatePurchase,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Registrar primera compra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

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
              'No encontramos compras',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otro proveedor o número de compra.',
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

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

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
              'No fue posible cargar las compras',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
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
