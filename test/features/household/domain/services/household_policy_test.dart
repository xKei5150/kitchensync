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
          currentMemberCount: 1,
          maxMembers: 6,
          existingJoinedPremiumHouseholds: 0,
        ),
      );

      expect(result, isA<Success<HouseholdJoinApproval>>());
      final approval = (result as Success<HouseholdJoinApproval>).value;
      expect(approval.defaultRole, HouseholdRole.member);
    });

    test('free users cannot join a second premium household', () {
      final result = policy.joinApproval(
        const HouseholdJoinRequest(
          userIsPremium: false,
          householdIsJoint: true,
          householdHasPremium: true,
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
