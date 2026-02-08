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
    final highestTier = _determineHighestTier(violations);
    final toolName = highestTier != null
        ? 'saropa_lints - ${_tierDisplayName(highestTier)}'
        : 'saropa_lints';

    return {
      'tool': {
        'driver': {
          'name': toolName,
          'organization': 'Saropa',
          'product': 'Saropa Lints',
          'semanticVersion': metadata?['version'] ?? 'unknown',
          'informationUri': 'https://pub.dev/packages/saropa_lints',
          'downloadUri': 'https://pub.dev/packages/saropa_lints/install',
          'fullDescription': {
            'text':
                'A collection of custom lint rules with 286 quick fixes for Flutter and Dart. Static analysis for security, accessibility, and performance.',
          },
          'rules': _buildRules(violations),
        },
      },
      'results': violations.map(_toResult).toList(),
      'properties': {
        'totalViolations': violations.length,
        'criticalCount':
            violations.where((v) => v.impact == LintImpact.critical).length,
        'highCount':
            violations.where((v) => v.impact == LintImpact.high).length,
        'mediumCount':
            violations.where((v) => v.impact == LintImpact.medium).length,
        'lowCount': violations.where((v) => v.impact == LintImpact.low).length,
        'analysisTimestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      },
    };
  }

  List<Map<String, dynamic>> _buildRules(List<Violation> violations) {
    final ruleIds = violations.map((v) => v.rule).toSet();
    return ruleIds.map((ruleId) {
      final sample = violations.firstWhere((v) => v.rule == ruleId);
      final impact = sample.impact;
      
      final properties = <String, dynamic>{
        'impact': impact?.name ?? 'unknown',
        'category': _getRuleCategory(ruleId),
        'tags': _getRuleTags(ruleId, impact),
      };
      
      // Add OWASP mapping for security rules
      final owasp = _getOwaspMapping(ruleId);
      if (owasp != null) {
        properties['owasp'] = owasp;
      }
      
      // Add rule cost
      properties['cost'] = _getRuleCost(ruleId);
      
      return {
        'id': ruleId,
        'name': ruleId.replaceAll('_', ' ').toUpperCase(),
        'shortDescription': {'text': sample.message},
        'fullDescription': {
          'text': sample.message,
        },
        'defaultConfiguration': {
          'level': _impactToLevel(impact),
          'rank': _impactToRank(impact),
        },
        'helpUri':
            'https://pub.dev/packages/saropa_lints#${ruleId.replaceAll('_', '-')}',
        'properties': properties,
      };
    }).toList();
  }

  String _getRuleCategory(String ruleId) {
    if (ruleId.contains('security') ||
        ruleId.contains('credential') ||
        ruleId.contains('hardcoded')) {
      return 'security';
    }
    if (ruleId.contains('accessibility') ||
        ruleId.contains('semantics') ||
        ruleId.contains('a11y')) {
      return 'accessibility';
    }
    if (ruleId.contains('performance') ||
        ruleId.contains('build') ||
        ruleId.contains('expensive')) {
      return 'performance';
    }
    if (ruleId.contains('memory') ||
        ruleId.contains('leak') ||
        ruleId.contains('dispose')) {
      return 'memory';
    }
    if (ruleId.contains('test')) return 'testing';
    return 'code-quality';
  }

  List<String> _getRuleTags(String ruleId, LintImpact? impact) {
    final tags = <String>[];
    tags.add(_getRuleCategory(ruleId));
    if (impact != null) tags.add(impact.name);
    if (ruleId.contains('bloc')) tags.add('bloc');
    if (ruleId.contains('riverpod')) tags.add('riverpod');
    if (ruleId.contains('provider')) tags.add('provider');
    if (ruleId.contains('firebase')) tags.add('firebase');
    
    // Add OWASP tag for security rules
    if (_getOwaspMapping(ruleId) != null) {
      tags.add('owasp');
    }
    
    return tags;
  }
  
  Map<String, List<String>>? _getOwaspMapping(String ruleId) {
    if (ruleId.contains('credential') || ruleId.contains('hardcoded_credentials')) {
      return {'mobile': ['M1', 'M9'], 'web': ['A07']};
    }
    if (ruleId.contains('crypto') || ruleId.contains('encryption')) {
      return {'mobile': ['M10'], 'web': ['A02']};
    }
    if (ruleId.contains('https') || ruleId.contains('cleartext')) {
      return {'mobile': ['M5'], 'web': ['A02']};
    }
    if (ruleId.contains('injection') || ruleId.contains('sql')) {
      return {'mobile': ['M4'], 'web': ['A03']};
    }
    if (ruleId.contains('auth') || ruleId.contains('permission')) {
      return {'mobile': ['M3'], 'web': ['A07']};
    }
    return null;
  }
  
  String _getRuleCost(String ruleId) {
    if (ruleId.contains('god_class') ||
        ruleId.contains('cyclomatic') ||
        ruleId.contains('cognitive_complexity')) {
      return 'high';
    }
    if (ruleId.startsWith('prefer_') || ruleId.contains('naming')) {
      return 'low';
    }
    return 'medium';
  }
  
  String? _determineHighestTier(List<Violation> violations) {
    var hasEssential = false;
    var hasRecommended = false;
    var hasProfessional = false;
    
    for (final v in violations) {
      final impact = v.impact;
      if (impact == LintImpact.critical) {
        hasEssential = true;
      } else if (impact == LintImpact.high) {
        hasRecommended = true;
      } else if (impact == LintImpact.medium) {
        hasProfessional = true;
      }
    }
    
    if (hasEssential) return 'essential';
    if (hasRecommended) return 'recommended';
    if (hasProfessional) return 'professional';
    return null;
  }
  
  String _tierDisplayName(String tier) {
    switch (tier) {
      case 'essential': return 'Essential';
      case 'recommended': return 'Recommended';
      case 'professional': return 'Professional';
      case 'comprehensive': return 'Comprehensive';
      case 'pedantic': return 'Pedantic';
      default: return tier;
    }
  }

  Map<String, dynamic> _toResult(Violation v) {
    return {
      'ruleId': v.rule,
      'level': _impactToLevel(v.impact),
      'message': {
        'text': v.message,
        'markdown': v.message,
      },
      'locations': [
        {
          'physicalLocation': {
            'artifactLocation': {
              'uri': v.file,
              'uriBaseId': '%SRCROOT%',
            },
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
        'category': _getRuleCategory(v.rule),
        'tags': _getRuleTags(v.rule, v.impact),
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
