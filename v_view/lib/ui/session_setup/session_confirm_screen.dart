import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../domain/session_setup/session_input.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../questions/question_list_screen.dart';
import '../widgets/practice_button.dart';

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
      backgroundColor: const Color(0xFFFAFCFA),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: const Text('면접 시작 전 확인'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: '세션 정보',
              children: [
                _InfoRow(label: '면접 유형', value: typeName),
                _InfoRow(label: '직종 / 전공', value: input.position),
                _InfoRow(label: '회사 / 학교', value: input.company),
                if (input.age.isNotEmpty)
                  _InfoRow(label: '나이', value: input.age),
                if (input.school.isNotEmpty)
                  _InfoRow(label: '학교', value: input.school),
                if (input.education.isNotEmpty)
                  _InfoRow(label: '학력', value: input.education),
                if (input.certificationNames.isNotEmpty)
                  _InfoRow(
                    label: '자격증',
                    value: input.certificationNames.join(', '),
                  ),
                if (input.resumeSummary.isNotEmpty)
                  _InfoRow(label: '이력서 요약', value: input.resumeSummary),
                if (input.selfIntroduction.isNotEmpty)
                  _InfoRow(label: '이전 소개서', value: input.selfIntroduction),
                for (var i = 0; i < 3; i++)
                  if (input.essayAt(i).answer.trim().isNotEmpty)
                    _InfoRow(
                      label: '자소서 ${i + 1}',
                      value:
                          '${input.essayAt(i).question}\n${input.essayAt(i).answer}',
                    ),
                _InfoRow(label: '질문 수', value: '${input.questionCount}개'),
                _InfoRow(label: '질문당 시간', value: '${input.timerMinutes}분'),
                _InfoRow(
                  label: '준비 시간',
                  value: input.preparationSeconds == 0
                      ? '없음'
                      : '질문마다 ${input.preparationSeconds}초',
                ),
                _InfoRow(
                  label: '카메라',
                  value: input.cameraEnabled ? '시선 분석 사용' : '사용하지 않음',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '개인정보 처리 안내',
              titleColor: const Color(0xFFFF9600),
              titleIcon: Icons.shield_outlined,
              children: const [
                _BulletRow(text: '카메라 영상은 기기에서 실시간 시선 분석 후 즉시 폐기됩니다.'),
                _BulletRow(text: '앱은 원본 영상·오디오 파일을 별도로 저장하지 않습니다.'),
                _BulletRow(
                  text:
                      '입력 텍스트, 시선 지표, 리포트는 기기에 저장됩니다. 지원 정보·답변 텍스트·시선 지표는 AI 질문·피드백 생성 시 외부 API로 전송됩니다.',
                ),
                _BulletRow(
                  text:
                      '마이크 답변은 기기의 음성 인식 서비스로 텍스트로 변환됩니다. 인식된 내용은 제출 전에 확인하고 수정할 수 있습니다.',
                ),
                _BulletRow(text: '저장된 연습 기록은 기록 목록에서 삭제할 수 있습니다.'),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '시작하면 첫 질문이 공개됩니다. 답변을 제출하면 필요한 경우에만 추가 질문을 해요. 시간이 끝나도 직접 확인한 뒤 제출할 수 있어요.',
            ),
            const SizedBox(height: 16),
            PracticeButton(
              label: '면접 시작',
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const QuestionListScreen()),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가서 수정'),
              ),
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
  final IconData? titleIcon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.titleColor,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Icon(
                  titleIcon,
                  size: 18,
                  color: titleColor ?? AppColors.onSurface,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: titleColor ?? AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: AppColors.onSurface),
            ),
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
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFFFF9600),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
