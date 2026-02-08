import '../models/violation.dart';

/// Abstract base class for report exporters.
abstract class ReportExporter {
  const ReportExporter();

  String get formatName;
  String get fileExtension;

  Future<void> export({
    required List<Violation> violations,
    required String outputPath,
    Map<String, dynamic>? metadata,
  });
}
