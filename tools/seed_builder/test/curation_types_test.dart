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
}
