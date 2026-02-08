import 'dart:convert';
import 'dart:io';

import '../models/violation.dart';
import 'base_exporter.dart';

class SonarExporter extends ReportExporter {
  const SonarExporter();

  @override
  String get formatName => 'SonarQube';

  @override
  String get fileExtension => 'json';

  @override
  Future<void> export({
    required List<Violation> violations,
    required String outputPath,
    Map<String, dynamic>? metadata,
  }) async {
    final sonar = {
      'rules': _buildRules(violations),
      'issues': violations.map(_toIssue).toList(),
    };

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(sonar),
    );
  }

  List<Map<String, dynamic>> _buildRules(List<Violation> violations) {
    final ruleIds = violations.map((v) => v.rule).toSet();
    return ruleIds.map((ruleId) {
      final sample = violations.firstWhere((v) => v.rule == ruleId);
      return {
        'id': ruleId,
        'name': ruleId,
        'description': sample.message,
        'engineId': 'saropa_lints',
        'cleanCodeAttribute': 'LOGICAL',
        'type': 'CODE_SMELL',
        'severity': 'MAJOR',
        'impacts': [
          {
            'softwareQuality': 'MAINTAINABILITY',
            'severity': 'MEDIUM',
          }
        ],
      };
    }).toList();
  }

  Map<String, dynamic> _toIssue(Violation v) {
    return {
      'ruleId': v.rule,
      'effortMinutes': 10,
      'primaryLocation': {
        'message': v.message,
        'filePath': v.file,
        'textRange': {
          'startLine': v.line,
        },
      },
    };
  }
}
