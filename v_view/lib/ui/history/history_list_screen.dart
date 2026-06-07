import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../app.dart' show kPrimaryColor, kSecondaryColor, kTextColor;
import '../../state/history/history_provider.dart';
import '../../state/auth/auth_provider.dart' show authStateProvider, authNotifierProvider;
import '../../domain/history/session_history.dart';
import '../../domain/session_setup/session_input.dart';
import '../../state/report/report_provider.dart';
import '../session_setup/session_setup_screen.dart';
import 'history_detail_screen.dart';

class HistoryListScreen extends ConsumerWidget {
  const HistoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);
    final firebaseUser = ref.watch(authStateProvider).valueOrNull;
    final userName = firebaseUser?.displayName ?? firebaseUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'v-view',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '전체 삭제',
              onPressed: () => _confirmDeleteAll(context, ref),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: '계정',
            itemBuilder: (_) => [
              if (userName.isNotEmpty)
                PopupMenuItem(
                  enabled: false,
                  child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'signout') {
                ref.read(authNotifierProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FadeInUp(
                  child: Text(
                    '아직 연습 기록이 없어요.\n첫 면접을 시작해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kTextColor,
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              itemCount: items.length,
              itemBuilder: (_, i) => FadeInUp(
                delay: Duration(milliseconds: 60 * i),
                from: 24,
                child: _HistoryCard(item: items[i]),
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: _DuoButton(
          label: '새 면접 시작',
          icon: Icons.mic,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionSetupScreen()),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('모든 면접 기록을 삭제합니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(historyProvider.notifier).deleteAll();
            },
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final SessionHistoryItem item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeName = switch (item.interviewType) {
      InterviewType.job => '직무면접',
      InterviewType.personality => '인성면접',
      InterviewType.university => '대학입시',
    };
    final dateStr = DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          '$typeName · ${item.position}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextColor),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$dateStr · 응시율 ${item.gazeRate.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: kPrimaryColor),
        onTap: () {
          final report = ref.read(reportProvider.notifier).loadById(item.id);
          if (report != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryDetailScreen(reportId: item.id),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('리포트를 불러올 수 없습니다.')),
            );
          }
        },
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 세션 기록을 삭제합니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(historyProvider.notifier).delete(item.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

/// Duolingo 스타일 큰 CTA 버튼 — 두꺼운 하단 그림자, 누르면 아래로 이동
class _DuoButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _DuoButton({required this.label, required this.icon, required this.onPressed});

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  static const _shadowColor = Color(0xFF3730A3);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(top: _pressed ? 4 : 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            bottom: BorderSide(color: _shadowColor, width: _pressed ? 0 : 4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
