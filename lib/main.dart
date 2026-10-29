import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/app/app.dart';
import 'package:quran_center/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();

  // Initialize Firebase + provider container + error handling before runApp.
  await bootstrap();

  runApp(const App());
}
