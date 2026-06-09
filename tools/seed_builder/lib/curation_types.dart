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

class IngredientCurationProposal {
  const IngredientCurationProposal({
    required this.id,
    required this.displayNameEn,
    this.parentIngredientId,
    required this.category,
    required this.aliases,
    required this.taxonomyTags,
    required this.formTags,
    required this.isNonFood,
    required this.confidence,
    required this.reason,
  });

  final String id;
  final String displayNameEn;
  final String? parentIngredientId;
  final String category;
  final List<String> aliases;
  final List<String> taxonomyTags;
  final List<String> formTags;
  final bool isNonFood;
  final double confidence;
  final String reason;

  factory IngredientCurationProposal.fromMap(Map<String, Object?> map) {
    return IngredientCurationProposal(
      id: map['id'] as String,
      displayNameEn: map['displayNameEn'] as String,
      parentIngredientId: map['parentIngredientId'] as String?,
      category: map['category'] as String,
      aliases: ((map['aliases'] as List?) ?? const []).cast<String>(),
      taxonomyTags: ((map['taxonomyTags'] as List?) ?? const []).cast<String>(),
      formTags: ((map['formTags'] as List?) ?? const []).cast<String>(),
      isNonFood: map['isNonFood'] as bool? ?? false,
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
      reason: map['reason'] as String? ?? '',
    );
  }
}
