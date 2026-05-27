import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';

void main() {
  test('round-trips through JSON with all fields', () {
    const attr = ImageAttribution(
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Onion.jpg',
      author: 'Jane Doe',
    );
    expect(ImageAttribution.fromJson(attr.toJson()), attr);
  });

  test('round-trips through JSON with required fields only', () {
    const attr = ImageAttribution(
      source: 'Unsplash',
      license: 'Unsplash License',
    );
    expect(ImageAttribution.fromJson(attr.toJson()), attr);
  });
}
