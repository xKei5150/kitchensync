import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

class MenuSetMapper {
  const MenuSetMapper._();

  static Map<String, dynamic> toMap(MenuSet menuSet) => {
    'householdId': menuSet.householdId,
    'name': menuSet.name,
    'description': menuSet.description,
    'lengthInDays': menuSet.lengthInDays,
    'createdByUserId': menuSet.createdByUserId,
    'createdAt': menuSet.createdAt == null
        ? null
        : Timestamp.fromDate(menuSet.createdAt!),
    'updatedAt': menuSet.updatedAt == null
        ? null
        : Timestamp.fromDate(menuSet.updatedAt!),
    'isPublicTemplate': menuSet.isPublicTemplate,
  };

  static MenuSet fromMap({
    required String id,
    required Map<String, dynamic> map,
    required List<MenuSetDay> days,
  }) {
    return MenuSet(
      id: id,
      householdId: map['householdId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      lengthInDays: map['lengthInDays'] as int,
      createdByUserId: map['createdByUserId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isPublicTemplate: (map['isPublicTemplate'] as bool?) ?? false,
      days: List.unmodifiable(days),
    );
  }
}

class MenuSetDayMapper {
  const MenuSetDayMapper._();

  static Map<String, dynamic> toMap(MenuSetDay day) => {
    'menuSetId': day.menuSetId,
    'dayIndex': day.dayIndex,
    'label': day.label,
  };

  static MenuSetDay fromMap({
    required String id,
    required Map<String, dynamic> map,
    required List<MenuSetEntry> entries,
  }) {
    return MenuSetDay(
      id: id,
      menuSetId: map['menuSetId'] as String,
      dayIndex: map['dayIndex'] as int,
      label: map['label'] as String?,
      entries: List.unmodifiable(entries),
    );
  }
}

class MenuSetEntryMapper {
  const MenuSetEntryMapper._();

  static Map<String, dynamic> toMap(MenuSetEntry entry) => {
    'menuSetDayId': entry.menuSetDayId,
    'mealSlot': entry.mealSlot,
    'recipeId': entry.recipeId,
    'orderInSlot': entry.orderInSlot,
  };

  static MenuSetEntry fromMap(String id, Map<String, dynamic> map) {
    return MenuSetEntry(
      id: id,
      menuSetDayId: map['menuSetDayId'] as String,
      mealSlot: map['mealSlot'] as String,
      recipeId: map['recipeId'] as String,
      orderInSlot: map['orderInSlot'] as int,
    );
  }
}
