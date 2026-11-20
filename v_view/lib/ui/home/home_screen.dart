import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/history/session_history.dart';
import '../../state/auth/auth_provider.dart'
    show authStateProvider, authNotifierProvider;
import '../../state/gaze/gaze_provider.dart';
import '../../state/history/history_provider.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/app_mode_provider.dart';
import '../../state/local_connection_provider.dart';
import 'widgets/local_practice_tools.dart';
import '../../theme/app_theme.dart';
import '../history/history_detail_screen.dart';
import '../history/history_list_screen.dart';
import '../session_setup/session_setup_screen.dart';
import '../widgets/practice_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;

  Future<void> _startNewSession() async {
    if (ref.read(isLocalAiModeProvider)) {
      ref.invalidate(localConnectionProvider);
      final ready = await ref.read(localConnectionProvider.future);
      if (!mounted) return;
      if (!ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PC의 로컬 AI를 실행하고 USB 연결을 확인해 주세요.')),
        );
        return;
      }
      if (!await confirmReplacingDraft(context, ref) || !mounted) return;
    }
    // Keep application material for the next practice.
    ref.read(interviewProvider.notifier).reset();
    ref.read(gazeProvider.notifier).reset();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SessionSetupScreen()),
    );
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _navIndex = 0);
    } else if (index == 1) {
      // 연습
      _startNewSession();
    } else if (index == 2) {
      // 기록
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HistoryListScreen()),
      );
    } else if (index == 3) {
      // 마이
      _showAccountSheet();
    }
  }

  void _showAccountSheet() {
    if (ref.read(isLocalAiModeProvider)) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이 기기의 로컬 사용자',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'PC에서 AI를 실행한 상태로 사용해 주세요. 로그인 없이 연습하며 기록은 이 기기의 로컬 전용 저장소에 남아요. 지원 정보와 답변은 AI 요청 시 OpenAI로 전송됩니다.',
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    final name = user?.displayName ?? user?.email ?? '사용자';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryContainer, width: 2),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 32,
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: AppColors.onSurfaceVariant,
              ),
              title: Text(
                '로그아웃',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(historyProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final practicedToday = items.any(
      (e) => DateUtils.isSameDay(e.createdAt, today),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFCFA),
        automaticallyImplyLeading: false,
        title: const Text(
          'v-view',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAccountSheet,
            tooltip: ref.watch(isLocalAiModeProvider) ? '로컬 모드 안내' : '계정',
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatPill(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFB55C00),
                  text: '${_streak(items, today)}일 연속',
                ),
                _StatPill(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.primary,
                  text: '누적 ${items.length}회 연습',
                ),
              ],
            ),
            if (ref.watch(isLocalAiModeProvider)) ...[
              const SizedBox(height: 14),
              const LocalPracticeTools(),
            ],
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFE9FAF2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFBFE9D7), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '오늘의 면접 연습',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '한 질문씩,\n실전처럼',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              practicedToday
                                  ? '오늘도 연습했네요!\n다음 답변을 더 다듬어 볼까요?'
                                  : '내 경험을 말하는 연습,\n오늘 한 번 시작해 볼까요?',
                              style: const TextStyle(
                                height: 1.5,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const ExcludeSemantics(
                        child: SizedBox(
                          width: 94,
                          height: 122,
                          child: CustomPaint(painter: _BotPainter()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PracticeButton(
                    label: '면접 시작하기',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _startNewSession,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '지원 자료에 맞춘 질문 · 필요한 부분만 추가 확인',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              '이렇게 연습해요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            const _PracticeStep(
              number: '1',
              icon: Icons.description_outlined,
              title: '나의 지원 자료 준비',
              description: '이력서와 자소서 문항을 나눠 입력해요.',
              color: Color(0xFFE9FAF2),
            ),
            const _PracticeStep(
              number: '2',
              icon: Icons.mic_none_rounded,
              title: '한 질문씩 답하기',
              description: '질문은 시작한 뒤 한 개씩 공개돼요.',
              color: Color(0xFFEEF3FF),
            ),
            const _PracticeStep(
              number: '3',
              icon: Icons.auto_awesome_outlined,
              title: '피드백으로 다시 도전',
              description: '내 답변과 개선점을 기록으로 확인해요.',
              color: Color(0xFFFFF3DE),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '최근 연습 기록',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: () => _onNavTap(2),
                  child: const Text('전체보기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '첫 연습을 기록해 보세요',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '면접을 마치면 답변과 피드백이 여기에 쌓여요.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final item in items.take(3)) _RecentPractice(item: item),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD6F6E8),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            label: '연습',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: '마이',
          ),
        ],
      ),
    );
  }

  int _streak(List<SessionHistoryItem> items, DateTime today) {
    final dates = items.map((e) => DateUtils.dateOnly(e.createdAt)).toSet();
    var date = dates.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var count = 0;
    while (dates.contains(date)) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE2EAE5), width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
  final String number, title, description;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2EAE5), width: 1.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. $title',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecentPractice extends StatelessWidget {
  const _RecentPractice({required this.item});
  final SessionHistoryItem item;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE2EAE5), width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => HistoryDetailScreen(reportId: item.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.position,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.company} · ${DateFormat('MM.dd').format(item.createdAt)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '답변 ${item.totalQuestions}개 · ${item.totalDurationSeconds ~/ 60}분 ${item.totalDurationSeconds % 60}초',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

/// Original V-Bot: a rounded interview coach, drawn without external assets.
class _BotPainter extends CustomPainter {
  const _BotPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 130);
    final ink = Paint()..color = AppColors.primary;
    final mint = Paint()..color = AppColors.primaryContainer;
    canvas.drawOval(
      const Rect.fromLTWH(12, 117, 78, 9),
      Paint()..color = const Color(0xFFD0ECDD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 88, 38, 31),
        const Radius.circular(12),
      ),
      mint,
    );
    canvas.drawCircle(const Offset(17, 89), 10, mint);
    canvas.drawCircle(const Offset(85, 85), 10, mint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 31, 83, 68),
        const Radius.circular(24),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 26, 83, 68),
        const Radius.circular(24),
      ),
      mint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 39, 61, 41),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFF5FFF9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 49, 7, 12),
        const Radius.circular(4),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 49, 7, 12),
        const Radius.circular(4),
      ),
      ink,
    );
    canvas.drawArc(
      const Rect.fromLTWH(43, 57, 15, 12),
      0.2,
      2.7,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(51, 27),
      const Offset(51, 16),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      const Offset(51, 12),
      6,
      Paint()..color = const Color(0xFFFFC862),
    );
    canvas.drawCircle(const Offset(40, 103), 3, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(51, 103), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BotPainter oldDelegate) => false;
}
