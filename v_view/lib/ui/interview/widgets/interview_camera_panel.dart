import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class InterviewCameraPanel extends StatefulWidget {
  const InterviewCameraPanel({super.key, required this.previewBuilder});
  final WidgetBuilder previewBuilder;

  @override
  State<InterviewCameraPanel> createState() => _InterviewCameraPanelState();
}

class _InterviewCameraPanelState extends State<InterviewCameraPanel> {
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '카메라 연결됨\n미리보기를 숨겨도 시선 분석은 계속돼요.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (_showPreview) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 80,
                child: widget.previewBuilder(context),
              ),
            ),
          ],
          IconButton(
            tooltip: _showPreview ? '카메라 미리보기 숨기기' : '카메라 미리보기 보기',
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(
              _showPreview
                  ? Icons.videocam_off_outlined
                  : Icons.videocam_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
