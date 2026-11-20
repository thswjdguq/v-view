import '../data/remote/ai/claude_api_service.dart';
import '../domain/gaze/gaze_metrics.dart';
import '../domain/interview/interview_question.dart';
import '../domain/report/session_report.dart';
import '../domain/session_setup/session_input.dart';

/// 네트워크와 API 키를 사용하지 않는 명시적 포트폴리오 샘플 응답.
class DemoApiService implements ClaudeApiService {
  @override
  Future<bool> checkLocalConnection() async => false;
  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async {
    final prompts = switch (input.type) {
      InterviewType.job => [
        '${input.position} 업무와 관련해 해결한 프로젝트 문제를 소개해주세요.',
        '사용한 기술을 선택한 이유와 대안을 설명해주세요.',
        '구현 결과가 올바른지 어떻게 검증했나요?',
        '팀에서 의견이 달랐을 때 어떻게 결정했나요?',
        '사용자 피드백을 반영해 개선한 경험이 있나요?',
        '예상하지 못한 오류를 발견하고 해결한 과정을 설명해주세요.',
        '이 프로젝트를 다시 만든다면 무엇을 바꾸겠나요?',
      ],
      InterviewType.personality => [
        '팀에서 맡은 역할과 기여를 소개해주세요.',
        '갈등을 해결한 경험을 설명해주세요.',
        '실패에서 무엇을 배웠나요?',
        '모르는 문제에 어떻게 접근하나요?',
        '협업에서 중요하게 생각하는 원칙은 무엇인가요?',
        '일정을 지키기 어려울 때 어떻게 대응했나요?',
        '앞으로 성장하고 싶은 방향을 설명해주세요.',
      ],
      InterviewType.university => [
        '${input.position} 분야에 관심을 갖게 된 계기는 무엇인가요?',
        '기억에 남는 탐구 활동을 설명해주세요.',
        '어려운 개념을 어떻게 공부했나요?',
        '협력해서 문제를 해결한 경험이 있나요?',
        '관심 분야에서 더 알아보고 싶은 주제가 있나요?',
        '학습 과정에서 실패를 극복한 경험을 소개해주세요.',
        '입학 후 학습 계획을 설명해주세요.',
      ],
    };
    return List.generate(
      input.questionCount.clamp(1, 7),
      (index) => InterviewQuestion(
        id: 'demo_${input.type.index}_$index',
        text: prompts[index],
        intent: '경험·역할·검증 과정을 구체적으로 설명하는 연습',
      ),
    );
  }

  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) async {
    if (question.isFollowUp || userAnswer.trim().length >= 80) return null;
    return InterviewQuestion(
      id: '${question.id}_followup',
      text: '그 과정에서 본인이 직접 한 행동과 확인한 결과를 조금 더 설명해주세요.',
      intent: '본인 기여와 검증 결과 구체화',
      isFollowUp: true,
      parentQuestionId: question.id,
    );
  }

  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async {
    final answered = qaList
        .where((qa) => qa.userAnswer.trim().isNotEmpty)
        .length;
    return [
      ImprovementPoint(
        title: '답변을 다시 읽고 다음 연습 목표를 정해보세요',
        description:
            '상황 → 본인 행동 → 결과 순서로 정리해보세요. 이 안내는 샘플 규칙으로 제공되며 답변 역량을 판정하지 않습니다.',
        evidenceMetric: '작성한 답변 $answered / ${qaList.length}개',
      ),
      const ImprovementPoint(
        title: '실제 기기에서 음성·시선 기능을 확인해보세요',
        description: '이 데모는 카메라·마이크와 외부 AI를 사용하지 않습니다. 시선 지표는 측정 불가로 표시됩니다.',
        evidenceMetric: '텍스트 답변 데모',
      ),
    ];
  }
}
