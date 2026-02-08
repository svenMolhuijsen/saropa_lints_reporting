import 'dart:io';

import '../models/violation.dart';
import '../exporters/base_exporter.dart';
import '../exporters/sarif_exporter.dart';

/// Manages automatic export of analysis results based on configuration.
///
/// Reads export formats from analysis_options_custom.yaml:
/// ```yaml
/// export_formats:
///   - sarif
///   - json  # future
/// ```
class ExportManager {
  ExportManager._();

  static final List<String> _enabledFormats = [];
  static bool _initialized = false;

  /// Initialize from configuration file.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    try {
      final configFile = File('analysis_options_custom.yaml');
      if (!configFile.existsSync()) return;

      final content = configFile.readAsStringSync();
      
      // Parse export_formats list
      final match = RegExp(
        r'export_formats:\s*\n((?:\s*-\s*\w+\s*\n?)+)',
        multiLine: true,
      ).firstMatch(content);

      if (match != null) {
        final formatsBlock = match.group(1)!;
        final formats = RegExp(r'-\s*(\w+)').allMatches(formatsBlock);
        _enabledFormats.addAll(formats.map((m) => m.group(1)!));
      }
    } catch (_) {
      // Silently ignore config errors
    }
  }

  /// Export violations to all configured formats.
  static Future<void> exportIfConfigured(List<Violation> violations) async {
    if (_enabledFormats.isEmpty || violations.isEmpty) return;

    final metadata = {
      'timestamp': DateTime.now().toIso8601String(),
      'totalFiles': violations.map((v) => v.file).toSet().length,
      'totalViolations': violations.length,
    };

    for (final format in _enabledFormats) {
      final exporter = _getExporter(format);
      if (exporter == null) continue;

      try {
        final outputPath = 'reports/saropa_lints.$format';
        await exporter.export(
          violations: violations,
          outputPath: outputPath,
          metadata: metadata,
        );
      } catch (_) {
        // Silently ignore export errors - don't break analysis
      }
    }
  }

  static ReportExporter? _getExporter(String format) {
    switch (format) {
      case 'sarif':
        return const SarifExporter();
      default:
        return null;
    }
  }
}
