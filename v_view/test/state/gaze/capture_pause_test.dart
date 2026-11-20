import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:v_view/data/remote/gaze/gaze_analyzer.dart';
import 'package:v_view/state/gaze/gaze_provider.dart';

class _PendingAnalyzer extends Fake implements GazeAnalyzer {
  final result = Completer<GazeFrame>();
  @override
  Future<GazeFrame> analyze(InputImage image) => result.future;
}

void main() {
  test('준비·일시정지 구간을 가로질러 시선 분산 시간이 합산되지 않는다', () {
    final analyzer = GazeAnalyzer();
    final t = DateTime(2026, 11, 17);
    final result = analyzer.computeMetrics([
      GazeFrame(
        isGazing: false,
        faceDetected: true,
        timestamp: t,
        segmentId: 1,
      ),
      GazeFrame(
        isGazing: false,
        faceDetected: true,
        timestamp: t.add(const Duration(milliseconds: 500)),
        segmentId: 1,
      ),
      GazeFrame(
        isGazing: false,
        faceDetected: true,
        timestamp: t.add(const Duration(seconds: 20)),
        segmentId: 2,
      ),
      GazeFrame(
        isGazing: true,
        faceDetected: true,
        timestamp: t.add(const Duration(milliseconds: 20500)),
        segmentId: 2,
      ),
    ]);
    expect(result.distractionCount, 0);
    expect(result.totalDistractionSeconds, 0);
    expect(result.gazeRate, 25);
  });
  test('멈췄다가 재개한 뒤 도착한 이전 프레임은 새 측정에 섞이지 않는다', () async {
    final analyzer = _PendingAnalyzer();
    final notifier = GazeNotifier(analyzer)..start();
    addTearDown(notifier.dispose);
    final pending = notifier.processFrame(
      InputImage.fromBytes(
        bytes: Uint8List(1),
        metadata: InputImageMetadata(
          size: const Size(1, 1),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 1,
        ),
      ),
    );
    notifier.pauseCapture();
    notifier.resumeCapture();
    analyzer.result.complete(
      GazeFrame(isGazing: false, faceDetected: true, timestamp: DateTime.now()),
    );
    await pending;
    expect(notifier.state.frames, isEmpty);
  });
}
