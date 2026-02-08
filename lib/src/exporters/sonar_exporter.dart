import 'dart:convert';
import 'dart:io';

import '../models/violation.dart';
import '../saropa_lint_rule.dart';
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
      final impact = sample.impact ?? LintImpact.medium;
      final impacts = _mapImpactToSonar(impact);
      
      final rule = <String, dynamic>{
        'id': ruleId,
        'name': ruleId,
        'description': sample.message,
        'engineId': 'saropa_lints',
        'cleanCodeAttribute': _cleanCodeAttributeForRule(ruleId),
        'type': _deprecatedTypeFromImpact(impact),
        'severity': _deprecatedSeverityFromImpact(impact),
        'impacts': impacts,
      };
      
      // Add OWASP tags for security rules
      final owaspTags = _getOwaspTags(ruleId);
      if (owaspTags.isNotEmpty) {
        rule['tags'] = owaspTags;
      }
      
      return rule;
    }).toList();
  }

  List<Map<String, dynamic>> _mapImpactToSonar(LintImpact impact) {
    switch (impact) {
      case LintImpact.critical:
        return [
          {
            'softwareQuality': 'RELIABILITY',
            'severity': 'HIGH',
          },
          {
            'softwareQuality': 'SECURITY',
            'severity': 'HIGH',
          },
        ];
      case LintImpact.high:
        return [
          {
            'softwareQuality': 'MAINTAINABILITY',
            'severity': 'HIGH',
          },
        ];
      case LintImpact.medium:
        return [
          {
            'softwareQuality': 'MAINTAINABILITY',
            'severity': 'MEDIUM',
          },
        ];
      case LintImpact.low:
        return [
          {
            'softwareQuality': 'MAINTAINABILITY',
            'severity': 'LOW',
          },
        ];
      case LintImpact.opinionated:
        return [
          {
            'softwareQuality': 'MAINTAINABILITY',
            'severity': 'INFO',
          },
        ];
    }
  }

  String _cleanCodeAttributeForRule(String ruleId) {
    // Check security/responsibility first (highest priority)
    if (ruleId.contains('security') ||
        ruleId.contains('credential') ||
        ruleId.contains('crypto') ||
        ruleId.contains('unsafe')) {
      return 'TRUSTWORTHY';
    }
    
    // Then check other patterns
    if (ruleId.startsWith('prefer') || ruleId.contains('prefer_')) {
      return 'FORMATTED';
    }
    if (ruleId.startsWith('avoid') ||
        ruleId.contains('avoid_') ||
        ruleId.contains('no_')) {
      return 'LOGICAL';
    }
    if (ruleId.startsWith('require') ||
        ruleId.contains('require_') ||
        ruleId.startsWith('enforce')) {
      return 'COMPLETE';
    }
    if (ruleId.startsWith('always') || ruleId.startsWith('must')) {
      return 'CONVENTIONAL';
    }
    return 'LOGICAL';
  }

  String _deprecatedTypeFromImpact(LintImpact impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'VULNERABILITY';
      case LintImpact.high:
        return 'BUG';
      case LintImpact.medium:
      case LintImpact.low:
      case LintImpact.opinionated:
        return 'CODE_SMELL';
    }
  }

  String _deprecatedSeverityFromImpact(LintImpact impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'BLOCKER';
      case LintImpact.high:
        return 'CRITICAL';
      case LintImpact.medium:
        return 'MAJOR';
      case LintImpact.low:
        return 'MINOR';
      case LintImpact.opinionated:
        return 'INFO';
    }
  }

  int _effortFromImpact(LintImpact impact) {
    switch (impact) {
      case LintImpact.critical:
        return 240;
      case LintImpact.high:
        return 120;
      case LintImpact.medium:
        return 60;
      case LintImpact.low:
        return 20;
      case LintImpact.opinionated:
        return 10;
    }
  }
  
  List<String> _getOwaspTags(String ruleId) {
    final tags = <String>[];
    
    if (ruleId.contains('credential')) {
      tags.addAll(['owasp-m1', 'owasp-m9', 'owasp-a07']);
    }
    if (ruleId.contains('crypto') || ruleId.contains('encryption')) {
      tags.addAll(['owasp-m10', 'owasp-a02']);
    }
    if (ruleId.contains('https') || ruleId.contains('cleartext')) {
      tags.addAll(['owasp-m5', 'owasp-a02']);
    }
    if (ruleId.contains('injection') || ruleId.contains('sql')) {
      tags.addAll(['owasp-m4', 'owasp-a03']);
    }
    if (ruleId.contains('auth') || ruleId.contains('permission')) {
      tags.addAll(['owasp-m3', 'owasp-a07']);
    }
    
    return tags;
  }

  Map<String, dynamic> _toIssue(Violation v) {
    final impact = v.impact ?? LintImpact.medium;
    final effort = _effortFromImpact(impact);

    final textRange = <String, dynamic>{
      'startLine': v.line,
    };

    if (v.column > 0) {
      textRange['startColumn'] = v.column;
      // keep end column same as start if not known
      textRange['endColumn'] = v.column;
      textRange['endLine'] = v.line;
    }

    return {
      'ruleId': v.rule,
      'effortMinutes': effort,
      'primaryLocation': {
        'message': v.message,
        'filePath': v.file,
        'textRange': textRange,
      },
    };
  }
}
