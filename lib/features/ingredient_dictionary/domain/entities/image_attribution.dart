import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_attribution.freezed.dart';
part 'image_attribution.g.dart';

@freezed
class ImageAttribution with _$ImageAttribution {
  const factory ImageAttribution({
    required String source,
    required String license,
    String? sourceUrl,
    String? author,
  }) = _ImageAttribution;

  factory ImageAttribution.fromJson(Map<String, dynamic> json) =>
      _$ImageAttributionFromJson(json);
}
