// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../src/interfaces/IERC7540Operators.sol";
import {IERC7540Redeem} from "../src/interfaces/IERC7540Redeem.sol";
import {IERC7540VaultSettlementFacet} from "../src/interfaces/IERC7540VaultSettlementFacet.sol";
import {ERC7540VaultRedeemFacet} from "../src/vault/facets/ERC7540VaultRedeemFacet.sol";
import {ERC4626VaultFacetFixture} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultRedeemFuzzTest is ERC4626VaultFacetFixture {
    function setUp() public override {
        super.setUp();
        _installHostedVaultFullyAsyncFacetsToDiamond();

        VM.prank(admin);
        _initializeHostedVault(address(diamond));
    }

    function testFuzzRequestRedeemEscrowsSharesForControllerOnly(
        uint8 controllerSeed,
        uint96 seedRaw,
        uint96 sharesRaw
    ) public {
        address controller = _controller(controllerSeed);
        address unrelated = _otherController(controller);
        uint256 seedAssets = _boundedAmount(seedRaw, 10_000);
        uint256 shares = _boundedAmount(sharesRaw, seedAssets);

        _seedClaimedShares(controller, seedAssets);

        VM.prank(controller);
        uint256 requestId = IERC7540Redeem(address(diamond)).requestRedeem(shares, controller, controller);

        assertTrue(requestId == 0, "request id mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, controller) == shares, "pending mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, controller) == 0, "claimable mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, unrelated) == 0, "unrelated pending");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, unrelated) == 0, "unrelated claimable");
        assertTrue(
            IERC4626(address(diamond)).balanceOf(controller) == seedAssets - shares, "controller shares mismatch"
        );
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == shares, "escrow shares mismatch");
        assertTrue(IERC4626(address(diamond)).totalSupply() == seedAssets, "supply should not change on request");
    }

    function testFuzzSettleAndClaimRedeemConsumeClaimableOnly(
        uint8 controllerSeed,
        uint8 receiverSeed,
        uint96 seedRaw,
        uint96 requestRaw,
        uint96 settleRaw,
        uint96 claimRaw
    ) public {
        address controller = _controller(controllerSeed);
        address receiver = _controller(receiverSeed);
        address unrelated = _otherController(controller);
        uint256 seedAssets = _boundedAmount(seedRaw, 10_000);
        uint256 requestShares = _boundedAmount(requestRaw, seedAssets);
        uint256 settleShares = _boundedAmount(settleRaw, requestShares);
        uint256 claimShares = _boundedAmount(claimRaw, settleShares);

        _seedClaimedShares(controller, seedAssets);

        VM.prank(controller);
        IERC7540Redeem(address(diamond)).requestRedeem(requestShares, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(controller, settleShares);

        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        VM.prank(controller);
        uint256 assets = IERC4626(address(diamond)).redeem(claimShares, receiver, controller);

        assertTrue(assets == claimShares, "redeem claim assets mismatch");
        assertTrue(
            IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, controller) == requestShares - settleShares,
            "pending mismatch"
        );
        assertTrue(
            IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, controller) == settleShares - claimShares,
            "claimable mismatch"
        );
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, unrelated) == 0, "unrelated pending");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, unrelated) == 0, "unrelated claimable");
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == requestShares - claimShares, "escrow");
        assertTrue(asset.balanceOf(receiver) == receiverAssetsBefore + assets, "receiver assets mismatch");
    }

    function testFuzzRedeemMaxHelpersTrackClaimableShares(
        uint8 controllerSeed,
        uint96 seedRaw,
        uint96 requestRaw,
        uint96 settleRaw
    ) public {
        address controller = _controller(controllerSeed);
        uint256 seedAssets = _boundedAmount(seedRaw, 10_000);
        uint256 requestShares = _boundedAmount(requestRaw, seedAssets);
        uint256 settleShares = _boundedAmount(settleRaw, requestShares);

        _seedClaimedShares(controller, seedAssets);

        VM.prank(controller);
        IERC7540Redeem(address(diamond)).requestRedeem(requestShares, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(controller, settleShares);

        assertTrue(IERC4626(address(diamond)).maxRedeem(controller) == settleShares, "maxRedeem mismatch");
        assertTrue(IERC4626(address(diamond)).maxWithdraw(controller) == settleShares, "maxWithdraw mismatch");
    }

    function testFuzzAllowanceHolderCanRequestRedeemAndOperatorCanClaim(
        uint8 controllerSeed,
        uint8 receiverSeed,
        uint96 seedRaw,
        uint96 requestRaw,
        uint96 settleRaw,
        uint96 claimRaw
    ) public {
        address controller = _controller(controllerSeed);
        address operator = _otherController(controller);
        address receiver = _controller(receiverSeed);
        uint256 seedAssets = _boundedAmount(seedRaw, 10_000);
        uint256 requestShares = _boundedAmount(requestRaw, seedAssets);
        uint256 settleShares = _boundedAmount(settleRaw, requestShares);
        uint256 claimShares = _boundedAmount(claimRaw, settleShares);

        _seedClaimedShares(controller, seedAssets);

        VM.prank(controller);
        IERC4626(address(diamond)).approve(operator, requestShares);

        VM.prank(operator);
        IERC7540Redeem(address(diamond)).requestRedeem(requestShares, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(controller, settleShares);

        VM.prank(controller);
        IERC7540Operators(address(diamond)).setOperator(operator, true);

        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        VM.prank(operator);
        uint256 assets = IERC4626(address(diamond)).redeem(claimShares, receiver, controller);

        assertTrue(assets == claimShares, "operator claim assets mismatch");
        assertTrue(asset.balanceOf(receiver) == receiverAssetsBefore + assets, "receiver assets mismatch");
        assertTrue(
            IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, controller) == settleShares - claimShares,
            "remaining claimable mismatch"
        );
    }

    function testFuzzUnauthorizedRedeemRequestAndClaimRevert(uint8 controllerSeed, uint96 seedRaw, uint96 sharesRaw)
        public
    {
        address controller = _controller(controllerSeed);
        address unauthorized = _otherController(controller);
        uint256 seedAssets = _boundedAmount(seedRaw, 10_000);
        uint256 shares = _boundedAmount(sharesRaw, seedAssets);

        _seedClaimedShares(controller, seedAssets);

        VM.prank(unauthorized);
        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultBase.ERC4626VaultInsufficientAllowance.selector, controller, unauthorized, 0, shares
            )
        );
        IERC7540Redeem(address(diamond)).requestRedeem(shares, controller, controller);

        VM.prank(controller);
        IERC7540Redeem(address(diamond)).requestRedeem(shares, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(controller, shares);

        VM.prank(unauthorized);
        VM.expectRevert(
            abi.encodeWithSelector(
                ERC7540VaultRedeemFacet.ERC7540VaultUnauthorizedOperator.selector, controller, unauthorized
            )
        );
        IERC4626(address(diamond)).redeem(shares, unauthorized, controller);
    }

    function _seedClaimedShares(address controller, uint256 assets) internal {
        _approveAsset(controller, address(diamond), assets);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, assets);

        VM.prank(controller);
        IERC4626(address(diamond)).deposit(assets, controller);
    }

    function _controller(uint8 seed) internal view returns (address) {
        return seed % 2 == 0 ? bob : eve;
    }

    function _otherController(address controller) internal view returns (address) {
        return controller == bob ? eve : bob;
    }

    function _boundedAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        return (raw % max) + 1;
    }
}
