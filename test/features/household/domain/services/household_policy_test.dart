import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';

void main() {
  const policy = HouseholdPolicy();

  group('creationSpec', () {
    test('free users get a solo household with one member', () {
      final result = policy.creationSpec(
        const HouseholdCreationRequest(
          userIsPremium: false,
          requestJointHousehold: false,
          existingSoloHouseholds: 0,
          existingCreatedJointHouseholds: 0,
        ),
      );

      expect(result, isA<Success<HouseholdCreationSpec>>());
      final spec = (result as Success<HouseholdCreationSpec>).value;
      expect(spec.isJoint, isFalse);
      expect(spec.maxMembers, HouseholdPolicy.soloHouseholdMaxMembers);
      expect(spec.initialRole, HouseholdRole.admin);
    });

    test('free users cannot create joint households', () {
      final result = policy.creationSpec(
        const HouseholdCreationRequest(
          userIsPremium: false,
          requestJointHousehold: true,
          existingSoloHouseholds: 1,
          existingCreatedJointHouseholds: 0,
        ),
      );

      expect(result, isA<ResultFailure<HouseholdCreationSpec>>());
      final failure = (result as ResultFailure<HouseholdCreationSpec>).failure;
      expect(failure, isA<ConflictFailure>());
    });

    test('premium users can create exactly one joint household', () {
      final allowed = policy.creationSpec(
        const HouseholdCreationRequest(
          userIsPremium: true,
          requestJointHousehold: true,
          existingSoloHouseholds: 1,
          existingCreatedJointHouseholds: 0,
        ),
      );
      final denied = policy.creationSpec(
        const HouseholdCreationRequest(
          userIsPremium: true,
          requestJointHousehold: true,
          existingSoloHouseholds: 1,
          existingCreatedJointHouseholds: 1,
        ),
      );

      expect(allowed, isA<Success<HouseholdCreationSpec>>());
      final spec = (allowed as Success<HouseholdCreationSpec>).value;
      expect(spec.isJoint, isTrue);
      expect(spec.maxMembers, HouseholdPolicy.jointHouseholdMaxMembers);
      expect(denied, isA<ResultFailure<HouseholdCreationSpec>>());
    });
  });

  group('joinApproval', () {
    test('free users may join one premium-created joint household', () {
      final result = policy.joinApproval(
        const HouseholdJoinRequest(
          userIsPremium: false,
          householdIsJoint: true,
          householdHasPremium: true,
          invitedRole: HouseholdRole.cook,
          currentMemberCount: 1,
          maxMembers: 6,
          existingJoinedPremiumHouseholds: 0,
        ),
      );

      expect(result, isA<Success<HouseholdJoinApproval>>());
      final approval = (result as Success<HouseholdJoinApproval>).value;
      expect(approval.defaultRole, HouseholdRole.cook);
    });

    test('free users cannot join a second premium household', () {
      final result = policy.joinApproval(
        const HouseholdJoinRequest(
          userIsPremium: false,
          householdIsJoint: true,
          householdHasPremium: true,
          invitedRole: HouseholdRole.member,
          currentMemberCount: 1,
          maxMembers: 6,
          existingJoinedPremiumHouseholds: 1,
        ),
      );

      expect(result, isA<ResultFailure<HouseholdJoinApproval>>());
    });

    test('solo households reject invites once membership would exceed one', () {
      final result = policy.joinApproval(
        const HouseholdJoinRequest(
          userIsPremium: true,
          householdIsJoint: false,
          householdHasPremium: false,
          invitedRole: HouseholdRole.member,
          currentMemberCount: 1,
          maxMembers: 1,
          existingJoinedPremiumHouseholds: 0,
        ),
      );

      expect(result, isA<ResultFailure<HouseholdJoinApproval>>());
    });
  });

  group('roleCan', () {
    test('admin has every capability', () {
      for (final capability in HouseholdCapability.values) {
        expect(policy.roleCan(HouseholdRole.admin, capability), isTrue);
      }
    });

    test('cook can schedule meals but cannot manage membership', () {
      expect(
        policy.roleCan(HouseholdRole.cook, HouseholdCapability.scheduleMeals),
        isTrue,
      );
      expect(
        policy.roleCan(HouseholdRole.cook, HouseholdCapability.inviteMembers),
        isFalse,
      );
    });

    test('only joint admins can configure calendar defaults', () {
      expect(
        policy.roleCan(
          HouseholdRole.admin,
          HouseholdCapability.configureCalendarDefaults,
        ),
        isTrue,
      );
      for (final role in [
        HouseholdRole.cook,
        HouseholdRole.shopper,
        HouseholdRole.member,
      ]) {
        expect(
          policy.roleCan(role, HouseholdCapability.configureCalendarDefaults),
          isFalse,
        );
      }
    });

    test('shopper can complete shopping but cannot schedule meals', () {
      expect(
        policy.roleCan(
          HouseholdRole.shopper,
          HouseholdCapability.completeShopping,
        ),
        isTrue,
      );
      expect(
        policy.roleCan(
          HouseholdRole.shopper,
          HouseholdCapability.scheduleMeals,
        ),
        isFalse,
      );
    });

    test('only joint admins can manage shopping schedules', () {
      expect(
        policy.roleCan(
          HouseholdRole.admin,
          HouseholdCapability.manageShoppingSchedules,
        ),
        isTrue,
      );
      for (final role in [
        HouseholdRole.cook,
        HouseholdRole.shopper,
        HouseholdRole.member,
      ]) {
        expect(
          policy.roleCan(role, HouseholdCapability.manageShoppingSchedules),
          isFalse,
        );
      }
    });

    test('solo members can manage shopping schedules', () {
      expect(
        policy.roleCan(
          HouseholdRole.member,
          HouseholdCapability.manageShoppingSchedules,
          isSoloHousehold: true,
        ),
        isTrue,
      );
    });

    test('member is view-only', () {
      expect(
        policy.roleCan(HouseholdRole.member, HouseholdCapability.viewPantry),
        isTrue,
      );
      expect(
        policy.roleCan(
          HouseholdRole.member,
          HouseholdCapability.editPantryItems,
        ),
        isFalse,
      );
    });

    test('solo household membership unlocks all functional powers', () {
      expect(
        policy.roleCan(
          HouseholdRole.member,
          HouseholdCapability.applyMenuSets,
          isSoloHousehold: true,
        ),
        isTrue,
      );
    });

    // Spec 1.5.2-1.5.4 per-module capability matrix for the non-admin roles.
    // Cook owns Recipes/Calendar/MenuSet authoring; Shopper owns Shopping;
    // Member is view-only; neither non-owning role crosses into the other's.
    test('cook owns recipe, calendar and menu-set authoring only', () {
      const cook = HouseholdRole.cook;
      for (final cap in [
        HouseholdCapability.createRecipes,
        HouseholdCapability.editRecipes,
        HouseholdCapability.deleteRecipes,
        HouseholdCapability.scheduleMeals,
        HouseholdCapability.markMealsCooked,
        HouseholdCapability.adjustMealServings,
        HouseholdCapability.manageLeftovers,
        HouseholdCapability.markCalendarWaste,
        HouseholdCapability.createMenuSets,
        HouseholdCapability.editMenuSets,
        HouseholdCapability.applyMenuSets,
      ]) {
        expect(policy.roleCan(cook, cap), isTrue, reason: '$cap');
      }
      // Spec 1.5.2: Cook cannot manage membership or shopping/schedule/admin.
      for (final cap in [
        HouseholdCapability.inviteMembers,
        HouseholdCapability.removeMembers,
        HouseholdCapability.assignRoles,
        HouseholdCapability.transferAdmin,
        HouseholdCapability.manageShoppingSchedules,
        HouseholdCapability.configureCalendarDefaults,
        HouseholdCapability.generateShoppingLists,
        HouseholdCapability.completeShopping,
        HouseholdCapability.deleteMenuSets,
      ]) {
        expect(policy.roleCan(cook, cap), isFalse, reason: '$cap');
      }
    });

    test('shopper owns shopping actions only', () {
      const shopper = HouseholdRole.shopper;
      for (final cap in [
        HouseholdCapability.generateShoppingLists,
        HouseholdCapability.editShoppingLists,
        HouseholdCapability.finalizeShoppingLists,
        HouseholdCapability.deleteShoppingLists,
        HouseholdCapability.completeShopping,
        HouseholdCapability.confirmSubstitutions,
        HouseholdCapability.updatePurchasedQuantities,
        HouseholdCapability.initiateShopNow,
        HouseholdCapability.reviewBulkItems,
      ]) {
        expect(policy.roleCan(shopper, cap), isTrue, reason: '$cap');
      }
      // Spec 1.5.3: Shopper cannot schedule meals or author recipes/menu sets.
      for (final cap in [
        HouseholdCapability.scheduleMeals,
        HouseholdCapability.markMealsCooked,
        HouseholdCapability.createRecipes,
        HouseholdCapability.editRecipes,
        HouseholdCapability.createMenuSets,
        HouseholdCapability.editMenuSets,
        HouseholdCapability.inviteMembers,
      ]) {
        expect(policy.roleCan(shopper, cap), isFalse, reason: '$cap');
      }
    });

    test('member cannot mutate any module', () {
      const member = HouseholdRole.member;
      for (final cap in [
        HouseholdCapability.createRecipes,
        HouseholdCapability.editRecipes,
        HouseholdCapability.scheduleMeals,
        HouseholdCapability.generateShoppingLists,
        HouseholdCapability.completeShopping,
        HouseholdCapability.createMenuSets,
        HouseholdCapability.applyMenuSets,
        HouseholdCapability.editPantryItems,
        HouseholdCapability.inviteMembers,
      ]) {
        expect(policy.roleCan(member, cap), isFalse, reason: '$cap');
      }
      // Spec 1.5.4: Member retains view + social capabilities.
      for (final cap in [
        HouseholdCapability.viewRecipes,
        HouseholdCapability.viewPantry,
        HouseholdCapability.viewCalendar,
        HouseholdCapability.viewShoppingList,
      ]) {
        expect(policy.roleCan(member, cap), isTrue, reason: '$cap');
      }
    });
  });

  group('premium checks', () {
    test('menu sets tab is visible only for premium households', () {
      expect(policy.canShowMenuSetsTab(householdHasPremium: true), isTrue);
      expect(policy.canShowMenuSetsTab(householdHasPremium: false), isFalse);
    });

    test('premium capabilities require a premium household', () {
      expect(
        policy.canUsePremiumCapability(
          householdHasPremium: false,
          capability: HouseholdCapability.applyMenuSets,
        ),
        isFalse,
      );
      expect(
        policy.canUsePremiumCapability(
          householdHasPremium: false,
          capability: HouseholdCapability.viewRecipes,
        ),
        isTrue,
      );
    });
  });
}
