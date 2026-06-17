import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get sku => text().nullable().unique()();

  TextColumn get barcode => text().nullable().unique()();

  TextColumn get description => text().nullable()();

  IntColumn get purchasePriceCents => integer().withDefault(const Constant(0))();

  IntColumn get salePriceCents => integer().withDefault(const Constant(0))();

  IntColumn get currentStock => integer().withDefault(const Constant(0))();

  IntColumn get minStock => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class InventoryMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  // Tipos sugeridos:
  // purchase_entry, sale_exit, manual_adjustment, return_entry
  TextColumn get type => text().withLength(min: 1, max: 50)();

  IntColumn get quantity => integer()();

  IntColumn get stockAfterMovement => integer()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get supplierName => text().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get totalCents => integer().withDefault(const Constant(0))();

  // completed, cancelled
  TextColumn get status => text().withDefault(const Constant('completed'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId => integer().references(Purchases, #id)();

  IntColumn get productId => integer().references(Products, #id)();

  IntColumn get quantity => integer()();

  IntColumn get unitCostCents => integer()();

  IntColumn get subtotalCents => integer()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get customerName => text().nullable()();

  IntColumn get subtotalCents => integer().withDefault(const Constant(0))();

  IntColumn get discountCents => integer().withDefault(const Constant(0))();

  IntColumn get totalCents => integer().withDefault(const Constant(0))();

  // cash, card, transfer, mixed
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();

  // completed, cancelled
  TextColumn get status => text().withDefault(const Constant('completed'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer().references(Sales, #id)();

  IntColumn get productId => integer().references(Products, #id)();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceCents => integer()();

  IntColumn get subtotalCents => integer()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get category => text().withLength(min: 1, max: 80)();

  TextColumn get description => text().nullable()();

  IntColumn get amountCents => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CashTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  // income, expense
  TextColumn get type => text().withLength(min: 1, max: 20)();

  TextColumn get concept => text().withLength(min: 1, max: 120)();

  IntColumn get amountCents => integer()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Products,
    InventoryMovements,
    Purchases,
    PurchaseItems,
    Sales,
    SaleItems,
    Expenses,
    CashTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pos_offline',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  // -------------------------
  // Productos
  // -------------------------

  Future<List<Product>> getAllProducts() {
    return select(products).get();
  }

  Stream<List<Product>> watchAllProducts() {
    return select(products).watch();
  }

  Future<int> insertProduct(ProductsCompanion product) {
    return into(products).insert(product);
  }

  Future<bool> updateProduct(Product product) {
    return update(products).replace(product.copyWith(updatedAt: DateTime.now()));
  }

  Future<int> deactivateProduct(int productId) {
    return (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<Product?> watchProductById(int productId) {
    return (select(products)..where((tbl) => tbl.id.equals(productId)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<Product?> getProductById(int productId) async {
    final rows = await (select(products)..where((tbl) => tbl.id.equals(productId)))
        .get();

    if (rows.isEmpty) return null;

    return rows.first;
  }

  Future<int> updateProductInfo({
    required int id,
    required String name,
    String? sku,
    String? barcode,
    String? description,
    required int purchasePriceCents,
    required int salePriceCents,
    required int minStock,
  }) {
    return (update(products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        sku: Value(sku),
        barcode: Value(barcode),
        description: Value(description),
        purchasePriceCents: Value(purchasePriceCents),
        salePriceCents: Value(salePriceCents),
        minStock: Value(minStock),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // -------------------------
  // Inventario
  // -------------------------

  Future<void> addInventoryMovement({
    required int productId,
    required String type,
    required int quantity,
    String? note,
  }) async {
    await transaction(() async {
      final product = await (select(products)
            ..where((tbl) => tbl.id.equals(productId)))
          .getSingle();

      final newStock = product.currentStock + quantity;
      
      if (newStock < 0) {
        throw Exception('El stock no puede quedar en negativo.');
      }

      await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
        ProductsCompanion(
          currentStock: Value(newStock),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await into(inventoryMovements).insert(
        InventoryMovementsCompanion(
          productId: Value(productId),
          type: Value(type),
          quantity: Value(quantity),
          stockAfterMovement: Value(newStock),
          note: Value(note),
        ),
      );
    });
  }

  Stream<List<InventoryMovement>> watchProductMovements(int productId) {
    return (select(inventoryMovements)
          ..where((tbl) => tbl.productId.equals(productId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  // -------------------------
  // Gastos
  // -------------------------

  Future<int> insertExpense(ExpensesCompanion expense) {
    return into(expenses).insert(expense);
  }

  Stream<List<Expense>> watchExpenses() {
    return (select(expenses)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }
}