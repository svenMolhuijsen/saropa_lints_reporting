#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// CLI tool to export saropa_lints analysis results to various formats.
///
/// Usage:
///   dart run saropa_lints:export_report [options]
///
/// Formats:
///   --sarif    SARIF 2.1.0 (default)
///   --json     Simple JSON (future)
///   --html     HTML report (future)
library;

import 'dart:io';

import 'package:saropa_lints/src/exporters/sarif_exporter.dart';
import 'package:saropa_lints/src/violation_parser.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Parse format
  final format = args.contains('--json')
      ? 'json'
      : args.contains('--html')
          ? 'html'
          : 'sarif'; // default

  // Parse output path
  var outputPath = 'reports/saropa_lints.$format';
  final outputIndex = args.indexOf('--output');
  if (outputIndex != -1 && outputIndex + 1 < args.length) {
    outputPath = args[outputIndex + 1];
  }
  final outputIndexShort = args.indexOf('-o');
  if (outputIndexShort != -1 && outputIndexShort + 1 < args.length) {
    outputPath = args[outputIndexShort + 1];
  }

  // Parse working directory
  var workingDir = '.';
  for (final arg in args) {
    if (!arg.startsWith('-') &&
        arg != outputPath &&
        args.indexOf(arg) != outputIndex + 1 &&
        args.indexOf(arg) != outputIndexShort + 1) {
      workingDir = arg;
      break;
    }
  }

  print('Saropa Lints Report Exporter');
  print('============================');
  print('Format: ${format.toUpperCase()}');
  print('');

  print('Running lint analysis...');
  print('');

  // Run custom_lint
  final result = await Process.run(
    'dart',
    ['run', 'custom_lint'],
    workingDirectory: workingDir,
    runInShell: true,
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  if (result.exitCode != 0 && !stderr.contains('Analyzing')) {
    if (stderr.isNotEmpty) {
      print('Warning: custom_lint returned errors:');
      print(stderr);
    }
  }

  // Parse violations
  final violations = parseViolations(output);

  print('Found ${violations.length} violation(s)');
  print('');

  if (violations.isEmpty) {
    print('No violations found - nothing to export.');
    return;
  }

  // Build metadata
  final metadata = {
    'timestamp': DateTime.now().toIso8601String(),
    'totalFiles': violations.map((v) => v.file).toSet().length,
    'totalViolations': violations.length,
    'version': '4.11.1',
  };

  // Select exporter
  final exporter = _getExporter(format);
  if (exporter == null) {
    print('Error: Format "$format" not yet implemented.');
    print('Available formats: sarif');
    exit(1);
  }

  // Export
  print('Exporting to $outputPath...');
  await exporter.export(
    violations: violations,
    outputPath: outputPath,
    metadata: metadata,
  );

  print('');
  print('✓ Report exported successfully!');
  print('  Format: ${exporter.formatName}');
  print('  Output: $outputPath');
  print('  Files: ${metadata['totalFiles']}');
  print('  Violations: ${metadata['totalViolations']}');
}

dynamic _getExporter(String format) {
  switch (format) {
    case 'sarif':
      return const SarifExporter();
    case 'json':
    case 'html':
      return null; // Not yet implemented
    default:
      return null;
  }
}

void _printUsage() {
  print('Saropa Lints Report Exporter');
  print('');
  print('Usage: dart run saropa_lints:export_report [options] [path]');
  print('');
  print('Exports lint analysis results to various formats for CI/CD integration.');
  print('');
  print('Options:');
  print('  --sarif               Export as SARIF 2.1.0 (default)');
  print('  --json                Export as JSON (not yet implemented)');
  print('  --html                Export as HTML (not yet implemented)');
  print('  -o, --output <path>   Output file path');
  print('  -h, --help            Show this help message');
  print('');
  print('Examples:');
  print('  dart run saropa_lints:export_report');
  print('  dart run saropa_lints:export_report --sarif -o results.sarif');
  print('  dart run saropa_lints:export_report ./my_project');
}
