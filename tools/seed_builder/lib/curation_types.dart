enum CurationStatus { accepted, needsReview }

const allowedTaxonomyTags = <String>{
  'allium',
  'berry',
  'citrus',
  'leafyGreen',
  'legume',
  'mushroom',
  'processedMeat',
  'rootVegetable',
  'stoneFruit',
  'treeNut',
};

const allowedFormTags = <String>{
  'canned',
  'dried',
  'fresh',
  'frozen',
  'ground',
  'packaged',
  'powdered',
  'prepared',
  'raw',
  'roasted',
};

class CurationMetadata {
  const CurationMetadata({
    required this.status,
    required this.confidence,
    required this.source,
    required this.notes,
  });

  final CurationStatus status;
  final double confidence;
  final String source;
  final String notes;

  factory CurationMetadata.fromMap(Map<String, Object?> map) {
    final statusName = map['status'] as String? ?? 'needsReview';
    return CurationMetadata(
      status: CurationStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => CurationStatus.needsReview,
      ),
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
      source: map['source'] as String? ?? 'unknown',
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() => {
        'status': status.name,
        'confidence': confidence,
        'source': source,
        'notes': notes,
      };
}
