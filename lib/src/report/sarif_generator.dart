import 'dart:convert';
import 'dart:io';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Generates SARIF (Static Analysis Results Interchange Format) reports.
class SarifGenerator {
  /// Generate SARIF JSON from violations.
  static Map<String, dynamic> generate({
    required Map<LintImpact, List<ViolationRecord>> violations,
    required String projectRoot,
  }) {
    final rules = <Map<String, dynamic>>[];
    final results = <Map<String, dynamic>>[];
    final seenRules = <String>{};

    // Process violations by impact
    for (final impact in LintImpact.values) {
      final list = violations[impact];
      if (list == null || list.isEmpty) continue;

      for (final v in list) {
        // Add rule definition if not seen
        if (!seenRules.contains(v.rule)) {
          seenRules.add(v.rule);
          rules.add({
            'id': v.rule,
            'shortDescription': {'text': v.message},
            'fullDescription': {'text': v.message},
            'defaultConfiguration': {'level': _impactToLevel(impact)},
            'properties': {'impact': impact.name},
          });
        }

        // Add result
        results.add({
          'ruleId': v.rule,
          'level': _impactToLevel(impact),
          'message': {'text': v.message},
          'locations': [
            {
              'physicalLocation': {
                'artifactLocation': {'uri': _relativePath(v.file, projectRoot)},
                'region': {'startLine': v.line},
              },
            },
          ],
        });
      }
    }

    return {
      'version': '2.1.0',
      '\$schema':
          'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'saropa_lints',
              'informationUri': 'https://pub.dev/packages/saropa_lints',
              'version': '1.0.0',
              'rules': rules,
            },
          },
          'results': results,
        },
      ],
    };
  }

  /// Write SARIF report to file.
  static void writeToFile(String path, Map<String, dynamic> sarif) {
    final encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync(encoder.convert(sarif));
  }

  static String _impactToLevel(LintImpact impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'error';
      case LintImpact.high:
        return 'warning';
      case LintImpact.medium:
        return 'note';
      case LintImpact.low:
        return 'note';
      case LintImpact.opinionated:
        return 'note';
    }
  }

  static String _relativePath(String filePath, String projectRoot) {
    if (filePath.startsWith(projectRoot)) {
      var relative = filePath.substring(projectRoot.length);
      if (relative.startsWith('/') || relative.startsWith('\\')) {
        relative = relative.substring(1);
      }
      return relative;
    }
    return filePath;
  }
}
