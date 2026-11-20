import 'package:flutter/material.dart';
import 'data/local/hive_service.dart';
import 'local/local_ai_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init(subdirectory: 'local_ai');
  runApp(const LocalAiApp());
}
