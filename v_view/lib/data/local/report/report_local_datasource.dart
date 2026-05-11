import '../../local/hive_service.dart';
import '../../../domain/report/session_report.dart';
import '../../../domain/gaze/gaze_metrics.dart';
import '../../../domain/interview/interview_question.dart';
import '../../../domain/session_setup/session_input.dart';

class ReportLocalDatasource {
  void save(SessionReport report) {
    HiveService.reportBox.put(report.id, _toMap(report));
  }

  SessionReport? load(String id) {
    final raw = HiveService.reportBox.get(id);
    if (raw == null) return null;
    return _fromMap(raw);
  }

  void delete(String id) => HiveService.reportBox.delete(id);

  Map _toMap(SessionReport r) => {
        'id': r.id,
        'createdAt': r.createdAt.toIso8601String(),
        'interviewType': r.interviewType.index,
        'gazeRate': r.gazeMetrics.gazeRate,
        'distractionCount': r.gazeMetrics.distractionCount,
        'totalDistractionSeconds': r.gazeMetrics.totalDistractionSeconds,
        'maxDistractionSeconds': r.gazeMetrics.maxDistractionSeconds,
        'gazeQuality': r.gazeMetrics.quality.index,
        'gazeQualityNote': r.gazeMetrics.qualityNote,
        'qaList': r.qaList
            .map((qa) => {
                  'questionId': qa.question.id,
                  'questionText': qa.question.text,
                  'questionIntent': qa.question.intent,
                  'isFollowUp': qa.question.isFollowUp,
                  'parentQuestionId': qa.question.parentQuestionId,
                  'userAnswer': qa.userAnswer,
                  'aiSummary': qa.aiSummary,
                  'answerDurationSeconds': qa.answerDurationSeconds,
                })
            .toList(),
        'totalQuestions': r.totalQuestions,
        'totalDurationSeconds': r.totalDurationSeconds,
        'improvementPoints': r.improvementPoints
            .map((p) => {
                  'title': p.title,
                  'description': p.description,
                  'evidenceMetric': p.evidenceMetric,
                })
            .toList(),
        'isAiFeedbackAvailable': r.isAiFeedbackAvailable,
      };

  SessionReport _fromMap(Map raw) {
    final qaRaw = (raw['qaList'] as List).cast<Map>();
    return SessionReport(
      id: raw['id'] as String,
      createdAt: DateTime.parse(raw['createdAt'] as String),
      interviewType: InterviewType.values[raw['interviewType'] as int],
      gazeMetrics: GazeMetrics(
        gazeRate: (raw['gazeRate'] as num).toDouble(),
        distractionCount: raw['distractionCount'] as int,
        totalDistractionSeconds:
            (raw['totalDistractionSeconds'] as num).toDouble(),
        maxDistractionSeconds: (raw['maxDistractionSeconds'] as num).toDouble(),
        quality: GazeQuality.values[raw['gazeQuality'] as int],
        qualityNote: raw['gazeQualityNote'] as String?,
      ),
      qaList: qaRaw
          .map((qa) => QuestionAnswer(
                question: InterviewQuestion(
                  id: qa['questionId'] as String,
                  text: qa['questionText'] as String,
                  intent: qa['questionIntent'] as String,
                  isFollowUp: qa['isFollowUp'] as bool,
                  parentQuestionId: qa['parentQuestionId'] as String?,
                ),
                userAnswer: qa['userAnswer'] as String,
                aiSummary: qa['aiSummary'] as String?,
                answerDurationSeconds: qa['answerDurationSeconds'] as int,
              ))
          .toList(),
      totalQuestions: raw['totalQuestions'] as int,
      totalDurationSeconds: raw['totalDurationSeconds'] as int,
      improvementPoints: ((raw['improvementPoints'] as List).cast<Map>())
          .map((p) => ImprovementPoint(
                title: p['title'] as String,
                description: p['description'] as String,
                evidenceMetric: p['evidenceMetric'] as String,
              ))
          .toList(),
      isAiFeedbackAvailable: raw['isAiFeedbackAvailable'] as bool,
    );
  }
}
