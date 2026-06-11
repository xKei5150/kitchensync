import 'package:seed_builder/agrovoc_query.dart';
import 'package:test/test.dart';

void main() {
  group('primaryTerm', () {
    test('takes the first comma segment, lowercased', () {
      expect(
        primaryTerm('Beans, snap, green, canned, regular pack, drained solids'),
        'beans',
      );
      expect(primaryTerm('Tomatoes, grape, raw'), 'tomatoes');
      expect(primaryTerm('Milk, reduced fat, fluid, 2% milkfat'), 'milk');
    });

    test('strips parentheticals and trims', () {
      expect(primaryTerm('Milk (skim)'), 'milk');
    });
  });

  test('searchQuery wraps the primary term for substring search', () {
    expect(searchQuery('Beans, snap, green'), '*beans*');
  });

  group('parseSearch', () {
    test('maps results to candidates', () {
      final decoded = {
        'results': [
          {'uri': 'http://x/c_1', 'prefLabel': 'green beans', 'lang': 'en'},
          {'uri': 'http://x/c_2', 'prefLabel': 'common beans', 'lang': 'en'},
        ],
      };
      final candidates = parseSearch(decoded);
      expect(candidates.map((c) => c.uri), ['http://x/c_1', 'http://x/c_2']);
      expect(candidates.first.prefLabel, 'green beans');
      expect(candidates.first.toJson(), {'uri': 'http://x/c_1', 'label': 'green beans'});
    });

    test('tolerates a missing prefLabel', () {
      final candidates = parseSearch({
        'results': [
          {'uri': 'http://x/c_3'},
        ],
      });
      expect(candidates.single.prefLabel, '');
    });
  });

  group('parseLabels', () {
    const uri = 'http://aims.fao.org/aos/agrovoc/c_4826';

    test('extracts only target languages from a prefLabel list', () {
      final decoded = {
        'graph': [
          {
            'uri': uri,
            'prefLabel': [
              {'lang': 'en', 'value': 'milk'},
              {'lang': 'fr', 'value': 'lait'},
              {'lang': 'xx', 'value': 'ignored'},
            ],
          },
        ],
      };
      expect(parseLabels(decoded, uri, {'en', 'fr'}), {'en': 'milk', 'fr': 'lait'});
    });

    test('handles a single prefLabel object (not a list)', () {
      final decoded = {
        'graph': [
          {
            'uri': uri,
            'prefLabel': {'lang': 'en', 'value': 'milk'},
          },
        ],
      };
      expect(parseLabels(decoded, uri, {'en'}), {'en': 'milk'});
    });

    test('returns empty when the concept node is absent', () {
      expect(parseLabels({'graph': []}, uri, {'en'}), isEmpty);
    });
  });

  test('parseAltLabels returns values for the requested language only', () {
    const uri = 'http://x/c_1';
    final decoded = {
      'graph': [
        {
          'uri': uri,
          'altLabel': [
            {'lang': 'en', 'value': 'whole milk'},
            {'lang': 'zh', 'value': '奶'},
          ],
        },
      ],
    };
    expect(parseAltLabels(decoded, uri, 'en'), ['whole milk']);
  });

  test('stableHash is deterministic and hex', () {
    expect(stableHash('milk|5'), stableHash('milk|5'));
    expect(stableHash('a'), matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(stableHash('a') == stableHash('b'), isFalse);
  });
}
