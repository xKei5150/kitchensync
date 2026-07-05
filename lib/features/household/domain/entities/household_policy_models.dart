enum HouseholdRole { admin, cook, shopper, member }

extension HouseholdRoleX on HouseholdRole {
  String get label => switch (this) {
    HouseholdRole.admin => 'Admin',
    HouseholdRole.cook => 'Cook',
    HouseholdRole.shopper => 'Shopper',
    HouseholdRole.member => 'Member',
  };
}

enum HouseholdCapability {
  viewRecipes,
  viewPantry,
  viewCalendar,
  viewShoppingList,
  viewMenuSets,
  createRecipes,
  editRecipes,
  deleteRecipes,
  commentOnRecipes,
  savePublicRecipes,
  likeRecipes,
  inviteMembers,
  removeMembers,
  assignRoles,
  manageHouseholdSettings,
  transferAdmin,
  createMenuSets,
  editMenuSets,
  deleteMenuSets,
  applyMenuSets,
  createMenuSetsFromPastCalendar,
  configureCalendarDefaults,
  scheduleMeals,
  removeScheduledMeals,
  markMealsCooked,
  adjustMealServings,
  manageLeftovers,
  markCalendarWaste,
  manageShoppingSchedules,
  generateShoppingLists,
  editShoppingLists,
  finalizeShoppingLists,
  deleteShoppingLists,
  completeShopping,
  confirmSubstitutions,
  updatePurchasedQuantities,
  initiateShopNow,
  reviewBulkItems,
  addPantryItems,
  editPantryItems,
  removePantryItems,
  overridePantryItems,
  markPantryWaste,
  viewPantryMetrics,
  manageBulkPredictions,
  markIngredientsConsumed,
  recordLeftovers,
  verifyPurchasedItems,
}

class HouseholdCreationRequest {
  const HouseholdCreationRequest({
    required this.userIsPremium,
    required this.requestJointHousehold,
    required this.existingSoloHouseholds,
    required this.existingCreatedJointHouseholds,
  });

  final bool userIsPremium;
  final bool requestJointHousehold;
  final int existingSoloHouseholds;
  final int existingCreatedJointHouseholds;
}

class HouseholdCreationSpec {
  const HouseholdCreationSpec({
    required this.isJoint,
    required this.maxMembers,
    required this.initialRole,
  });

  final bool isJoint;
  final int maxMembers;
  final HouseholdRole initialRole;
}

class HouseholdJoinRequest {
  const HouseholdJoinRequest({
    required this.userIsPremium,
    required this.householdIsJoint,
    required this.householdHasPremium,
    required this.currentMemberCount,
    required this.maxMembers,
    required this.existingJoinedPremiumHouseholds,
  });

  final bool userIsPremium;
  final bool householdIsJoint;
  final bool householdHasPremium;
  final int currentMemberCount;
  final int maxMembers;
  final int existingJoinedPremiumHouseholds;
}

class HouseholdJoinApproval {
  const HouseholdJoinApproval({required this.defaultRole});

  final HouseholdRole defaultRole;
}
