// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../src/interfaces/IERC7540Operators.sol";
import {IERC7540Redeem} from "../src/interfaces/IERC7540Redeem.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IReentrancyGuard} from "../src/interfaces/IReentrancyGuard.sol";
import {LibERC7540RequestAccounting} from "../src/vault/libraries/LibERC7540RequestAccounting.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {ERC7540VaultFoundationFixture} from "./helpers/ERC7540VaultFoundationTestHarness.sol";

contract ERC7540VaultFoundationCoreTest is ERC7540VaultFoundationFixture {
    function testErc7540InterfaceIdsMatchSpecConstants() public pure {
        assertTrue(type(IERC7540Operators).interfaceId == 0xe3bc4e65, "operator interface id mismatch");
        assertTrue(type(IERC7540Deposit).interfaceId == 0xce3bbe50, "deposit interface id mismatch");
        assertTrue(type(IERC7540Redeem).interfaceId == 0x620ee8e4, "redeem interface id mismatch");
    }

    function testAsyncSelectorGroupCoversExpectedSurface() public pure {
        bytes4[] memory asyncSelectors = LibVaultFacetSelectors.vaultAsyncSelectors();
        bytes4[] memory coreSelectors = LibVaultFacetSelectors.vaultFullyAsyncHostCoreSelectors();
        bytes4[] memory nativeSelectors = LibVaultFacetSelectors.vaultNativeSelectors();
        bytes4[] memory controlSelectors = LibVaultFacetSelectors.vaultControlsSelectors();
        bytes4[] memory integrationSelectors = LibVaultFacetSelectors.vaultAsyncIntegrationSelectors();

        assertTrue(asyncSelectors.length == 22, "unexpected async selector count");

        _assertContains(asyncSelectors, IERC7540Deposit.requestDeposit.selector);
        _assertContains(asyncSelectors, IERC7540Deposit.pendingDepositRequest.selector);
        _assertContains(asyncSelectors, IERC7540Deposit.claimableDepositRequest.selector);
        _assertContains(asyncSelectors, IERC7540Deposit.deposit.selector);
        _assertContains(asyncSelectors, IERC7540Deposit.mint.selector);
        _assertContains(asyncSelectors, IERC4626.maxWithdraw.selector);
        _assertContains(asyncSelectors, IERC4626.previewWithdraw.selector);
        _assertContains(asyncSelectors, IERC4626.withdraw.selector);
        _assertContains(asyncSelectors, IERC4626.maxRedeem.selector);
        _assertContains(asyncSelectors, IERC4626.previewRedeem.selector);
        _assertContains(asyncSelectors, IERC4626.redeem.selector);
        _assertContains(asyncSelectors, IERC7540Redeem.requestRedeem.selector);
        _assertContains(asyncSelectors, IERC7540Redeem.pendingRedeemRequest.selector);
        _assertContains(asyncSelectors, IERC7540Redeem.claimableRedeemRequest.selector);
        _assertContains(asyncSelectors, IERC7540Operators.isOperator.selector);
        _assertContains(asyncSelectors, IERC7540Operators.setOperator.selector);

        _assertUnique(asyncSelectors);
        _assertDisjoint(asyncSelectors, coreSelectors);
        _assertDisjoint(asyncSelectors, nativeSelectors);
        _assertDisjoint(asyncSelectors, controlSelectors);
        _assertDisjoint(asyncSelectors, integrationSelectors);
    }

    function testZeroStateReturnsZeroAcrossAllBuckets() public view {
        assertTrue(harness.aggregateRequestId() == 0, "aggregate request id mismatch");
        assertTrue(harness.pendingDepositRequest(0, bob) == 0, "pending deposit should start at zero");
        assertTrue(harness.claimableDepositRequest(0, bob) == 0, "claimable deposit should start at zero");
        assertTrue(harness.pendingRedeemRequest(0, bob) == 0, "pending redeem should start at zero");
        assertTrue(harness.claimableRedeemRequest(0, bob) == 0, "claimable redeem should start at zero");
        assertFalse(harness.isOperator(bob, eve), "operator approval should start unset");
        assertTrue(harness.totalPendingDepositRequestAssets() == 0, "pending deposit total should start at zero");
        assertTrue(harness.totalClaimableDepositRequestAssets() == 0, "claimable deposit total should start at zero");
        assertTrue(harness.totalPendingRedeemRequestShares() == 0, "pending redeem total should start at zero");
        assertTrue(harness.totalClaimableRedeemRequestShares() == 0, "claimable redeem total should start at zero");
    }

    function testAggregateRequestViewsIgnoreUnsupportedRequestIds() public {
        harness.increasePendingDeposit(bob, 40);
        harness.increasePendingRedeem(bob, 15);

        assertTrue(harness.pendingDepositRequest(0, bob) == 40, "aggregate pending deposit mismatch");
        assertTrue(harness.pendingRedeemRequest(0, bob) == 15, "aggregate pending redeem mismatch");
        assertTrue(harness.pendingDepositRequest(1, bob) == 0, "non-aggregate deposit id should read zero");
        assertTrue(harness.pendingRedeemRequest(1, bob) == 0, "non-aggregate redeem id should read zero");
    }

    function testRequireAggregateRequestIdRevertsForNonZeroIds() public {
        VM.expectRevert(abi.encodeWithSelector(LibERC7540RequestAccounting.ERC7540VaultInvalidRequestId.selector, 7));
        harness.requireAggregateRequestId(7);
    }

    function testDepositAccountingUpdatesControllerAndTotals() public {
        harness.increasePendingDeposit(bob, 40);
        harness.movePendingDepositToClaimable(bob, 25);
        harness.consumeClaimableDeposit(bob, 10);

        assertTrue(harness.pendingDepositRequest(0, bob) == 15, "pending deposit mismatch");
        assertTrue(harness.claimableDepositRequest(0, bob) == 15, "claimable deposit mismatch");
        assertTrue(harness.totalPendingDepositRequestAssets() == 15, "pending deposit total mismatch");
        assertTrue(harness.totalClaimableDepositRequestAssets() == 15, "claimable deposit total mismatch");
        assertTrue(harness.pendingRedeemRequest(0, bob) == 0, "redeem state should stay isolated");
        assertTrue(harness.totalPendingRedeemRequestShares() == 0, "redeem total should stay isolated");
    }

    function testRedeemAccountingUpdatesControllerAndTotals() public {
        harness.increasePendingRedeem(carol, 30);
        harness.movePendingRedeemToClaimable(carol, 12);
        harness.consumeClaimableRedeem(carol, 5);

        assertTrue(harness.pendingRedeemRequest(0, carol) == 18, "pending redeem mismatch");
        assertTrue(harness.claimableRedeemRequest(0, carol) == 7, "claimable redeem mismatch");
        assertTrue(harness.totalPendingRedeemRequestShares() == 18, "pending redeem total mismatch");
        assertTrue(harness.totalClaimableRedeemRequestShares() == 7, "claimable redeem total mismatch");
        assertTrue(harness.pendingDepositRequest(0, carol) == 0, "deposit state should stay isolated");
        assertTrue(harness.totalPendingDepositRequestAssets() == 0, "deposit total should stay isolated");
    }

    function testDepositAccountingRevertsWhenMovingOrConsumingBeyondBalance() public {
        harness.increasePendingDeposit(bob, 5);

        VM.expectRevert(
            abi.encodeWithSelector(
                LibERC7540RequestAccounting.ERC7540VaultInsufficientPendingDepositRequest.selector, bob, 5, 6
            )
        );
        harness.movePendingDepositToClaimable(bob, 6);

        harness.movePendingDepositToClaimable(bob, 5);

        VM.expectRevert(
            abi.encodeWithSelector(
                LibERC7540RequestAccounting.ERC7540VaultInsufficientClaimableDepositRequest.selector, bob, 5, 6
            )
        );
        harness.consumeClaimableDeposit(bob, 6);
    }

    function testRedeemAccountingRevertsWhenMovingOrConsumingBeyondBalance() public {
        harness.increasePendingRedeem(carol, 8);

        VM.expectRevert(
            abi.encodeWithSelector(
                LibERC7540RequestAccounting.ERC7540VaultInsufficientPendingRedeemRequest.selector, carol, 8, 9
            )
        );
        harness.movePendingRedeemToClaimable(carol, 9);

        harness.movePendingRedeemToClaimable(carol, 8);

        VM.expectRevert(
            abi.encodeWithSelector(
                LibERC7540RequestAccounting.ERC7540VaultInsufficientClaimableRedeemRequest.selector, carol, 8, 9
            )
        );
        harness.consumeClaimableRedeem(carol, 9);
    }

    function testSetOperatorTracksApprovalAndRevocation() public {
        VM.prank(bob);
        bool approved = harness.setOperator(eve, true);

        assertTrue(approved, "setOperator should return true");
        assertTrue(harness.isOperator(bob, eve), "operator should be approved");

        VM.prank(bob);
        harness.setOperator(eve, false);

        assertFalse(harness.isOperator(bob, eve), "operator should be revoked");
    }

    function testSetOperatorRevertsOnZeroOperator() public {
        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(LibERC7540RequestAccounting.ERC7540VaultZeroOperator.selector));
        harness.setOperator(address(0), true);
    }

    function _assertContains(bytes4[] memory selectors, bytes4 target) internal pure {
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] == target) {
                return;
            }
        }
        revert("missing selector");
    }

    function _assertUnique(bytes4[] memory selectors) internal pure {
        for (uint256 i = 0; i < selectors.length; i++) {
            for (uint256 j = i + 1; j < selectors.length; j++) {
                if (selectors[i] == selectors[j]) {
                    revert("duplicate selector");
                }
            }
        }
    }

    function _assertDisjoint(bytes4[] memory left, bytes4[] memory right) internal pure {
        for (uint256 i = 0; i < left.length; i++) {
            for (uint256 j = 0; j < right.length; j++) {
                if (left[i] == right[j]) {
                    revert("selector overlap");
                }
            }
        }
    }
}
