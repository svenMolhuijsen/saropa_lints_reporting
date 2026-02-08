import 'dart:io';

import '../models/violation.dart';
import '../saropa_lint_rule.dart';
import 'base_exporter.dart';

/// Checkstyle XML format exporter.
///
/// Exports violations to Checkstyle XML format for CI/CD integration.
/// See: https://checkstyle.sourceforge.io/
class CheckstyleExporter extends ReportExporter {
  const CheckstyleExporter();

  @override
  String get formatName => 'Checkstyle';

  @override
  String get fileExtension => 'xml';

  @override
  Future<void> export({
    required List<Violation> violations,
    required String outputPath,
    Map<String, dynamic>? metadata,
  }) async {
    final xml = _buildXml(violations);

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(xml);
  }

  String _buildXml(List<Violation> violations) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<checkstyle version="10.0">');

    // Group violations by file
    final byFile = <String, List<Violation>>{};
    for (final v in violations) {
      byFile.putIfAbsent(v.file, () => []).add(v);
    }

    // Write each file
    for (final entry in byFile.entries) {
      buffer.writeln('  <file name="${_escapeXml(entry.key)}">');
      for (final v in entry.value) {
        buffer.writeln(_buildError(v));
      }
      buffer.writeln('  </file>');
    }

    buffer.writeln('</checkstyle>');
    return buffer.toString();
  }

  String _buildError(Violation v) {
    final severity = _impactToSeverity(v.impact);
    final message = _escapeXml(v.message);
    final source = 'saropa_lints.${v.rule}';
    final tier = _getTierFromImpact(v.impact);
    final category = _getCategory(v.rule);
    final owaspTags = _getOwaspTags(v.rule);

    // Build attributes
    final attrs = StringBuffer()
      ..write('line="${v.line}" ')
      ..write('column="${v.column}" ')
      ..write('severity="$severity" ')
      ..write('message="$message" ')
      ..write('source="$source"');
    
    // Add custom metadata as attributes
    if (tier.isNotEmpty) {
      attrs.write(' tier="$tier"');
    }
    if (category.isNotEmpty) {
      attrs.write(' category="$category"');
    }
    if (owaspTags.isNotEmpty) {
      attrs.write(' owasp="${owaspTags.join(",")}"');
    }

    return '    <error $attrs/>';
  }

  String _impactToSeverity(LintImpact? impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'error';
      case LintImpact.high:
        return 'error';
      case LintImpact.medium:
        return 'warning';
      case LintImpact.low:
        return 'info';
      case LintImpact.opinionated:
        return 'info';
      case null:
        return 'warning';
    }
  }
  
  String _getTierFromImpact(LintImpact? impact) {
    switch (impact) {
      case LintImpact.critical:
        return 'essential';
      case LintImpact.high:
        return 'recommended';
      case LintImpact.medium:
        return 'professional';
      case LintImpact.low:
        return 'comprehensive';
      case LintImpact.opinionated:
        return 'pedantic';
      case null:
        return '';
    }
  }
  
  String _getCategory(String ruleId) {
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
  
  List<String> _getOwaspTags(String ruleId) {
    final tags = <String>[];
    
    if (ruleId.contains('credential')) {
      tags.addAll(['M1', 'M9', 'A07']);
    }
    if (ruleId.contains('crypto') || ruleId.contains('encryption')) {
      tags.addAll(['M10', 'A02']);
    }
    if (ruleId.contains('https') || ruleId.contains('cleartext')) {
      tags.addAll(['M5', 'A02']);
    }
    if (ruleId.contains('injection') || ruleId.contains('sql')) {
      tags.addAll(['M4', 'A03']);
    }
    if (ruleId.contains('auth') || ruleId.contains('permission')) {
      tags.addAll(['M3', 'A07']);
    }
    
    return tags;
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
