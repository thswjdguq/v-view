import 'package:flutter/material.dart';
import 'ui/session_setup/session_setup_screen.dart';
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
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  static const _screens = [
    SessionSetupScreen(),
    HistoryListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic), label: '면접 시작'),
          NavigationDestination(icon: Icon(Icons.history), label: '기록'),
        ],
      ),
    );
  }
}
