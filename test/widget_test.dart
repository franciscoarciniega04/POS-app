import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_offline/app/pos_app.dart';
import 'package:pos_offline/data/local/app_database.dart';

void main() {
  testWidgets('muestra la pantalla principal del POS', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(() => database.close());

    await tester.pumpWidget(PosApp(database: database));

    expect(find.text('POS Offline'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Compras'), findsOneWidget);
  });
}
