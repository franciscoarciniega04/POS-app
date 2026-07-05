import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CustomerOrderStatus {
  const CustomerOrderStatus._();

  static const pending = 'pending';
  static const partiallyFulfilled = 'partially_fulfilled';
  static const fulfilled = 'fulfilled';
  static const cancelled = 'cancelled';

  static const values = {pending, partiallyFulfilled, fulfilled, cancelled};

  static String label(String status) {
    return switch (status) {
      pending => 'Pendiente',
      partiallyFulfilled => 'Parcialmente surtido',
      fulfilled => 'Surtido',
      cancelled => 'Cancelado',
      _ => status,
    };
  }
}

class ProductCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 80)();

  TextColumn get description => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId => integer().nullable().references(
    ProductCategories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get sku => text().nullable().unique()();

  TextColumn get barcode => text().nullable().unique()();

  TextColumn get description => text().nullable()();

  BlobColumn get imageBytes => blob().nullable()();

  BoolColumn get showInCatalog => boolean().withDefault(const Constant(true))();

  BoolColumn get allowNegativeStock =>
      boolean().withDefault(const Constant(false))();

  IntColumn get purchasePriceCents =>
      integer().withDefault(const Constant(0))();

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

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 150)();

  TextColumn get contactName => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get taxId => text().nullable().unique()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId => integer().nullable().references(
    Suppliers,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Copia histórica del nombre al registrar la compra.
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

  IntColumn get unitCostCents => integer().nullable()();

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

class PurchaseLineInput {
  final int productId;
  final int quantity;
  final int unitCostCents;

  const PurchaseLineInput({
    required this.productId,
    required this.quantity,
    required this.unitCostCents,
  });

  int get subtotalCents => quantity * unitCostCents;
}

class PurchaseItemDetail {
  final PurchaseItem purchaseItem;
  final Product product;

  const PurchaseItemDetail({required this.purchaseItem, required this.product});
}

class SaleLineInput {
  final int productId;
  final int quantity;
  final int unitPriceCents;

  const SaleLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPriceCents,
  });

  int get subtotalCents {
    return quantity * unitPriceCents;
  }
}

class SaleItemDetail {
  final SaleItem saleItem;
  final Product product;

  const SaleItemDetail({required this.saleItem, required this.product});
}

class InventoryMovementDetail {
  final InventoryMovement movement;
  final Product product;

  const InventoryMovementDetail({
    required this.movement,
    required this.product,
  });
}

class BusinessReportSummary {
  final int completedSalesCount;
  final int cancelledSalesCount;
  final int salesTotalCents;
  final int discountsCents;
  final int costOfGoodsSoldCents;
  final int expensesCents;
  final int soldUnits;
  final int salesWithoutHistoricalCost;

  const BusinessReportSummary({
    required this.completedSalesCount,
    required this.cancelledSalesCount,
    required this.salesTotalCents,
    required this.discountsCents,
    required this.costOfGoodsSoldCents,
    required this.expensesCents,
    required this.soldUnits,
    required this.salesWithoutHistoricalCost,
  });

  int get grossProfitCents {
    return salesTotalCents - costOfGoodsSoldCents;
  }

  int get netProfitCents {
    return grossProfitCents - expensesCents;
  }

  int get averageTicketCents {
    if (completedSalesCount == 0) {
      return 0;
    }

    return salesTotalCents ~/ completedSalesCount;
  }

  bool get hasIncompleteHistoricalCosts {
    return salesWithoutHistoricalCost > 0;
  }
}

class ProductSalesReport {
  final int productId;
  final String productName;
  final String? sku;
  final int quantitySold;
  final int salesSubtotalCents;
  final int knownCostCents;
  final bool hasMissingHistoricalCost;

  const ProductSalesReport({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantitySold,
    required this.salesSubtotalCents,
    required this.knownCostCents,
    required this.hasMissingHistoricalCost,
  });

  int get knownGrossProfitCents {
    return salesSubtotalCents - knownCostCents;
  }
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get phone => text().withLength(min: 3, max: 30).nullable()();

  TextColumn get email => text().withLength(min: 5, max: 150).nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerOrders extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.restrict)();

  TextColumn get status => text()
      .withLength(min: 1, max: 30)
      .withDefault(const Constant(CustomerOrderStatus.pending))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get orderId =>
      integer().references(CustomerOrders, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  // Conserva el nombre histórico del producto,
  // aunque después sea renombrado.
  TextColumn get productName => text().withLength(min: 1, max: 200)();

  IntColumn get quantityRequested => integer()();

  IntColumn get quantityFulfilled => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class OrderPurchaseAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get orderItemId => integer().references(
    CustomerOrderItems,
    #id,
    onDelete: KeyAction.cascade,
  )();

  IntColumn get purchaseItemId =>
      integer().references(PurchaseItems, #id, onDelete: KeyAction.cascade)();

  IntColumn get quantity => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerOrderLineInput {
  final int productId;
  final int quantity;
  final String? notes;

  const CustomerOrderLineInput({
    required this.productId,
    required this.quantity,
    this.notes,
  });
}

class CustomerOrderWithCustomer {
  final CustomerOrder order;
  final Customer customer;

  const CustomerOrderWithCustomer({
    required this.order,
    required this.customer,
  });
}

class CustomerOrderItemDetail {
  final CustomerOrderItem orderItem;
  final Product product;

  const CustomerOrderItemDetail({
    required this.orderItem,
    required this.product,
  });

  int get pendingQuantity {
    final pending = orderItem.quantityRequested - orderItem.quantityFulfilled;

    return pending < 0 ? 0 : pending;
  }

  bool get isFullyFulfilled {
    return pendingQuantity == 0;
  }
}

class PendingCustomerOrderItemDetail {
  final CustomerOrder order;
  final Customer customer;
  final CustomerOrderItem orderItem;
  final Product product;

  const PendingCustomerOrderItemDetail({
    required this.order,
    required this.customer,
    required this.orderItem,
    required this.product,
  });

  int get pendingQuantity {
    final value = orderItem.quantityRequested - orderItem.quantityFulfilled;

    return value < 0 ? 0 : value;
  }
}

class OrderFulfillmentLineInput {
  final int orderItemId;
  final int quantity;
  final int unitCostCents;

  const OrderFulfillmentLineInput({
    required this.orderItemId,
    required this.quantity,
    required this.unitCostCents,
  });

  int get subtotalCents => quantity * unitCostCents;
}

class ProductCatalogItem {
  final Product product;
  final ProductCategory? category;

  const ProductCatalogItem({required this.product, required this.category});

  String get categoryName {
    final currentCategory = category;

    if (currentCategory == null || !currentCategory.isActive) {
      return 'Sin categoría';
    }

    return currentCategory.name;
  }
}

@DriftDatabase(
  tables: [
    ProductCategories,
    Products,
    InventoryMovements,
    Suppliers,
    Purchases,
    PurchaseItems,
    Sales,
    SaleItems,
    Expenses,
    CashTransactions,
    Customers,
    CustomerOrders,
    CustomerOrderItems,
    OrderPurchaseAllocations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static const databaseName = 'pos_offline';
  static const currentSchemaVersion = 7;

  static Future<Directory> getDatabaseDirectory() {
    return getApplicationSupportDirectory();
  }

  static Future<File> getDatabaseFile() async {
    final directory = await getDatabaseDirectory();

    return File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '$databaseName.sqlite',
    );
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(suppliers);

          await migrator.addColumn(purchases, purchases.supplierId);
        }

        if (from < 3) {
          await migrator.addColumn(saleItems, saleItems.unitCostCents);
        }

        if (from < 4) {
          await migrator.createTable(customers);
        }

        if (from < 5) {
          await migrator.createTable(customerOrders);

          await migrator.createTable(customerOrderItems);

          await migrator.createTable(orderPurchaseAllocations);
        }

        if (from < 6) {
          await migrator.createTable(productCategories);

          await migrator.addColumn(products, products.categoryId);

          await migrator.addColumn(products, products.imageBytes);

          await migrator.addColumn(products, products.showInCatalog);
        }

        if (from < 7) {
          await migrator.addColumn(products, products.allowNegativeStock);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: databaseName,
      native: DriftNativeOptions(databaseDirectory: getDatabaseDirectory),
    );
  }

  // -------------------------
  // Categorías de productos
  // -------------------------

  Stream<List<ProductCategory>> watchProductCategories({
    bool includeInactive = false,
  }) {
    final query = select(productCategories);

    if (!includeInactive) {
      query.where((tbl) => tbl.isActive.equals(true));
    }

    query.orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);

    return query.watch();
  }

  Future<bool> productCategoryNameExists(
    String name, {
    int? excludeCategoryId,
  }) async {
    final cleanName = name.trim().toLowerCase();

    if (cleanName.isEmpty) {
      return false;
    }

    final rows = await select(productCategories).get();

    return rows.any(
      (category) =>
          category.id != excludeCategoryId &&
          category.name.trim().toLowerCase() == cleanName,
    );
  }

  Future<int> createProductCategory({
    required String name,
    String? description,
  }) async {
    final cleanName = name.trim();
    final cleanDescription = _cleanOptionalText(description);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre de la categoría es obligatorio.');
    }

    if (cleanName.length > 80) {
      throw ArgumentError('La categoría no puede superar los 80 caracteres.');
    }

    if (await productCategoryNameExists(cleanName)) {
      throw StateError('Ya existe una categoría con ese nombre.');
    }

    return into(productCategories).insert(
      ProductCategoriesCompanion(
        name: Value(cleanName),
        description: Value(cleanDescription),
      ),
    );
  }

  Future<void> updateProductCategory({
    required int categoryId,
    required String name,
    String? description,
  }) async {
    final cleanName = name.trim();
    final cleanDescription = _cleanOptionalText(description);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre de la categoría es obligatorio.');
    }

    if (cleanName.length > 80) {
      throw ArgumentError('La categoría no puede superar los 80 caracteres.');
    }

    if (await productCategoryNameExists(
      cleanName,
      excludeCategoryId: categoryId,
    )) {
      throw StateError('Ya existe una categoría con ese nombre.');
    }

    final affectedRows =
        await (update(
          productCategories,
        )..where((tbl) => tbl.id.equals(categoryId))).write(
          ProductCategoriesCompanion(
            name: Value(cleanName),
            description: Value(cleanDescription),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (affectedRows == 0) {
      throw StateError('No se encontró la categoría.');
    }
  }

  Future<void> setProductCategoryActive({
    required int categoryId,
    required bool isActive,
  }) async {
    final affectedRows =
        await (update(
          productCategories,
        )..where((tbl) => tbl.id.equals(categoryId))).write(
          ProductCategoriesCompanion(
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (affectedRows == 0) {
      throw StateError('No se encontró la categoría.');
    }
  }

  Stream<List<ProductCatalogItem>> watchCatalogProducts() {
    final query = select(products).join([
      leftOuterJoin(
        productCategories,
        productCategories.id.equalsExp(products.categoryId),
      ),
    ]);

    query.where(
      products.isActive.equals(true) & products.showInCatalog.equals(true),
    );

    query.orderBy([
      OrderingTerm.asc(productCategories.name),
      OrderingTerm.asc(products.name),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ProductCatalogItem(
          product: row.readTable(products),
          category: row.readTableOrNull(productCategories),
        );
      }).toList();
    });
  }

  Stream<ProductCatalogItem?> watchCatalogProductById(int productId) {
    final query = select(products).join([
      leftOuterJoin(
        productCategories,
        productCategories.id.equalsExp(products.categoryId),
      ),
    ]);

    query.where(products.id.equals(productId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      return ProductCatalogItem(
        product: row.readTable(products),
        category: row.readTableOrNull(productCategories),
      );
    });
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
    return update(
      products,
    ).replace(product.copyWith(updatedAt: DateTime.now()));
  }

  Future<int> deactivateProduct(int productId) {
    return (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> setProductActive({
    required int productId,
    required bool isActive,
  }) async {
    final productRows = await (select(
      products,
    )..where((tbl) => tbl.id.equals(productId))).get();

    if (productRows.isEmpty) {
      throw StateError('No se encontró el producto.');
    }

    return (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        isActive: Value(isActive),
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
    final rows = await (select(
      products,
    )..where((tbl) => tbl.id.equals(productId))).get();

    if (rows.isEmpty) return null;

    return rows.first;
  }

  Future<int> updateProductInfo({
    required int id,
    required String name,
    String? sku,
    String? barcode,
    String? description,
    int? categoryId,
    Uint8List? imageBytes,
    required bool showInCatalog,
    required bool allowNegativeStock,
    required int purchasePriceCents,
    required int salePriceCents,
    required int minStock,
  }) async {
    final existingProduct = await getProductById(id);

    if (existingProduct == null) {
      throw StateError('No se encontró el producto.');
    }

    if (!allowNegativeStock && existingProduct.currentStock < 0) {
      throw StateError(
        'No puedes desactivar las existencias negativas '
        'mientras el stock actual sea '
        '${existingProduct.currentStock}. '
        'Primero ajusta el stock a cero o a una cantidad positiva.',
      );
    }

    return (update(products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        sku: Value(sku),
        barcode: Value(barcode),
        description: Value(description),
        categoryId: Value(categoryId),
        imageBytes: Value(imageBytes),
        showInCatalog: Value(showInCatalog),
        allowNegativeStock: Value(allowNegativeStock),
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
      final product = await (select(
        products,
      )..where((tbl) => tbl.id.equals(productId))).getSingle();

      final newStock = product.currentStock + quantity;

      if (newStock < 0 && !product.allowNegativeStock) {
        throw StateError(
          'El stock de "${product.name}" no puede quedar en negativo.',
        );
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
  // Proveedores
  // -------------------------

  Stream<List<Supplier>> watchSuppliers({bool includeInactive = false}) {
    final query = select(suppliers);

    if (!includeInactive) {
      query.where((tbl) => tbl.isActive.equals(true));
    }

    query.orderBy([
      (tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc),
    ]);

    return query.watch();
  }

  Stream<Supplier?> watchSupplierById(int supplierId) {
    return (select(suppliers)..where((tbl) => tbl.id.equals(supplierId)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<Supplier?> getSupplierById(int supplierId) async {
    final rows = await (select(
      suppliers,
    )..where((tbl) => tbl.id.equals(supplierId))).get();

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  Future<bool> supplierTaxIdExists(
    String taxId, {
    int? excludeSupplierId,
  }) async {
    final cleanTaxId = taxId.trim();

    if (cleanTaxId.isEmpty) {
      return false;
    }

    final rows = await (select(
      suppliers,
    )..where((tbl) => tbl.taxId.equals(cleanTaxId))).get();

    return rows.any((supplier) => supplier.id != excludeSupplierId);
  }

  Future<int> createSupplier({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? taxId,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    final cleanTaxId = _cleanOptionalText(taxId);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre del proveedor es obligatorio.');
    }

    if (cleanTaxId != null) {
      final duplicatedTaxId = await supplierTaxIdExists(cleanTaxId);

      if (duplicatedTaxId) {
        throw StateError(
          'Ya existe un proveedor con ese RFC o identificador fiscal.',
        );
      }
    }

    return into(suppliers).insert(
      SuppliersCompanion(
        name: Value(cleanName),
        contactName: Value(_cleanOptionalText(contactName)),
        phone: Value(_cleanOptionalText(phone)),
        email: Value(_cleanOptionalText(email)),
        taxId: Value(cleanTaxId),
        address: Value(_cleanOptionalText(address)),
        notes: Value(_cleanOptionalText(notes)),
      ),
    );
  }

  Future<int> updateSupplierInfo({
    required int supplierId,
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? taxId,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    final cleanTaxId = _cleanOptionalText(taxId);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre del proveedor es obligatorio.');
    }

    final existingSupplier = await getSupplierById(supplierId);

    if (existingSupplier == null) {
      throw StateError('No se encontró el proveedor.');
    }

    if (cleanTaxId != null) {
      final duplicatedTaxId = await supplierTaxIdExists(
        cleanTaxId,
        excludeSupplierId: supplierId,
      );

      if (duplicatedTaxId) {
        throw StateError(
          'Ya existe otro proveedor con ese RFC o identificador fiscal.',
        );
      }
    }

    return (update(suppliers)..where((tbl) => tbl.id.equals(supplierId))).write(
      SuppliersCompanion(
        name: Value(cleanName),
        contactName: Value(_cleanOptionalText(contactName)),
        phone: Value(_cleanOptionalText(phone)),
        email: Value(_cleanOptionalText(email)),
        taxId: Value(cleanTaxId),
        address: Value(_cleanOptionalText(address)),
        notes: Value(_cleanOptionalText(notes)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> setSupplierActive({
    required int supplierId,
    required bool isActive,
  }) async {
    final existingSupplier = await getSupplierById(supplierId);

    if (existingSupplier == null) {
      throw StateError('No se encontró el proveedor.');
    }

    return (update(suppliers)..where((tbl) => tbl.id.equals(supplierId))).write(
      SuppliersCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _cleanOptionalText(String? value) {
    final cleanValue = value?.trim();

    if (cleanValue == null || cleanValue.isEmpty) {
      return null;
    }

    return cleanValue;
  }

  // -------------------------
  // Compras
  // -------------------------

  Stream<List<Purchase>> watchAllPurchases() {
    return (select(purchases)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<Purchase?> watchPurchaseById(int purchaseId) {
    return (select(purchases)..where((tbl) => tbl.id.equals(purchaseId)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Stream<List<PurchaseItemDetail>> watchPurchaseItemsWithProducts(
    int purchaseId,
  ) {
    final query = select(purchaseItems).join([
      innerJoin(products, products.id.equalsExp(purchaseItems.productId)),
    ]);

    query.where(purchaseItems.purchaseId.equals(purchaseId));

    return query.watch().map((rows) {
      return rows.map((row) {
        return PurchaseItemDetail(
          purchaseItem: row.readTable(purchaseItems),
          product: row.readTable(products),
        );
      }).toList();
    });
  }

  Future<int> createPurchase({
    required int supplierId,
    String? note,
    required List<PurchaseLineInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('La compra debe contener al menos un producto.');
    }

    final productIds = <int>{};

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Todas las cantidades deben ser mayores que cero.');
      }

      if (item.unitCostCents < 0) {
        throw ArgumentError('El costo de compra no puede ser negativo.');
      }

      if (!productIds.add(item.productId)) {
        throw ArgumentError(
          'El mismo producto no puede aparecer dos veces en la compra.',
        );
      }
    }

    final cleanNote = _cleanOptionalText(note);

    final totalCents = items.fold<int>(
      0,
      (total, item) => total + item.subtotalCents,
    );

    return transaction(() async {
      final supplierRows =
          await (select(suppliers)..where(
                (tbl) => tbl.id.equals(supplierId) & tbl.isActive.equals(true),
              ))
              .get();

      if (supplierRows.isEmpty) {
        throw StateError(
          'El proveedor seleccionado no existe o está inactivo.',
        );
      }

      final supplier = supplierRows.first;

      final purchaseId = await into(purchases).insert(
        PurchasesCompanion(
          supplierId: Value(supplier.id),
          supplierName: Value(supplier.name),
          note: Value(cleanNote),
          totalCents: Value(totalCents),
          status: const Value('completed'),
        ),
      );

      for (final item in items) {
        final productRows = await (select(
          products,
        )..where((tbl) => tbl.id.equals(item.productId))).get();

        if (productRows.isEmpty) {
          throw StateError(
            'No se encontró el producto con ID ${item.productId}.',
          );
        }

        final product = productRows.first;

        if (!product.isActive) {
          throw StateError('El producto "${product.name}" está inactivo.');
        }

        final newStock = product.currentStock + item.quantity;

        await into(purchaseItems).insert(
          PurchaseItemsCompanion(
            purchaseId: Value(purchaseId),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitCostCents: Value(item.unitCostCents),
            subtotalCents: Value(item.subtotalCents),
          ),
        );

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(item.productId))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            purchasePriceCents: Value(item.unitCostCents),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(item.productId),
            type: const Value('purchase_entry'),
            quantity: Value(item.quantity),
            stockAfterMovement: Value(newStock),
            note: Value('Compra #$purchaseId · ${supplier.name}'),
          ),
        );
      }

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('expense'),
          concept: Value('Compra #$purchaseId'),
          amountCents: Value(totalCents),
          note: Value(
            cleanNote == null
                ? 'Proveedor: ${supplier.name}'
                : 'Proveedor: ${supplier.name} · $cleanNote',
          ),
        ),
      );

      return purchaseId;
    });
  }

  Future<void> cancelPurchase(int purchaseId) async {
    await transaction(() async {
      final purchaseRows = await (select(
        purchases,
      )..where((tbl) => tbl.id.equals(purchaseId))).get();

      if (purchaseRows.isEmpty) {
        throw StateError('No se encontró la compra.');
      }

      final purchase = purchaseRows.first;

      if (purchase.status == 'cancelled') {
        throw StateError('La compra ya está cancelada.');
      }

      if (purchase.status != 'completed') {
        throw StateError('La compra no se encuentra completada.');
      }

      final itemRows = await (select(
        purchaseItems,
      )..where((tbl) => tbl.purchaseId.equals(purchaseId))).get();

      if (itemRows.isEmpty) {
        throw StateError('La compra no contiene productos.');
      }

      // Agrupamos cantidades para protegernos incluso si existieran
      // varias partidas del mismo producto.
      final quantitiesByProductId = <int, int>{};

      for (final item in itemRows) {
        quantitiesByProductId.update(
          item.productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final productsById = <int, Product>{};

      // Primero validamos todo. Todavía no modificamos el inventario.
      for (final entry in quantitiesByProductId.entries) {
        final productRows = await (select(
          products,
        )..where((tbl) => tbl.id.equals(entry.key))).get();

        if (productRows.isEmpty) {
          throw StateError('No se encontró el producto con ID ${entry.key}.');
        }

        final product = productRows.first;
        final quantityToRemove = entry.value;

        if (!product.allowNegativeStock &&
            product.currentStock < quantityToRemove) {
          throw StateError(
            'No se puede cancelar la compra porque '
            '"${product.name}" solo tiene ${product.currentStock} '
            'unidades disponibles y se necesitan '
            '$quantityToRemove.',
          );
        }

        productsById[product.id] = product;
      }

      final supplierName = purchase.supplierName?.trim();

      final movementNote = supplierName != null && supplierName.isNotEmpty
          ? 'Cancelación compra #$purchaseId · $supplierName'
          : 'Cancelación compra #$purchaseId';

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('income'),
          concept: Value('Cancelación compra #$purchaseId'),
          amountCents: Value(purchase.totalCents),
          note: Value(
            purchase.supplierName == null
                ? 'Reembolso de compra'
                : 'Reembolso de ${purchase.supplierName}',
          ),
        ),
      );

      // Después de validar todos los productos, hacemos los cambios.
      for (final entry in quantitiesByProductId.entries) {
        final product = productsById[entry.key]!;
        final quantityToRemove = entry.value;
        final newStock = product.currentStock - quantityToRemove;

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(product.id),
            type: const Value('purchase_cancellation'),
            quantity: Value(-quantityToRemove),
            stockAfterMovement: Value(newStock),
            note: Value(movementNote),
          ),
        );
      }

      await _reverseOrderAllocationsForPurchase(itemRows);

      await (update(purchases)..where((tbl) => tbl.id.equals(purchaseId)))
          .write(PurchasesCompanion(status: const Value('cancelled')));
    });
  }

  // -------------------------
  // Ventas
  // -------------------------

  Stream<List<Sale>> watchAllSales() {
    return (select(sales)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<Sale?> watchSaleById(int saleId) {
    return (select(sales)..where((tbl) => tbl.id.equals(saleId))).watch().map(
      (rows) => rows.isEmpty ? null : rows.first,
    );
  }

  Stream<List<SaleItemDetail>> watchSaleItemsWithProducts(int saleId) {
    final query = select(
      saleItems,
    ).join([innerJoin(products, products.id.equalsExp(saleItems.productId))]);

    query.where(saleItems.saleId.equals(saleId));

    return query.watch().map((rows) {
      return rows.map((row) {
        return SaleItemDetail(
          saleItem: row.readTable(saleItems),
          product: row.readTable(products),
        );
      }).toList();
    });
  }

  Future<int> createSale({
    String? customerName,
    required String paymentMethod,
    int discountCents = 0,
    required List<SaleLineInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('La venta debe contener al menos un producto.');
    }

    final cleanPaymentMethod = paymentMethod.trim().toLowerCase();

    const allowedPaymentMethods = {'cash', 'card', 'transfer', 'mixed'};

    if (!allowedPaymentMethods.contains(cleanPaymentMethod)) {
      throw ArgumentError('El método de pago seleccionado no es válido.');
    }

    if (discountCents < 0) {
      throw ArgumentError('El descuento no puede ser negativo.');
    }

    final productIds = <int>{};

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Todas las cantidades deben ser mayores que cero.');
      }

      if (item.unitPriceCents < 0) {
        throw ArgumentError('El precio de venta no puede ser negativo.');
      }

      if (!productIds.add(item.productId)) {
        throw ArgumentError(
          'El mismo producto no puede aparecer dos veces en la venta.',
        );
      }
    }

    final subtotalCents = items.fold<int>(
      0,
      (total, item) => total + item.subtotalCents,
    );

    if (discountCents > subtotalCents) {
      throw ArgumentError('El descuento no puede ser mayor que el subtotal.');
    }

    final totalCents = subtotalCents - discountCents;
    final cleanCustomerName = _cleanOptionalText(customerName);

    return transaction(() async {
      final productsById = <int, Product>{};

      // Primero se valida toda la venta.
      // Todavía no se modifica el inventario.
      for (final item in items) {
        final productRows = await (select(
          products,
        )..where((tbl) => tbl.id.equals(item.productId))).get();

        if (productRows.isEmpty) {
          throw StateError(
            'No se encontró el producto con ID ${item.productId}.',
          );
        }

        final product = productRows.first;

        if (!product.isActive) {
          throw StateError('El producto "${product.name}" está inactivo.');
        }

        if (!product.allowNegativeStock &&
            product.currentStock < item.quantity) {
          throw StateError(
            'No hay suficiente stock de "${product.name}". '
            'Disponible: ${product.currentStock}. '
            'Solicitado: ${item.quantity}.',
          );
        }

        productsById[product.id] = product;
      }

      final saleId = await into(sales).insert(
        SalesCompanion(
          customerName: Value(cleanCustomerName),
          subtotalCents: Value(subtotalCents),
          discountCents: Value(discountCents),
          totalCents: Value(totalCents),
          paymentMethod: Value(cleanPaymentMethod),
          status: const Value('completed'),
        ),
      );

      for (final item in items) {
        final product = productsById[item.productId]!;
        final newStock = product.currentStock - item.quantity;

        await into(saleItems).insert(
          SaleItemsCompanion(
            saleId: Value(saleId),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitPriceCents: Value(item.unitPriceCents),
            unitCostCents: Value(product.purchasePriceCents),
            subtotalCents: Value(item.subtotalCents),
          ),
        );

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(item.productId))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            updatedAt: Value(DateTime.now()),
          ),
        );

        final movementNote = cleanCustomerName == null
            ? 'Salida por venta #$saleId'
            : 'Venta #$saleId · $cleanCustomerName';

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(item.productId),
            type: const Value('sale_exit'),
            quantity: Value(-item.quantity),
            stockAfterMovement: Value(newStock),
            note: Value(movementNote),
          ),
        );
      }

      final paymentMethodLabel = switch (cleanPaymentMethod) {
        'cash' => 'Efectivo',
        'card' => 'Tarjeta',
        'transfer' => 'Transferencia',
        'mixed' => 'Pago mixto',
        _ => cleanPaymentMethod,
      };

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('income'),
          concept: Value('Venta #$saleId · $paymentMethodLabel'),
          amountCents: Value(totalCents),
          note: Value(cleanCustomerName),
        ),
      );

      return saleId;
    });
  }

  Future<void> cancelSale(int saleId) async {
    await transaction(() async {
      final saleRows = await (select(
        sales,
      )..where((tbl) => tbl.id.equals(saleId))).get();

      if (saleRows.isEmpty) {
        throw StateError('No se encontró la venta.');
      }

      final sale = saleRows.first;

      if (sale.status == 'cancelled') {
        throw StateError('La venta ya está cancelada.');
      }

      if (sale.status != 'completed') {
        throw StateError('La venta no se encuentra completada.');
      }

      final itemRows = await (select(
        saleItems,
      )..where((tbl) => tbl.saleId.equals(saleId))).get();

      if (itemRows.isEmpty) {
        throw StateError('La venta no contiene productos.');
      }

      // Agrupamos las cantidades por producto para protegernos
      // incluso si existieran partidas repetidas.
      final quantitiesByProductId = <int, int>{};

      for (final item in itemRows) {
        quantitiesByProductId.update(
          item.productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final productsById = <int, Product>{};

      // Validamos que todos los productos sigan existiendo.
      for (final productId in quantitiesByProductId.keys) {
        final productRows = await (select(
          products,
        )..where((tbl) => tbl.id.equals(productId))).get();

        if (productRows.isEmpty) {
          throw StateError('No se encontró el producto con ID $productId.');
        }

        final product = productRows.first;

        productsById[product.id] = product;
      }

      final customerName = sale.customerName?.trim();

      final movementNote = customerName != null && customerName.isNotEmpty
          ? 'Cancelación venta #$saleId · $customerName'
          : 'Cancelación venta #$saleId';

      for (final entry in quantitiesByProductId.entries) {
        final product = productsById[entry.key]!;
        final quantityToReturn = entry.value;
        final newStock = product.currentStock + quantityToReturn;

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(product.id),
            type: const Value('sale_cancellation'),
            quantity: Value(quantityToReturn),
            stockAfterMovement: Value(newStock),
            note: Value(movementNote),
          ),
        );
      }

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('expense'),
          concept: Value('Cancelación venta #$saleId'),
          amountCents: Value(sale.totalCents),
          note: Value(
            customerName != null && customerName.isNotEmpty
                ? 'Devolución a $customerName'
                : 'Devolución a público general',
          ),
        ),
      );

      await (update(sales)..where((tbl) => tbl.id.equals(saleId))).write(
        const SalesCompanion(status: Value('cancelled')),
      );
    });
  }

  // -------------------------
  // Inventario
  // -------------------------

  Stream<List<Product>> watchInventoryProducts({bool includeInactive = true}) {
    final query = select(products);

    if (!includeInactive) {
      query.where((tbl) => tbl.isActive.equals(true));
    }

    query.orderBy([
      (tbl) =>
          OrderingTerm(expression: tbl.currentStock, mode: OrderingMode.asc),
      (tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc),
    ]);

    return query.watch();
  }

  Stream<List<InventoryMovementDetail>> watchAllInventoryMovements() {
    final query = select(inventoryMovements).join([
      innerJoin(products, products.id.equalsExp(inventoryMovements.productId)),
    ]);

    query.orderBy([
      OrderingTerm(
        expression: inventoryMovements.createdAt,
        mode: OrderingMode.desc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return InventoryMovementDetail(
          movement: row.readTable(inventoryMovements),
          product: row.readTable(products),
        );
      }).toList();
    });
  }

  // -------------------------
  // Gastos
  // -------------------------

  Stream<List<Expense>> watchAllExpenses() {
    return (select(expenses)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<Expense?> watchExpenseById(int expenseId) {
    return (select(expenses)..where((tbl) => tbl.id.equals(expenseId)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<int> createExpense({
    required String category,
    String? description,
    required int amountCents,
  }) async {
    final cleanCategory = category.trim();
    final cleanDescription = _cleanOptionalText(description);

    if (cleanCategory.isEmpty) {
      throw ArgumentError('La categoría del gasto es obligatoria.');
    }

    if (cleanCategory.length > 80) {
      throw ArgumentError('La categoría no puede superar los 80 caracteres.');
    }

    if (amountCents <= 0) {
      throw ArgumentError('El importe del gasto debe ser mayor que cero.');
    }

    return transaction(() async {
      final expenseId = await into(expenses).insert(
        ExpensesCompanion(
          category: Value(cleanCategory),
          description: Value(cleanDescription),
          amountCents: Value(amountCents),
        ),
      );

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('expense'),
          concept: Value('Gasto · $cleanCategory'),
          amountCents: Value(amountCents),
          note: Value(cleanDescription),
        ),
      );

      return expenseId;
    });
  }

  // -------------------------
  // Movimientos de caja
  // -------------------------

  Stream<List<CashTransaction>> watchAllCashTransactions() {
    return (select(cashTransactions)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> createCashTransaction({
    required String type,
    required String concept,
    required int amountCents,
    String? note,
  }) async {
    final cleanType = type.trim().toLowerCase();
    final cleanConcept = concept.trim();
    final cleanNote = _cleanOptionalText(note);

    const allowedTypes = {'income', 'expense'};

    if (!allowedTypes.contains(cleanType)) {
      throw ArgumentError('El tipo de movimiento de caja no es válido.');
    }

    if (cleanConcept.isEmpty) {
      throw ArgumentError('El concepto es obligatorio.');
    }

    if (cleanConcept.length > 120) {
      throw ArgumentError('El concepto no puede superar los 120 caracteres.');
    }

    if (amountCents <= 0) {
      throw ArgumentError('El importe debe ser mayor que cero.');
    }

    return into(cashTransactions).insert(
      CashTransactionsCompanion(
        type: Value(cleanType),
        concept: Value(cleanConcept),
        amountCents: Value(amountCents),
        note: Value(cleanNote),
      ),
    );
  }

  // -------------------------
  // Reportes
  // -------------------------

  Stream<BusinessReportSummary> watchBusinessReportSummary({
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) {
      throw ArgumentError(
        'La fecha final debe ser posterior a la fecha inicial.',
      );
    }

    final query = customSelect(
      '''
      WITH period AS (
        SELECT
          ? AS start_at,
          ? AS end_at
      ),
      sales_totals AS (
        SELECT
          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'completed' THEN 1
                ELSE 0
              END
            ),
            0
          ) AS completed_sales_count,

          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'cancelled' THEN 1
                ELSE 0
              END
            ),
            0
          ) AS cancelled_sales_count,

          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'completed'
                  THEN s.total_cents
                ELSE 0
              END
            ),
            0
          ) AS sales_total_cents,

          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'completed'
                  THEN s.discount_cents
                ELSE 0
              END
            ),
            0
          ) AS discounts_cents

        FROM sales AS s
        CROSS JOIN period AS p

        WHERE s.created_at >= p.start_at
          AND s.created_at < p.end_at
      ),
      item_totals AS (
        SELECT
          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'completed'
                  THEN si.quantity
                ELSE 0
              END
            ),
            0
          ) AS sold_units,

          COALESCE(
            SUM(
              CASE
                WHEN s.status = 'completed'
                  AND si.unit_cost_cents IS NOT NULL
                  THEN si.quantity * si.unit_cost_cents
                ELSE 0
              END
            ),
            0
          ) AS cost_of_goods_sold_cents,

          COUNT(
            DISTINCT CASE
              WHEN s.status = 'completed'
                AND si.unit_cost_cents IS NULL
                THEN s.id
              ELSE NULL
            END
          ) AS sales_without_historical_cost

        FROM sale_items AS si

        INNER JOIN sales AS s
          ON s.id = si.sale_id

        CROSS JOIN period AS p

        WHERE s.created_at >= p.start_at
          AND s.created_at < p.end_at
      ),
      expense_totals AS (
        SELECT
          COALESCE(
            SUM(e.amount_cents),
            0
          ) AS expenses_cents

        FROM expenses AS e
        CROSS JOIN period AS p

        WHERE e.created_at >= p.start_at
          AND e.created_at < p.end_at
      )

      SELECT
        st.completed_sales_count,
        st.cancelled_sales_count,
        st.sales_total_cents,
        st.discounts_cents,
        it.sold_units,
        it.cost_of_goods_sold_cents,
        it.sales_without_historical_cost,
        et.expenses_cents

      FROM sales_totals AS st
      CROSS JOIN item_totals AS it
      CROSS JOIN expense_totals AS et
      ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {sales, saleItems, expenses},
    );

    return query.watch().map((rows) {
      final row = rows.first;

      return BusinessReportSummary(
        completedSalesCount: row.read<int>('completed_sales_count'),
        cancelledSalesCount: row.read<int>('cancelled_sales_count'),
        salesTotalCents: row.read<int>('sales_total_cents'),
        discountsCents: row.read<int>('discounts_cents'),
        soldUnits: row.read<int>('sold_units'),
        costOfGoodsSoldCents: row.read<int>('cost_of_goods_sold_cents'),
        salesWithoutHistoricalCost: row.read<int>(
          'sales_without_historical_cost',
        ),
        expensesCents: row.read<int>('expenses_cents'),
      );
    });
  }

  Stream<List<ProductSalesReport>> watchProductSalesReport({
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) {
      throw ArgumentError(
        'La fecha final debe ser posterior a la fecha inicial.',
      );
    }

    final query = customSelect(
      '''
      SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.sku AS product_sku,

        COALESCE(
          SUM(si.quantity),
          0
        ) AS quantity_sold,

        COALESCE(
          SUM(si.subtotal_cents),
          0
        ) AS sales_subtotal_cents,

        COALESCE(
          SUM(
            CASE
              WHEN si.unit_cost_cents IS NOT NULL
                THEN si.quantity * si.unit_cost_cents
              ELSE 0
            END
          ),
          0
        ) AS known_cost_cents,

        MAX(
          CASE
            WHEN si.unit_cost_cents IS NULL THEN 1
            ELSE 0
          END
        ) AS has_missing_historical_cost

      FROM sale_items AS si

      INNER JOIN sales AS s
        ON s.id = si.sale_id

      INNER JOIN products AS p
        ON p.id = si.product_id

      WHERE s.status = 'completed'
        AND s.created_at >= ?
        AND s.created_at < ?

      GROUP BY
        p.id,
        p.name,
        p.sku

      ORDER BY
        quantity_sold DESC,
        sales_subtotal_cents DESC,
        p.name ASC
      ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {sales, saleItems, products},
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        return ProductSalesReport(
          productId: row.read<int>('product_id'),
          productName: row.read<String>('product_name'),
          sku: row.readNullable<String>('product_sku'),
          quantitySold: row.read<int>('quantity_sold'),
          salesSubtotalCents: row.read<int>('sales_subtotal_cents'),
          knownCostCents: row.read<int>('known_cost_cents'),
          hasMissingHistoricalCost:
              row.read<int>('has_missing_historical_cost') == 1,
        );
      }).toList();
    });
  }

  // -------------------------
  // Respaldos
  // -------------------------

  Future<void> createBackupAt(String filePath) async {
    final cleanFilePath = filePath.trim();

    if (cleanFilePath.isEmpty) {
      throw ArgumentError('La ruta del respaldo es obligatoria.');
    }

    // En los textos SQL, una comilla simple se escapa
    // duplicándola.
    final escapedFilePath = cleanFilePath.replaceAll("'", "''");

    await customStatement("VACUUM INTO '$escapedFilePath'");
  }

  // -------------------------
  // Clientes
  // -------------------------

  Stream<List<Customer>> watchAllCustomers({bool includeInactive = false}) {
    final query = select(customers);

    if (!includeInactive) {
      query.where((tbl) => tbl.isActive.equals(true));
    }

    query.orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);

    return query.watch();
  }

  Stream<Customer?> watchCustomerById(int customerId) {
    return (select(
      customers,
    )..where((tbl) => tbl.id.equals(customerId))).watchSingleOrNull();
  }

  Future<int> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = _cleanOptionalText(phone);
    final cleanEmail = _cleanOptionalText(email);
    final cleanAddress = _cleanOptionalText(address);
    final cleanNotes = _cleanOptionalText(notes);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre del cliente es obligatorio.');
    }

    if (cleanName.length > 120) {
      throw ArgumentError(
        'El nombre del cliente no puede exceder 120 caracteres.',
      );
    }

    if (cleanPhone != null && cleanPhone.length > 30) {
      throw ArgumentError('El teléfono no puede exceder 30 caracteres.');
    }

    if (cleanEmail != null && cleanEmail.length > 150) {
      throw ArgumentError('El correo no puede exceder 150 caracteres.');
    }

    return into(customers).insert(
      CustomersCompanion(
        name: Value(cleanName),
        phone: Value(cleanPhone),
        email: Value(cleanEmail),
        address: Value(cleanAddress),
        notes: Value(cleanNotes),
      ),
    );
  }

  Future<void> updateCustomer({
    required int customerId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = _cleanOptionalText(phone);
    final cleanEmail = _cleanOptionalText(email);
    final cleanAddress = _cleanOptionalText(address);
    final cleanNotes = _cleanOptionalText(notes);

    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre del cliente es obligatorio.');
    }

    if (cleanName.length > 120) {
      throw ArgumentError(
        'El nombre del cliente no puede exceder 120 caracteres.',
      );
    }

    if (cleanPhone != null && cleanPhone.length > 30) {
      throw ArgumentError('El teléfono no puede exceder 30 caracteres.');
    }

    if (cleanEmail != null && cleanEmail.length > 150) {
      throw ArgumentError('El correo no puede exceder 150 caracteres.');
    }

    final affectedRows =
        await (update(
          customers,
        )..where((tbl) => tbl.id.equals(customerId))).write(
          CustomersCompanion(
            name: Value(cleanName),
            phone: Value(cleanPhone),
            email: Value(cleanEmail),
            address: Value(cleanAddress),
            notes: Value(cleanNotes),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (affectedRows == 0) {
      throw StateError('No se encontró el cliente.');
    }
  }

  Future<void> setCustomerActive({
    required int customerId,
    required bool isActive,
  }) async {
    final affectedRows =
        await (update(
          customers,
        )..where((tbl) => tbl.id.equals(customerId))).write(
          CustomersCompanion(
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );

    if (affectedRows == 0) {
      throw StateError('No se encontró el cliente.');
    }
  }

  // -------------------------
  // Pedidos de clientes
  // -------------------------

  Stream<List<CustomerOrderWithCustomer>> watchAllCustomerOrders() {
    final query = select(customerOrders).join([
      innerJoin(customers, customers.id.equalsExp(customerOrders.customerId)),
    ]);

    query.orderBy([
      OrderingTerm(
        expression: customerOrders.createdAt,
        mode: OrderingMode.desc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return CustomerOrderWithCustomer(
          order: row.readTable(customerOrders),
          customer: row.readTable(customers),
        );
      }).toList();
    });
  }

  Stream<List<CustomerOrderWithCustomer>> watchCustomerOrdersByCustomer(
    int customerId,
  ) {
    final query = select(customerOrders).join([
      innerJoin(customers, customers.id.equalsExp(customerOrders.customerId)),
    ]);

    query.where(customerOrders.customerId.equals(customerId));

    query.orderBy([
      OrderingTerm(
        expression: customerOrders.createdAt,
        mode: OrderingMode.desc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return CustomerOrderWithCustomer(
          order: row.readTable(customerOrders),
          customer: row.readTable(customers),
        );
      }).toList();
    });
  }

  Stream<CustomerOrderWithCustomer?> watchCustomerOrderById(int orderId) {
    final query = select(customerOrders).join([
      innerJoin(customers, customers.id.equalsExp(customerOrders.customerId)),
    ]);

    query.where(customerOrders.id.equals(orderId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      return CustomerOrderWithCustomer(
        order: row.readTable(customerOrders),
        customer: row.readTable(customers),
      );
    });
  }

  Stream<List<CustomerOrderItemDetail>> watchCustomerOrderItems(int orderId) {
    final query = select(customerOrderItems).join([
      innerJoin(products, products.id.equalsExp(customerOrderItems.productId)),
    ]);

    query.where(customerOrderItems.orderId.equals(orderId));

    query.orderBy([
      OrderingTerm(expression: customerOrderItems.id, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return CustomerOrderItemDetail(
          orderItem: row.readTable(customerOrderItems),
          product: row.readTable(products),
        );
      }).toList();
    });
  }

  Future<int> createCustomerOrder({
    required int customerId,
    required List<CustomerOrderLineInput> items,
    String? notes,
  }) async {
    final cleanNotes = _cleanOptionalText(notes);

    if (items.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un producto.');
    }

    final customerRows = await (select(
      customers,
    )..where((tbl) => tbl.id.equals(customerId))).get();

    if (customerRows.isEmpty) {
      throw StateError('No se encontró el cliente.');
    }

    final customer = customerRows.first;

    if (!customer.isActive) {
      throw StateError(
        'No se pueden registrar pedidos '
        'para un cliente inactivo.',
      );
    }

    final productIds = items.map((item) => item.productId).toSet();

    if (productIds.length != items.length) {
      throw ArgumentError(
        'El mismo producto aparece más de una vez '
        'en el pedido.',
      );
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Todas las cantidades deben ser mayores a cero.');
      }
    }

    final productRows = await (select(
      products,
    )..where((tbl) => tbl.id.isIn(productIds))).get();

    if (productRows.length != productIds.length) {
      throw StateError('Uno o más productos ya no existen.');
    }

    final productsById = {
      for (final product in productRows) product.id: product,
    };

    for (final item in items) {
      final product = productsById[item.productId]!;

      if (!product.isActive) {
        throw StateError(
          'El producto "${product.name}" '
          'está inactivo.',
        );
      }
    }

    return transaction(() async {
      final orderId = await into(customerOrders).insert(
        CustomerOrdersCompanion(
          customerId: Value(customerId),
          status: const Value(CustomerOrderStatus.pending),
          notes: Value(cleanNotes),
        ),
      );

      for (final item in items) {
        final product = productsById[item.productId]!;

        await into(customerOrderItems).insert(
          CustomerOrderItemsCompanion(
            orderId: Value(orderId),
            productId: Value(product.id),
            productName: Value(product.name),
            quantityRequested: Value(item.quantity),
            quantityFulfilled: const Value(0),
            notes: Value(_cleanOptionalText(item.notes)),
          ),
        );
      }

      return orderId;
    });
  }

  Future<void> updateCustomerOrder({
    required int orderId,
    required int customerId,
    required List<CustomerOrderLineInput> items,
    String? notes,
  }) async {
    final cleanNotes = _cleanOptionalText(notes);

    if (items.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un producto.');
    }

    final productIds = items.map((item) => item.productId).toSet();

    if (productIds.length != items.length) {
      throw ArgumentError(
        'El mismo producto aparece más de una vez en el pedido.',
      );
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Todas las cantidades deben ser mayores a cero.');
      }
    }

    await transaction(() async {
      final orderRows = await (select(
        customerOrders,
      )..where((tbl) => tbl.id.equals(orderId))).get();

      if (orderRows.isEmpty) {
        throw StateError('No se encontró el pedido.');
      }

      final order = orderRows.first;

      if (order.status == CustomerOrderStatus.cancelled) {
        throw StateError('Un pedido cancelado no puede editarse.');
      }

      if (order.status == CustomerOrderStatus.fulfilled) {
        throw StateError('Un pedido completamente surtido no puede editarse.');
      }

      final existingItems = await (select(
        customerOrderItems,
      )..where((tbl) => tbl.orderId.equals(orderId))).get();

      final hasFulfilledItems = existingItems.any(
        (item) => item.quantityFulfilled > 0,
      );

      if (hasFulfilledItems && customerId != order.customerId) {
        throw StateError(
          'No puedes cambiar el cliente porque el pedido '
          'ya tiene productos surtidos.',
        );
      }

      final customerRows = await (select(
        customers,
      )..where((tbl) => tbl.id.equals(customerId))).get();

      if (customerRows.isEmpty) {
        throw StateError('No se encontró el cliente.');
      }

      final customer = customerRows.first;

      if (!customer.isActive) {
        throw StateError('El cliente seleccionado está inactivo.');
      }

      final productRows = await (select(
        products,
      )..where((tbl) => tbl.id.isIn(productIds))).get();

      if (productRows.length != productIds.length) {
        throw StateError('Uno o más productos ya no existen.');
      }

      final productsById = {
        for (final product in productRows) product.id: product,
      };

      final existingItemsByProductId = {
        for (final item in existingItems) item.productId: item,
      };

      for (final input in items) {
        final product = productsById[input.productId]!;

        final existingItem = existingItemsByProductId[input.productId];

        if (!product.isActive && existingItem == null) {
          throw StateError('El producto "${product.name}" está inactivo.');
        }

        if (existingItem != null &&
            input.quantity < existingItem.quantityFulfilled) {
          throw StateError(
            'La cantidad solicitada de '
            '"${existingItem.productName}" no puede ser menor '
            'que las ${existingItem.quantityFulfilled} unidades '
            'que ya fueron surtidas.',
          );
        }
      }

      final requestedProductIds = items.map((item) => item.productId).toSet();

      final itemsToDelete = existingItems.where(
        (item) => !requestedProductIds.contains(item.productId),
      );

      for (final existingItem in itemsToDelete) {
        if (existingItem.quantityFulfilled > 0) {
          throw StateError(
            'No puedes eliminar '
            '"${existingItem.productName}" porque ya tiene '
            '${existingItem.quantityFulfilled} unidades surtidas.',
          );
        }
      }

      await (update(
        customerOrders,
      )..where((tbl) => tbl.id.equals(orderId))).write(
        CustomerOrdersCompanion(
          customerId: Value(customerId),
          notes: Value(cleanNotes),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final itemIdsToDelete = itemsToDelete.map((item) => item.id).toList();

      if (itemIdsToDelete.isNotEmpty) {
        await (delete(
          customerOrderItems,
        )..where((tbl) => tbl.id.isIn(itemIdsToDelete))).go();
      }

      for (final input in items) {
        final product = productsById[input.productId]!;

        final existingItem = existingItemsByProductId[input.productId];

        final cleanItemNotes = _cleanOptionalText(input.notes);

        if (existingItem == null) {
          await into(customerOrderItems).insert(
            CustomerOrderItemsCompanion(
              orderId: Value(orderId),
              productId: Value(product.id),
              productName: Value(product.name),
              quantityRequested: Value(input.quantity),
              quantityFulfilled: const Value(0),
              notes: Value(cleanItemNotes),
            ),
          );
        } else {
          await (update(
            customerOrderItems,
          )..where((tbl) => tbl.id.equals(existingItem.id))).write(
            CustomerOrderItemsCompanion(
              productName: Value(product.name),
              quantityRequested: Value(input.quantity),
              notes: Value(cleanItemNotes),
            ),
          );
        }
      }

      await _recalculateCustomerOrderStatus(orderId);
    });
  }

  Future<void> cancelCustomerOrder(int orderId) async {
    final orderRows = await (select(
      customerOrders,
    )..where((tbl) => tbl.id.equals(orderId))).get();

    if (orderRows.isEmpty) {
      throw StateError('No se encontró el pedido.');
    }

    final order = orderRows.first;

    if (order.status == CustomerOrderStatus.cancelled) {
      return;
    }

    if (order.status == CustomerOrderStatus.fulfilled) {
      throw StateError(
        'Un pedido completamente surtido '
        'no puede cancelarse desde este módulo.',
      );
    }

    await (update(
      customerOrders,
    )..where((tbl) => tbl.id.equals(orderId))).write(
      CustomerOrdersCompanion(
        status: const Value(CustomerOrderStatus.cancelled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<PendingCustomerOrderItemDetail>>
  getPendingCustomerOrderItems() async {
    final query = select(customerOrderItems).join([
      innerJoin(
        customerOrders,
        customerOrders.id.equalsExp(customerOrderItems.orderId),
      ),
      innerJoin(customers, customers.id.equalsExp(customerOrders.customerId)),
      innerJoin(products, products.id.equalsExp(customerOrderItems.productId)),
    ]);

    query.where(
      customerOrders.status.isIn([
            CustomerOrderStatus.pending,
            CustomerOrderStatus.partiallyFulfilled,
          ]) &
          customerOrderItems.quantityFulfilled.isSmallerThan(
            customerOrderItems.quantityRequested,
          ),
    );

    query.orderBy([
      OrderingTerm.asc(products.name),
      OrderingTerm.asc(customers.name),
      OrderingTerm.asc(customerOrders.id),
    ]);

    final rows = await query.get();

    return rows.map((row) {
      return PendingCustomerOrderItemDetail(
        order: row.readTable(customerOrders),
        customer: row.readTable(customers),
        orderItem: row.readTable(customerOrderItems),
        product: row.readTable(products),
      );
    }).toList();
  }

  Future<int> createPurchaseFromOrderFulfillment({
    required int supplierId,
    String? note,
    required List<OrderFulfillmentLineInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Selecciona al menos un producto pendiente.');
    }

    final orderItemIds = <int>{};

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Todas las cantidades deben ser mayores que cero.');
      }

      if (item.unitCostCents < 0) {
        throw ArgumentError('El costo de compra no puede ser negativo.');
      }

      if (!orderItemIds.add(item.orderItemId)) {
        throw ArgumentError(
          'El mismo producto pendiente fue seleccionado más de una vez.',
        );
      }
    }

    final cleanNote = _cleanOptionalText(note);

    final totalCents = items.fold<int>(
      0,
      (total, item) => total + item.subtotalCents,
    );

    return transaction(() async {
      final supplierRows =
          await (select(suppliers)..where(
                (tbl) => tbl.id.equals(supplierId) & tbl.isActive.equals(true),
              ))
              .get();

      if (supplierRows.isEmpty) {
        throw StateError(
          'El proveedor seleccionado no existe o está inactivo.',
        );
      }

      final supplier = supplierRows.first;

      final orderItemRows = await (select(
        customerOrderItems,
      )..where((tbl) => tbl.id.isIn(orderItemIds))).get();

      if (orderItemRows.length != orderItemIds.length) {
        throw StateError('Uno o más productos del pedido ya no existen.');
      }

      final orderItemsById = {
        for (final orderItem in orderItemRows) orderItem.id: orderItem,
      };

      final orderIds = orderItemRows.map((item) => item.orderId).toSet();

      final orderRows = await (select(
        customerOrders,
      )..where((tbl) => tbl.id.isIn(orderIds))).get();

      if (orderRows.length != orderIds.length) {
        throw StateError('Uno o más pedidos ya no existen.');
      }

      final ordersById = {for (final order in orderRows) order.id: order};

      final productIds = orderItemRows.map((item) => item.productId).toSet();

      final productRows = await (select(
        products,
      )..where((tbl) => tbl.id.isIn(productIds))).get();

      if (productRows.length != productIds.length) {
        throw StateError('Uno o más productos ya no existen.');
      }

      final productsById = {
        for (final product in productRows) product.id: product,
      };

      for (final input in items) {
        final orderItem = orderItemsById[input.orderItemId]!;
        final order = ordersById[orderItem.orderId]!;
        final product = productsById[orderItem.productId]!;

        if (order.status == CustomerOrderStatus.cancelled) {
          throw StateError('El pedido #${order.id} está cancelado.');
        }

        if (order.status == CustomerOrderStatus.fulfilled) {
          throw StateError(
            'El pedido #${order.id} ya está completamente surtido.',
          );
        }

        final pendingQuantity =
            orderItem.quantityRequested - orderItem.quantityFulfilled;

        if (pendingQuantity <= 0) {
          throw StateError(
            'El producto "${orderItem.productName}" ya fue surtido.',
          );
        }

        if (input.quantity > pendingQuantity) {
          throw StateError(
            'Solo quedan $pendingQuantity unidades pendientes de '
            '"${orderItem.productName}".',
          );
        }

        if (!product.isActive) {
          throw StateError('El producto "${product.name}" está inactivo.');
        }
      }

      final purchaseId = await into(purchases).insert(
        PurchasesCompanion(
          supplierId: Value(supplier.id),
          supplierName: Value(supplier.name),
          note: Value(cleanNote),
          totalCents: Value(totalCents),
          status: const Value('completed'),
        ),
      );

      final stockByProductId = {
        for (final product in productRows) product.id: product.currentStock,
      };

      final affectedOrderIds = <int>{};

      for (final input in items) {
        final orderItem = orderItemsById[input.orderItemId]!;
        final product = productsById[orderItem.productId]!;
        final newStock = stockByProductId[product.id]! + input.quantity;

        stockByProductId[product.id] = newStock;

        final purchaseItemId = await into(purchaseItems).insert(
          PurchaseItemsCompanion(
            purchaseId: Value(purchaseId),
            productId: Value(product.id),
            quantity: Value(input.quantity),
            unitCostCents: Value(input.unitCostCents),
            subtotalCents: Value(input.subtotalCents),
          ),
        );

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            purchasePriceCents: Value(input.unitCostCents),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(product.id),
            type: const Value('purchase_entry'),
            quantity: Value(input.quantity),
            stockAfterMovement: Value(newStock),
            note: Value('Compra #$purchaseId · Pedido #${orderItem.orderId}'),
          ),
        );

        await into(orderPurchaseAllocations).insert(
          OrderPurchaseAllocationsCompanion(
            orderItemId: Value(orderItem.id),
            purchaseItemId: Value(purchaseItemId),
            quantity: Value(input.quantity),
          ),
        );

        await (update(
          customerOrderItems,
        )..where((tbl) => tbl.id.equals(orderItem.id))).write(
          CustomerOrderItemsCompanion(
            quantityFulfilled: Value(
              orderItem.quantityFulfilled + input.quantity,
            ),
          ),
        );

        affectedOrderIds.add(orderItem.orderId);
      }

      for (final orderId in affectedOrderIds) {
        await _recalculateCustomerOrderStatus(orderId);
      }

      await into(cashTransactions).insert(
        CashTransactionsCompanion(
          type: const Value('expense'),
          concept: Value('Compra #$purchaseId · Pedidos'),
          amountCents: Value(totalCents),
          note: Value(
            cleanNote == null
                ? 'Proveedor: ${supplier.name}'
                : 'Proveedor: ${supplier.name} · $cleanNote',
          ),
        ),
      );

      return purchaseId;
    });
  }

  Future<void> _recalculateCustomerOrderStatus(int orderId) async {
    final orderRows = await (select(
      customerOrders,
    )..where((tbl) => tbl.id.equals(orderId))).get();

    if (orderRows.isEmpty) {
      return;
    }

    final order = orderRows.first;

    if (order.status == CustomerOrderStatus.cancelled) {
      return;
    }

    final itemRows = await (select(
      customerOrderItems,
    )..where((tbl) => tbl.orderId.equals(orderId))).get();

    if (itemRows.isEmpty) {
      return;
    }

    final allFulfilled = itemRows.every(
      (item) => item.quantityFulfilled >= item.quantityRequested,
    );

    final anyFulfilled = itemRows.any((item) => item.quantityFulfilled > 0);

    final newStatus = allFulfilled
        ? CustomerOrderStatus.fulfilled
        : anyFulfilled
        ? CustomerOrderStatus.partiallyFulfilled
        : CustomerOrderStatus.pending;

    await (update(
      customerOrders,
    )..where((tbl) => tbl.id.equals(orderId))).write(
      CustomerOrdersCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _reverseOrderAllocationsForPurchase(
    List<PurchaseItem> purchaseItemRows,
  ) async {
    if (purchaseItemRows.isEmpty) {
      return;
    }

    final purchaseItemIds = purchaseItemRows.map((item) => item.id).toSet();

    final allocationRows = await (select(
      orderPurchaseAllocations,
    )..where((tbl) => tbl.purchaseItemId.isIn(purchaseItemIds))).get();

    if (allocationRows.isEmpty) {
      return;
    }

    final affectedOrderIds = <int>{};

    for (final allocation in allocationRows) {
      final orderItemRows = await (select(
        customerOrderItems,
      )..where((tbl) => tbl.id.equals(allocation.orderItemId))).get();

      if (orderItemRows.isEmpty) {
        continue;
      }

      final orderItem = orderItemRows.first;
      final newFulfilled = orderItem.quantityFulfilled - allocation.quantity;

      await (update(
        customerOrderItems,
      )..where((tbl) => tbl.id.equals(orderItem.id))).write(
        CustomerOrderItemsCompanion(
          quantityFulfilled: Value(newFulfilled < 0 ? 0 : newFulfilled),
        ),
      );

      affectedOrderIds.add(orderItem.orderId);
    }

    await (delete(
      orderPurchaseAllocations,
    )..where((tbl) => tbl.purchaseItemId.isIn(purchaseItemIds))).go();

    for (final orderId in affectedOrderIds) {
      await _recalculateCustomerOrderStatus(orderId);
    }
  }
}
