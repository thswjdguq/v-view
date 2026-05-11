import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionScreen extends StatelessWidget {
  final VoidCallback onGranted;

  const CameraPermissionScreen({super.key, required this.onGranted});

  Future<void> _requestPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) _showSettingsDialog(context);
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: const Text(
          '시선 분석을 위해 카메라 권한이 필요합니다.\n설정에서 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 64),
              const SizedBox(height: 24),
              const Text(
                '카메라 권한이 필요합니다',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '시선 분석을 위해 카메라를 사용합니다.\n원본 영상은 기기에 저장되지 않습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => _requestPermission(context),
                child: const Text('권한 허용'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
