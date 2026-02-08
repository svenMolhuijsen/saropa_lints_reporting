import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/exporters/sarif_exporter.dart';
import 'package:saropa_lints/src/models/violation.dart';
import 'package:test/test.dart';

void main() {
  group('SARIF Export', () {
    test('exports valid SARIF 2.1.0 format', () async {
      final violations = [
        Violation(
          file: 'lib/test.dart',
          line: 10,
          column: 5,
          rule: 'avoid_hardcoded_credentials',
          message: 'Hardcoded API key detected',
          impact: LintImpact.critical,
        ),
      ];

      final exporter = SarifExporter();
      final outputPath = 'reports/test_sarif.sarif';

      await exporter.export(
        violations: violations,
        outputPath: outputPath,
        metadata: {'version': '4.11.1'},
      );

      final file = File(outputPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('"version": "2.1.0"'));
      expect(content, contains('"saropa_lints"'));
      expect(content, contains('avoid_hardcoded_credentials'));

      file.deleteSync();
    });

    test('maps impact to SARIF levels', () async {
      final violations = [
        Violation(
          file: 'test.dart',
          line: 1,
          column: 1,
          rule: 'critical_rule',
          message: 'msg',
          impact: LintImpact.critical,
        ),
        Violation(
          file: 'test.dart',
          line: 2,
          column: 1,
          rule: 'high_rule',
          message: 'msg',
          impact: LintImpact.high,
        ),
        Violation(
          file: 'test.dart',
          line: 3,
          column: 1,
          rule: 'medium_rule',
          message: 'msg',
          impact: LintImpact.medium,
        ),
      ];

      final exporter = SarifExporter();
      final outputPath = 'reports/test_levels.sarif';

      await exporter.export(
        violations: violations,
        outputPath: outputPath,
        metadata: {},
      );

      final content = File(outputPath).readAsStringSync();
      expect(content, contains('"level": "error"'));
      expect(content, contains('"level": "warning"'));
      expect(content, contains('"level": "note"'));
      expect(content, contains('"rank": 100.0'));
      expect(content, contains('"rank": 75.0'));
      expect(content, contains('"rank": 50.0'));

      File(outputPath).deleteSync();
    });

    test('includes rule metadata', () async {
      final violations = [
        Violation(
          file: 'lib/main.dart',
          line: 42,
          column: 10,
          rule: 'require_semantics_label',
          message: 'Image missing semantics label',
          impact: LintImpact.high,
        ),
      ];

      final exporter = SarifExporter();
      final outputPath = 'reports/test_metadata.sarif';

      await exporter.export(
        violations: violations,
        outputPath: outputPath,
        metadata: {'totalFiles': 5, 'totalViolations': 1},
      );

      final content = File(outputPath).readAsStringSync();
      expect(content, contains('"helpUri"'));
      expect(content, contains('pub.dev/packages/saropa_lints'));
      expect(content, contains('"properties"'));
      expect(content, contains('"impact": "high"'));

      File(outputPath).deleteSync();
    });
  });
}
