import 'package:flutter/material.dart';
import 'package:quran_center/app/app.dart';
import 'package:quran_center/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase + provider container + error handling before runApp.
  await bootstrap();

  runApp(const App());
}
