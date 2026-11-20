import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/report/report_export.dart';
import '../../../domain/report/session_report.dart';

class ReportCopyButton extends StatefulWidget {
  const ReportCopyButton({
    super.key,
    required this.report,
    this.isDemo = false,
  });
  final SessionReport report;
  final bool isDemo;
  @override
  State<ReportCopyButton> createState() => _ReportCopyButtonState();
}

class _ReportCopyButtonState extends State<ReportCopyButton> {
  bool _busy = false;
  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    var message = '질문·답변과 피드백을 복사했어요.';
    try {
      await Clipboard.setData(
        ClipboardData(
          text: formatReportForExport(widget.report, isDemo: widget.isDemo),
        ),
      );
    } on Exception {
      message = '복사하지 못했어요. 다시 시도해 주세요.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '답변 포함 리포트 복사',
    onPressed: _busy ? null : _copy,
    icon: const Icon(Icons.copy_rounded),
  );
}
