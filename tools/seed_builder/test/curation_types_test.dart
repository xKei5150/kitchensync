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
  });
}
