import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/report/report_comparison.dart';
import '../../domain/report/session_report.dart';
import '../history/history_provider.dart';
import 'report_provider.dart';

final reportComparisonProvider =
    Provider.family<ReportComparison?, SessionReport>((ref, report) {
      final history = ref.watch(historyProvider);
      final current = history.where((item) => item.id == report.id).firstOrNull;
      if (current == null) return null;
      final candidates =
          history
              .where(
                (item) =>
                    item.id != report.id &&
                    item.createdAt.isBefore(report.createdAt) &&
                    item.interviewType == current.interviewType &&
                    item.position.trim().toLowerCase() ==
                        current.position.trim().toLowerCase() &&
                    item.company.trim().toLowerCase() ==
                        current.company.trim().toLowerCase(),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final reports = ref.read(reportProvider.notifier);
      for (final item in candidates) {
        final previous = reports.loadById(item.id);
        if (previous != null) {
          return ReportComparison(current: report, previous: previous);
        }
      }
      return null;
    });
