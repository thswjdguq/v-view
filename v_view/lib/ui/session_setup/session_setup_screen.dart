import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/gaze/gaze_provider.dart';
import 'session_confirm_screen.dart';
import 'widgets/interview_type_selector.dart';
import '../widgets/practice_button.dart';
import '../../domain/session_setup/profile_catalog.dart';
import 'widgets/profile_selection_field.dart';

class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  int _formRevision = 0;

  Future<void> _clearInput() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('입력 내용을 초기화할까요?'),
        content: const Text('이 화면의 지원 정보와 자소서를 비웁니다. 저장된 면접 기록은 유지돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (clear != true || !mounted) return;
    ref.read(sessionInputProvider.notifier).reset();
    setState(() => _formRevision++);
  }

  @override
  void initState() {
    super.initState();
    // Reuse application material; only interview progress belongs to a new session.
    ref.read(interviewProvider.notifier).reset();
    ref.read(gazeProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(sessionInputProvider);
    final notifier = ref.read(sessionInputProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: const Text('면접 세션 설정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          key: ValueKey(_formRevision),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '나의 경험으로 시작하는 면접',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('지원 자료를 준비하면, 면접 시작 후 질문을 하나씩 공개해요.'),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _clearInput,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('입력 내용 초기화'),
            ),
            const SizedBox(height: 12),
            const _SectionLabel('면접 유형'),
            const SizedBox(height: 12),
            InterviewTypeSelector(
              selected: input.type,
              onChanged: notifier.setType,
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            const _SectionLabel('지원자 정보 (선택)'),
            const SizedBox(height: 12),
            _InputField(
              label: '나이 (선택)',
              hint: '예) 26세 · 비워도 괜찮아요',
              initialValue: input.age,
              onChanged: notifier.setAge,
              maxLength: 20,
            ),
            const SizedBox(height: 16),
            const ProfileSelectionField(type: ProfileCatalogType.school),
            const SizedBox(height: 16),
            _InputField(
              label: '학력 (선택)',
              hint: '예) 컴퓨터공학 전공, 졸업 예정',
              initialValue: input.education,
              onChanged: notifier.setEducation,
              maxLength: 200,
            ),
            const SizedBox(height: 16),
            const ProfileSelectionField(type: ProfileCatalogType.certification),
            const SizedBox(height: 24),
            const _SectionLabel('이력서 · 자기소개서'),
            const SizedBox(height: 8),
            const Text(
              '이름은 입력하지 않아요. 아래 요약 또는 자소서 답변을 하나 이상 작성해 주세요. 문항 제목은 실제 지원서에 맞게 바꿀 수 있어요.',
            ),
            const SizedBox(height: 16),
            _InputField(
              label: '이력서 / 경험 요약 (선택)',
              hint: '프로젝트, 담당 역할, 사용 기술과 경험을 적어주세요.',
              initialValue: input.resumeSummary,
              onChanged: notifier.setResumeSummary,
              maxLines: 5,
              maxLength: 2000,
            ),
            if (input.selfIntroduction.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InputField(
                label: '이전에 입력한 자기소개서',
                hint: '이전 버전에서 작성한 내용',
                initialValue: input.selfIntroduction,
                onChanged: notifier.setSelfIntroduction,
                maxLines: 5,
                maxLength: 3000,
              ),
            ],
            for (var i = 0; i < 3; i++) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  border: Border.all(
                    color: AppColors.outlineVariant,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '자소서 ${i + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InputField(
                      label: '자소서 질문 ${i + 1}',
                      hint: '지원서의 문항을 입력하세요.',
                      initialValue: input.essayAt(i).question,
                      onChanged: (v) => notifier.setEssayQuestion(i, v),
                      maxLines: 2,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      label: '자소서 답변 ${i + 1}',
                      hint: '이 문항에 대한 본인의 경험과 생각을 적어주세요.',
                      initialValue: input.essayAt(i).answer,
                      onChanged: (v) => notifier.setEssayAnswer(i, v),
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _SegmentRow(
              label: '기본 질문 수',
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
            _SegmentRow(
              label: '질문별 준비 시간',
              options: const [0, 15, 30],
              selected: input.preparationSeconds,
              labelBuilder: (v) => v == 0 ? '없음' : '$v초',
              onChanged: notifier.setPreparationSeconds,
            ),
            const SizedBox(height: 8),
            const Text(
              '준비 시간에는 질문을 읽고 생각을 정리해요. 답변 시간이 끝나도 자동 제출하지 않으며, 확인 후 제출하거나 30초를 연장할 수 있어요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: SwitchListTile.adaptive(
                key: const ValueKey('camera-enabled'),
                title: const Text(
                  '카메라·시선 분석 사용',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('끄면 카메라 없이 텍스트·마이크 답변으로만 연습해요.'),
                value: input.cameraEnabled,
                onChanged: notifier.setCameraEnabled,
                activeThumbColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '지원 자료는 이 기기에 저장되며, AI 질문 생성 시 PC를 통해 OpenAI로 전송됩니다. 주민번호·연락처 등 불필요한 개인정보는 제외해 주세요. 원본 영상·오디오는 앱에 저장하지 않습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PracticeButton(
              label: '설정 확인하기',
              onPressed: !notifier.isValid
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SessionConfirmScreen(),
                      ),
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
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
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
                child: GestureDetector(
                  onTap: () => onChanged(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer.withValues(alpha: 0.15)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryContainer
                            : AppColors.outlineVariant,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Text(
                      labelBuilder(opt),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurface,
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
          key: ValueKey(label),
          initialValue: initialValue,
          style: TextStyle(fontSize: 16, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
