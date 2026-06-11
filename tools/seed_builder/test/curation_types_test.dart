import 'package:seed_builder/curation_types.dart';
import 'package:test/test.dart';

void main() {
  group('CurationMetadata', () {
    test('parses accepted curation metadata from map', () {
      final metadata = CurationMetadata.fromMap({
        'status': 'accepted',
        'confidence': 0.93,
        'source': 'llm-assisted',
        'notes': 'Grouped under onion.',
      });

      expect(metadata.status, CurationStatus.accepted);
      expect(metadata.confidence, 0.93);
      expect(metadata.source, 'llm-assisted');
      expect(metadata.notes, 'Grouped under onion.');
    });

    test('CurationMetadata.toMap omits AGROVOC fields when null', () {
      const meta = CurationMetadata(
        status: CurationStatus.accepted,
        confidence: 0.9,
        source: 'llm-assisted',
        notes: '',
      );
      expect(meta.toMap().containsKey('agrovocStatus'), isFalse);
    });

    test('CurationMetadata.toMap includes AGROVOC fields when set', () {
      const meta = CurationMetadata(
        status: CurationStatus.accepted,
        confidence: 0.9,
        source: 'llm-assisted+agrovoc',
        notes: '',
        agrovocConfidence: 0.92,
        agrovocStatus: 'matched',
      );
      final map = meta.toMap();
      expect(map['agrovocConfidence'], 0.92);
      expect(map['agrovocStatus'], 'matched');
    });
  });

  group('IngredientCurationProposal', () {
    test('clamps out-of-range confidence from untrusted LLM output', () {
      final high = IngredientCurationProposal.fromMap({
        'id': 'x',
        'displayNameEn': 'X',
        'category': 'produce',
        'confidence': 1.5,
      });
      final low = IngredientCurationProposal.fromMap({
        'id': 'y',
        'displayNameEn': 'Y',
        'category': 'produce',
        'confidence': -0.4,
      });

      expect(high.confidence, 1.0);
      expect(low.confidence, 0.0);
    });

    test('proposal parses AGROVOC fields and clamps confidence', () {
      final proposal = IngredientCurationProposal.fromMap({
        'id': 'milk',
        'displayNameEn': 'Milk',
        'category': 'dairy',
        'aliases': <String>[],
        'taxonomyTags': <String>[],
        'formTags': <String>[],
        'isNonFood': false,
        'confidence': 0.9,
        'reason': 'ok',
        'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826',
        'agrovocConfidence': 1.4,
      });
      expect(proposal.agrovocUri, 'http://aims.fao.org/aos/agrovoc/c_4826');
      expect(proposal.agrovocConfidence, 1.0); // clamped
    });

    test('proposal defaults AGROVOC fields when absent', () {
      final proposal = IngredientCurationProposal.fromMap({
        'id': 'x',
        'displayNameEn': 'X',
        'category': 'other',
      });
      expect(proposal.agrovocUri, isNull);
      expect(proposal.agrovocConfidence, 0.0);
    });
  });

  group('AGROVOC language constants', () {
    test('target language constants split core and extra', () {
      expect(agrovocCoreLangs, ['en', 'fr', 'es', 'ru', 'ar', 'zh']);
      expect(agrovocExtraLangs, ['ja', 'vi', 'th', 'ko']);
      expect(agrovocTargetLangs, [
        'en', 'fr', 'es', 'ru', 'ar', 'zh', 'ja', 'vi', 'th', 'ko',
      ]);
    });
  });
}
