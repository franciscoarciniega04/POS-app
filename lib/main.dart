import 'package:flutter/material.dart';

import 'app/pos_app.dart';
import 'data/local/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  runApp(PosApp(database: database));
}
