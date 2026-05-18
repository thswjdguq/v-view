import 'package:flutter/material.dart';
import 'ui/history/history_list_screen.dart';

class VViewApp extends StatelessWidget {
  const VViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'v-view',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HistoryListScreen(),
    );
  }
}
