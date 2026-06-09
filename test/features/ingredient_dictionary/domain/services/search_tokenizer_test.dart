import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

void main() {
  group('SearchTokenizer', () {
    test('lowercases and splits on whitespace', () {
      expect(
        SearchTokenizer.tokenize('Red Onion'),
        containsAll(<String>['red', 'onion']),
      );
    });
    test('strips diacritics', () {
      expect(
        SearchTokenizer.tokenize('Crème fraîche'),
        containsAll(<String>['creme', 'fraiche']),
      );
    });
    test('deduplicates tokens', () {
      final tokens = SearchTokenizer.tokenize('tomato Tomato TOMATO');
      expect(tokens.length, 1);
      expect(tokens.first, 'tomato');
    });
    test('drops empty / whitespace-only inputs', () {
      expect(SearchTokenizer.tokenize('   '), isEmpty);
    });
    test(
      'buildIndex unions names, aliases, parent, taxonomy, and form tags',
      () {
        final tokens = SearchTokenizer.buildIndex(
          displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
          aliases: const ['Spanish onion'],
          parentTokens: const ['onion'],
          taxonomyTags: const ['allium'],
          formTags: const ['fresh'],
        );
        expect(
          tokens,
          containsAll(<String>[
            'red',
            'onion',
            'pulang',
            'sibuyas',
            'spanish',
            'allium',
            'fresh',
          ]),
        );
      },
    );
  });
}
