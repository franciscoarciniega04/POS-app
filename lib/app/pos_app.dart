import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../features/products/screens/products_screen.dart';
import '../features/purchases/screens/purchases_screen.dart';

class PosApp extends StatelessWidget {
  final AppDatabase database;

  const PosApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Offline',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
      ),
      home: HomeScreen(database: database),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _HomeModule(
        title: 'Productos',
        subtitle: 'Catálogo, precios y stock',
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF4338CA),
        iconBackgroundColor: const Color(0xFFEEF2FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductsScreen(database: database),
            ),
          );
        },
      ),
      _HomeModule(
        title: 'Compras',
        subtitle: 'Entradas de inventario',
        icon: Icons.shopping_cart_checkout_outlined,
        iconColor: const Color(0xFF15803D),
        iconBackgroundColor: const Color(0xFFECFDF3),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchasesScreen(database: database),
            ),
          );
        },
      ),
      _HomeModule(
        title: 'Ventas',
        subtitle: 'Registrar salidas y pagos',
        icon: Icons.point_of_sale_outlined,
        iconColor: const Color(0xFFC2410C),
        iconBackgroundColor: const Color(0xFFFFF7ED),
        onTap: () {},
      ),
      _HomeModule(
        title: 'Inventario',
        subtitle: 'Historial y movimientos',
        icon: Icons.warehouse_outlined,
        iconColor: const Color(0xFF475569),
        iconBackgroundColor: const Color(0xFFF1F5F9),
        onTap: () {},
      ),
      _HomeModule(
        title: 'Gastos',
        subtitle: 'Control de egresos',
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xFFBE123C),
        iconBackgroundColor: const Color(0xFFFFF1F2),
        onTap: () {},
      ),
      _HomeModule(
        title: 'Reportes',
        subtitle: 'Ventas, ganancias y resumen',
        icon: Icons.bar_chart_outlined,
        iconColor: const Color(0xFF7E22CE),
        iconBackgroundColor: const Color(0xFFFAF5FF),
        onTap: () {},
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('POS Offline'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 1,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: isWide ? 1.55 : 3.7,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];

              return Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: module.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: module.iconBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: module.iconColor.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Icon(
                            module.icon,
                            color: module.iconColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                module.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                module.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback onTap;

  const _HomeModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onTap,
  });
}
