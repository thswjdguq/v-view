import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart' show kPrimaryColor, kSecondaryColor, kTextColor;
import '../../state/session_setup/session_setup_provider.dart';
import 'session_confirm_screen.dart';
import 'widgets/interview_type_selector.dart';

class SessionSetupScreen extends ConsumerWidget {
  const SessionSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(sessionInputProvider);
    final notifier = ref.read(sessionInputProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '면접 세션 설정',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('면접 유형'),
            const SizedBox(height: 12),
            InterviewTypeSelector(
              selected: input.type,
              onChanged: notifier.setType,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: '직종 / 전공',
              hint: '예) 백엔드 개발자, 컴퓨터공학과',
              initialValue: input.position,
              onChanged: notifier.setPosition,
            ),
            const SizedBox(height: 16),
            _InputField(
              label: '회사 / 학교',
              hint: '예) 카카오, 서울대학교',
              initialValue: input.company,
              onChanged: notifier.setCompany,
            ),
            const SizedBox(height: 16),
            _InputField(
              label: '자기소개서 / 경험 요약',
              hint: '핵심 내용을 붙여넣거나 직접 입력하세요.',
              initialValue: input.selfIntroduction,
              onChanged: notifier.setSelfIntroduction,
              maxLines: 6,
              maxLength: 500,
            ),
            const SizedBox(height: 20),
            _SegmentRow(
              label: '질문 수',
              options: const [3, 5, 7],
              selected: input.questionCount,
              labelBuilder: (v) => '$v개',
              onChanged: notifier.setQuestionCount,
            ),
            const SizedBox(height: 16),
            _SegmentRow(
              label: '질문당 시간',
              options: const [1, 2, 3],
              selected: input.timerMinutes,
              labelBuilder: (v) => '$v분',
              onChanged: notifier.setTimerMinutes,
            ),
            const SizedBox(height: 16),
            const Text(
              '※ 원본 영상/오디오는 저장되지 않습니다. 입력 텍스트와 시선 지표만 기기 로컬에 저장됩니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            _DuoButton(
              label: '다음',
              enabled: notifier.isValid,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionConfirmScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextColor),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _SegmentRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 10),
        Row(
          children: options.map((opt) {
            final isSelected = opt == selected;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryColor.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? kPrimaryColor : kSecondaryColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      labelBuilder(opt),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? kPrimaryColor : kTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? maxLength;

  const _InputField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: initialValue,
          style: const TextStyle(fontSize: 16, color: kTextColor),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kSecondaryColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kSecondaryColor, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Duolingo 스타일 큰 CTA 버튼 — 두꺼운 하단 그림자, 누르면 아래로 이동
class _DuoButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  const _DuoButton({required this.label, required this.onPressed, this.enabled = true});

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  static const _shadowColor = Color(0xFF3730A3);

  @override
  Widget build(BuildContext context) {
    final bg = widget.enabled ? kPrimaryColor : kSecondaryColor;
    final shadow = widget.enabled ? _shadowColor : const Color(0xFFB0B0B0);
    final fg = widget.enabled ? Colors.white : Colors.black45;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        margin: EdgeInsets.only(top: _pressed ? 4 : 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            bottom: BorderSide(color: shadow, width: _pressed ? 0 : 4),
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
