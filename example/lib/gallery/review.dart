import 'dart:convert';

/// A reviewer decision, deliberately separate from technical audit results.
enum ReviewStatus {
  /// The owner has not reviewed this example.
  notReviewed('Not reviewed'),

  /// The owner approves this example for presentation.
  approved('Approved'),

  /// The example needs another pass.
  needsImprovement('Needs improvement');

  const ReviewStatus(this.label);

  /// Human-readable decision.
  final String label;
}

/// One review entry. Export before leaving; no data is sent to a server.
class DemoReview {
  /// Creates an unreviewed entry.
  const DemoReview({this.status = ReviewStatus.notReviewed, this.notes = ''});

  /// Owner decision.
  final ReviewStatus status;

  /// Owner observations.
  final String notes;
}

/// Serializes all examples so an untouched entry remains visible in the export.
String exportReviews(Map<String, DemoReview> reviews, Iterable<String> slugs) {
  return const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'reviews': {
      for (final slug in slugs)
        slug: {
          'status': (reviews[slug] ?? const DemoReview()).status.name,
          'notes': (reviews[slug] ?? const DemoReview()).notes,
        },
    },
  });
}

/// Validates a complete import before replacing any in-memory decisions.
Map<String, DemoReview> importReviews(String source, Set<String> allowedSlugs) {
  if (source.length > 1000000) {
    throw const FormatException('Review file is too large (maximum 1 MB).');
  }
  final data = jsonDecode(source);
  if (data is! Map<String, dynamic> ||
      data['schemaVersion'] != 1 ||
      data['reviews'] is! Map<String, dynamic>) {
    throw const FormatException(
        'Expected a NibMotion review export (version 1).');
  }
  final entries = data['reviews'] as Map<String, dynamic>;
  final result = <String, DemoReview>{};
  for (final entry in entries.entries) {
    if (!allowedSlugs.contains(entry.key)) {
      throw FormatException('Unknown example: ${entry.key}.');
    }
    final value = entry.value;
    if (value is! Map<String, dynamic> ||
        value['notes'] is! String ||
        (value['notes'] as String).length > 10000) {
      throw FormatException(
          'Invalid notes for ${entry.key} (maximum 10,000 characters).');
    }
    final statuses =
        ReviewStatus.values.where((s) => s.name == value['status']);
    if (statuses.isEmpty) {
      throw FormatException('Invalid review status for ${entry.key}.');
    }
    result[entry.key] =
        DemoReview(status: statuses.single, notes: value['notes'] as String);
  }
  return result;
}
