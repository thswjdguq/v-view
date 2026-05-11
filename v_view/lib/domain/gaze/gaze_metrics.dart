enum GazeQuality { normal, reference, unavailable }

class GazeMetrics {
  final double gazeRate;
  final int distractionCount;
  final double totalDistractionSeconds;
  final double maxDistractionSeconds;
  final GazeQuality quality;
  final String? qualityNote;

  const GazeMetrics({
    required this.gazeRate,
    required this.distractionCount,
    required this.totalDistractionSeconds,
    required this.maxDistractionSeconds,
    this.quality = GazeQuality.normal,
    this.qualityNote,
  });

  static const GazeMetrics empty = GazeMetrics(
    gazeRate: 0,
    distractionCount: 0,
    totalDistractionSeconds: 0,
    maxDistractionSeconds: 0,
    quality: GazeQuality.unavailable,
  );
}
