import 'dart:io';

import '../models/violation.dart';
import '../exporters/base_exporter.dart';
import '../exporters/sarif_exporter.dart';
import '../exporters/sonar_exporter.dart';
import '../exporters/checkstyle_exporter.dart';

/// Manages automatic export of analysis results based on configuration.
///
/// Reads export formats from analysis_options_custom.yaml:
/// ```yaml
/// export_formats:
///   - sarif
///   - sonar
/// 
/// # Optional: customize output paths
/// export_paths:
///   sarif: 'custom/path/my-report.sarif'
///   sonar: 'reports/sonarqube.json'
///   checkstyle: 'build/checkstyle-results.xml'
/// ```
class ExportManager {
  ExportManager._();

  static final List<String> _enabledFormats = [];
  static final Map<String, String> _customPaths = {};
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
      
      // Parse export_paths map
      final pathsMatch = RegExp(
        r'export_paths:\s*\n((?:\s+\w+:\s*[^\n]+\n?)+)',
        multiLine: true,
      ).firstMatch(content);
      
      if (pathsMatch != null) {
        final pathsBlock = pathsMatch.group(1)!;
        final paths = RegExp(r'(\w+):\s*[\'"]?([^\'"]\S+)[\'"]?')
            .allMatches(pathsBlock);
        for (final match in paths) {
          _customPaths[match.group(1)!] = match.group(2)!;
        }
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
        final extension = exporter.fileExtension;

        // Check for custom path first
        final outputPath = _customPaths[format] ?? _generateDefaultPath(
          extension,
          metadata['timestamp'] as String?,
        );
        
        await exporter.export(
          violations: violations,
          outputPath: outputPath,
          metadata: metadata,
        );
        print('  ${exporter.formatName}: $outputPath');
      } catch (e) {
        print('  ${format}: ERROR - $e');
      }
    }
  }
  
  static String _generateDefaultPath(String extension, String? timestamp) {
    final dt = timestamp != null
        ? DateTime.tryParse(timestamp) ?? DateTime.now()
        : DateTime.now();
    final ts = '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        '_'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';

    return 'reports/${ts}_sonar-lint.$extension';
  }

  static ReportExporter? _getExporter(String format) {
    switch (format) {
      case 'sarif':
        return const SarifExporter();
      case 'sonar':
        return const SonarExporter();
      case 'checkstyle':
        return const CheckstyleExporter();
      default:
        return null;
    }
  }
}
