import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart' show kPrimaryColor, kSecondaryColor, kTextColor;
import '../../domain/session_setup/session_input.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../interview/interview_screen.dart';

class SessionConfirmScreen extends ConsumerWidget {
  const SessionConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(sessionInputProvider);
    final typeName = switch (input.type) {
      InterviewType.job => '직무면접',
      InterviewType.personality => '인성면접',
      InterviewType.university => '대학입시면접',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '면접 시작 전 확인',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: '세션 정보',
              children: [
                _InfoRow(label: '면접 유형', value: typeName),
                _InfoRow(label: '직종 / 전공', value: input.position),
                _InfoRow(label: '회사 / 학교', value: input.company),
                _InfoRow(
                  label: '자기소개서',
                  value: input.selfIntroduction.length > 60
                      ? '${input.selfIntroduction.substring(0, 60)}...'
                      : input.selfIntroduction,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '개인정보 처리 안내',
              titleColor: const Color(0xFFFF9600),
              children: const [
                _BulletRow(text: '카메라 영상은 기기에서 실시간 시선 분석 후 즉시 폐기됩니다.'),
                _BulletRow(text: '원본 영상·오디오는 저장되지 않습니다.'),
                _BulletRow(text: '저장 항목: 입력 텍스트, 시선 지표, 리포트 (기기 로컬만)'),
                _BulletRow(text: '저장된 데이터는 설정에서 언제든 삭제할 수 있습니다.'),
              ],
            ),
            const SizedBox(height: 32),
            _DuoButton(
              label: '면접 시작',
              icon: Icons.play_arrow_rounded,
              filled: true,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const InterviewScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _DuoButton(
              label: '돌아가서 수정',
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: titleColor ?? kTextColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: kTextColor)),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFFF9600), fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, color: kTextColor))),
        ],
      ),
    );
  }
}

/// Duolingo 스타일 큰 CTA 버튼 — 두꺼운 하단 그림자, 누르면 아래로 이동
class _DuoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool filled;

  const _DuoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
  });

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  static const _shadowColor = Color(0xFF3730A3);

  @override
  Widget build(BuildContext context) {
    final bg = widget.filled ? kPrimaryColor : Colors.white;
    final fg = widget.filled ? Colors.white : kPrimaryColor;
    final border = widget.filled
        ? Border(bottom: BorderSide(color: _shadowColor, width: _pressed ? 0 : 4))
        : Border.all(color: kPrimaryColor, width: 2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        margin: EdgeInsets.only(top: widget.filled && _pressed ? 4 : 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
