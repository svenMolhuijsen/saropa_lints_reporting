import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';

import '../models/violation.dart';
import 'base_exporter.dart';

/// SARIF 2.1.0 format exporter.
///
/// Exports violations to Static Analysis Results Interchange Format.
/// See: https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
class SarifExporter extends ReportExporter {
  const SarifExporter();

  @override
  String get formatName => 'SARIF';

  @override
  String get fileExtension => 'sarif';

  @override
  Future<void> export({
    required List<Violation> violations,
    required String outputPath,
    Map<String, dynamic>? metadata,
  }) async {
    final sarif = {
      'version': '2.1.0',
      r'$schema':
          'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json',
      'runs': [_buildRun(violations, metadata)],
    };

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(sarif),
    );
  }

  Map<String, dynamic> _buildRun(
    List<Violation> violations,
    Map<String, dynamic>? metadata,
  ) {
    return {
      'tool': {
        'driver': {
          'name': 'saropa_lints',
          'informationUri': 'https://pub.dev/packages/saropa_lints',
          'version': metadata?['version'] ?? 'unknown',
          'rules': _buildRules(violations),
        },
      },
      'results': violations.map(_toResult).toList(),
    };
  }

  List<Map<String, dynamic>> _buildRules(List<Violation> violations) {
    final ruleIds = violations.map((v) => v.rule).toSet();
    return ruleIds.map((ruleId) {
      final sample = violations.firstWhere((v) => v.rule == ruleId);
      return {
        'id': ruleId,
        'shortDescription': {'text': sample.message},
        'helpUri':
            'https://pub.dev/packages/saropa_lints#${ruleId.replaceAll('_', '-')}',
        'properties': {
          'impact': sample.impact?.name ?? 'unknown',
        },
      };
    }).toList();
  }

  Map<String, dynamic> _toResult(Violation v) {
    return {
      'ruleId': v.rule,
      'level': _impactToLevel(v.impact),
      'message': {'text': v.message},
      'locations': [
        {
          'physicalLocation': {
            'artifactLocation': {'uri': v.file},
            'region': {
              'startLine': v.line,
              'startColumn': v.column,
            },
          },
        },
      ],
      'rank': _impactToRank(v.impact),
      'properties': {
        'impact': v.impact?.name ?? 'unknown',
      },
    };
  }

  String _impactToLevel(LintImpact? impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'error';
      case LintImpact.high:
        return 'warning';
      case LintImpact.medium:
      case LintImpact.low:
        return 'note';
      case LintImpact.opinionated:
        return 'none';
      case null:
        return 'warning';
    }
  }

  double _impactToRank(LintImpact? impact) {
    switch (impact) {
      case LintImpact.critical:
        return 100.0;
      case LintImpact.high:
        return 75.0;
      case LintImpact.medium:
        return 50.0;
      case LintImpact.low:
        return 25.0;
      case LintImpact.opinionated:
        return 10.0;
      case null:
        return 50.0;
    }
  }
}
