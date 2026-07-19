import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';

class HouseholdPolicy {
  const HouseholdPolicy();

  static const int soloHouseholdMaxMembers = 1;
  static const int jointHouseholdMaxMembers = 6;

  Result<HouseholdCreationSpec> creationSpec(HouseholdCreationRequest request) {
    if (request.requestJointHousehold) {
      if (!request.userIsPremium) {
        return const Result.failure(
          Failure.conflict(
            reason: 'Only premium users can create joint households.',
          ),
        );
      }
      if (request.existingCreatedJointHouseholds > 0) {
        return const Result.failure(
          Failure.conflict(
            reason: 'Premium users can only create one joint household.',
          ),
        );
      }
      return const Result.success(
        HouseholdCreationSpec(
          isJoint: true,
          maxMembers: jointHouseholdMaxMembers,
          initialRole: HouseholdRole.admin,
        ),
      );
    }

    if (request.existingSoloHouseholds > 0) {
      return const Result.failure(
        Failure.conflict(reason: 'A user can only have one solo household.'),
      );
    }
    return const Result.success(
      HouseholdCreationSpec(
        isJoint: false,
        maxMembers: soloHouseholdMaxMembers,
        initialRole: HouseholdRole.admin,
      ),
    );
  }

  Result<HouseholdJoinApproval> joinApproval(HouseholdJoinRequest request) {
    if (!request.householdIsJoint) {
      return const Result.failure(
        Failure.conflict(reason: 'Solo households cannot accept invitations.'),
      );
    }
    if (request.currentMemberCount >= request.maxMembers) {
      return const Result.failure(
        Failure.conflict(reason: 'Household member limit has been reached.'),
      );
    }
    if (!request.userIsPremium) {
      if (!request.householdHasPremium) {
        return const Result.failure(
          Failure.conflict(
            reason: 'Free users can only join premium-created households.',
          ),
        );
      }
      if (request.existingJoinedPremiumHouseholds > 0) {
        return const Result.failure(
          Failure.conflict(
            reason: 'Free users can only join one premium household.',
          ),
        );
      }
    }

    return Result.success(
      HouseholdJoinApproval(defaultRole: request.invitedRole),
    );
  }

  bool canShowMenuSetsTab({required bool householdHasPremium}) {
    return householdHasPremium;
  }

  bool canUsePremiumCapability({
    required bool householdHasPremium,
    required HouseholdCapability capability,
  }) {
    if (!_premiumCapabilities.contains(capability)) {
      return true;
    }
    return householdHasPremium;
  }

  bool roleCan(
    HouseholdRole role,
    HouseholdCapability capability, {
    bool isSoloHousehold = false,
  }) {
    if (isSoloHousehold) {
      return true;
    }
    return _roleCapabilities[role]!.contains(capability);
  }
}

const Set<HouseholdCapability> _viewCapabilities = {
  HouseholdCapability.viewRecipes,
  HouseholdCapability.viewPantry,
  HouseholdCapability.viewCalendar,
  HouseholdCapability.viewShoppingList,
  HouseholdCapability.viewMenuSets,
  HouseholdCapability.commentOnRecipes,
  HouseholdCapability.savePublicRecipes,
  HouseholdCapability.likeRecipes,
};

const Set<HouseholdCapability> _cookCapabilities = {
  ..._viewCapabilities,
  HouseholdCapability.createRecipes,
  HouseholdCapability.editRecipes,
  HouseholdCapability.deleteRecipes,
  HouseholdCapability.scheduleMeals,
  HouseholdCapability.removeScheduledMeals,
  HouseholdCapability.markMealsCooked,
  HouseholdCapability.adjustMealServings,
  HouseholdCapability.manageLeftovers,
  HouseholdCapability.markCalendarWaste,
  HouseholdCapability.createMenuSets,
  HouseholdCapability.editMenuSets,
  HouseholdCapability.applyMenuSets,
  HouseholdCapability.markIngredientsConsumed,
  HouseholdCapability.recordLeftovers,
  HouseholdCapability.editPantryItems,
};

const Set<HouseholdCapability> _shopperCapabilities = {
  ..._viewCapabilities,
  HouseholdCapability.generateShoppingLists,
  HouseholdCapability.editShoppingLists,
  HouseholdCapability.finalizeShoppingLists,
  HouseholdCapability.deleteShoppingLists,
  HouseholdCapability.completeShopping,
  HouseholdCapability.confirmSubstitutions,
  HouseholdCapability.updatePurchasedQuantities,
  HouseholdCapability.initiateShopNow,
  HouseholdCapability.reviewBulkItems,
  HouseholdCapability.verifyPurchasedItems,
  HouseholdCapability.editPantryItems,
};

const Set<HouseholdCapability> _adminCapabilities = {
  ...HouseholdCapability.values,
};

const Map<HouseholdRole, Set<HouseholdCapability>> _roleCapabilities = {
  HouseholdRole.admin: _adminCapabilities,
  HouseholdRole.cook: _cookCapabilities,
  HouseholdRole.shopper: _shopperCapabilities,
  HouseholdRole.member: _viewCapabilities,
};

const Set<HouseholdCapability> _premiumCapabilities = {
  HouseholdCapability.viewMenuSets,
  HouseholdCapability.createMenuSets,
  HouseholdCapability.editMenuSets,
  HouseholdCapability.deleteMenuSets,
  HouseholdCapability.applyMenuSets,
  HouseholdCapability.createMenuSetsFromPastCalendar,
  HouseholdCapability.reviewBulkItems,
  HouseholdCapability.viewPantryMetrics,
  HouseholdCapability.manageBulkPredictions,
};
