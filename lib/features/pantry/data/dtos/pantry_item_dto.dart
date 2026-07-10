import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

class PantryItemMapper {
  const PantryItemMapper._();

  static Map<String, dynamic> toMap(PantryItem p) => {
    'householdId': p.householdId,
    'ingredientId': p.ingredientId,
    'quantity': p.quantity,
    'unit': p.unit.value,
    'section': p.section.name,
    'imageUrl': p.imageUrl,
    'note': p.note,
    'relatedRecipeId': p.relatedRecipeId,
    'leftoverServings': p.leftoverServings,
    'lastPurchaseDate': p.lastPurchaseDate != null
        ? Timestamp.fromDate(p.lastPurchaseDate!)
        : null,
    'expiryDate': p.expiryDate != null
        ? Timestamp.fromDate(p.expiryDate!)
        : null,
    'openedAt': p.openedAt != null ? Timestamp.fromDate(p.openedAt!) : null,
    'schemaVersion': p.schemaVersion,
    'createdAt': Timestamp.fromDate(p.createdAt),
    'updatedAt': Timestamp.fromDate(p.updatedAt),
  };

  static PantryItem fromMap(String id, Map<String, dynamic> m) => PantryItem(
    id: id,
    householdId: m['householdId'] as String,
    ingredientId: m['ingredientId'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    unit: UnitId(m['unit'] as String),
    section: _enumFromName(PantrySection.values, m['section'] as String),
    imageUrl: m['imageUrl'] as String?,
    note: m['note'] as String?,
    relatedRecipeId: m['relatedRecipeId'] as String?,
    leftoverServings: m['leftoverServings'] as int?,
    lastPurchaseDate: (m['lastPurchaseDate'] as Timestamp?)?.toDate(),
    expiryDate: (m['expiryDate'] as Timestamp?)?.toDate(),
    openedAt: (m['openedAt'] as Timestamp?)?.toDate(),
    schemaVersion: (m['schemaVersion'] as int?) ?? 1,
    createdAt: (m['createdAt'] as Timestamp).toDate(),
    updatedAt: (m['updatedAt'] as Timestamp).toDate(),
  );

  static T _enumFromName<T extends Enum>(List<T> values, Object name) {
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException(
        'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
      ),
    );
  }
}
