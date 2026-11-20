import 'package:flutter/material.dart';
import 'data/local/hive_service.dart';
import 'demo/demo_app.dart';
import 'demo/demo_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 제품의 실제 기록과 파일 경로를 분리한다.
  await HiveService.init(subdirectory: 'portfolio_demo');
  await seedDemoData();
  runApp(const DemoApp());
}
