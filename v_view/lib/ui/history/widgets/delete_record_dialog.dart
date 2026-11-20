import 'package:flutter/material.dart';

Future<bool?> showRecordDeletionDialog(
  BuildContext context, {
  required String title,
  required String description,
  required Future<void> Function() onDelete,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DeleteRecordDialog(
    title: title,
    description: description,
    onDelete: onDelete,
  ),
);

class _DeleteRecordDialog extends StatefulWidget {
  const _DeleteRecordDialog({
    required this.title,
    required this.description,
    required this.onDelete,
  });
  final String title;
  final String description;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteRecordDialog> createState() => _DeleteRecordDialogState();
}

class _DeleteRecordDialogState extends State<_DeleteRecordDialog> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '삭제를 마치지 못했어요. 다시 시도해 주세요.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _delete,
          child: Text(
            _busy
                ? '삭제 중...'
                : _failed
                ? '다시 시도'
                : '삭제',
          ),
        ),
      ],
    ),
  );
}
