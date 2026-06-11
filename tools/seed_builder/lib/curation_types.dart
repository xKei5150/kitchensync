enum CurationStatus { accepted, needsReview }

/// AGROVOC released under CC-BY 3.0 IGO (attribute FAO).
const agrovocCoreLangs = <String>['en', 'fr', 'es', 'ru', 'ar', 'zh'];

/// Extra app-target languages; AGROVOC coverage is uneven and licensing is
/// non-core, so missing extras are reported, never gated.
const agrovocExtraLangs = <String>['ja', 'vi', 'th', 'ko'];

const agrovocTargetLangs = <String>[...agrovocCoreLangs, ...agrovocExtraLangs];

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
    this.agrovocConfidence,
    this.agrovocStatus,
  });

  final CurationStatus status;
  final double confidence;
  final String source;
  final String notes;
  final double? agrovocConfidence;
  final String? agrovocStatus;

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
      agrovocConfidence: (map['agrovocConfidence'] as num?)?.toDouble(),
      agrovocStatus: map['agrovocStatus'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'status': status.name,
    'confidence': confidence,
    'source': source,
    'notes': notes,
    if (agrovocConfidence != null) 'agrovocConfidence': agrovocConfidence,
    if (agrovocStatus != null) 'agrovocStatus': agrovocStatus,
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
    this.agrovocUri,
    this.agrovocConfidence = 0.0,
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
  final String? agrovocUri;
  final double agrovocConfidence;

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
      // LLM output is untrusted: clamp confidence into the documented range.
      confidence: (map['confidence'] as num? ?? 0).toDouble().clamp(0.0, 1.0),
      reason: map['reason'] as String? ?? '',
      agrovocUri: map['agrovocUri'] as String?,
      agrovocConfidence: (map['agrovocConfidence'] as num? ?? 0)
          .toDouble()
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }
}
