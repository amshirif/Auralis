// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../src/interfaces/IERC7540Operators.sol";
import {IERC7540VaultSettlementFacet} from "../src/interfaces/IERC7540VaultSettlementFacet.sol";
import {ERC7540VaultDepositFacet} from "../src/vault/facets/ERC7540VaultDepositFacet.sol";
import {ERC4626VaultFacetFixture} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultDepositFuzzTest is ERC4626VaultFacetFixture {
    function setUp() public override {
        super.setUp();
        _installHostedVaultAsyncDepositFacetsToDiamond();

        VM.prank(admin);
        _initializeHostedVault(address(diamond));
    }

    function testFuzzRequestDepositTracksOnlyControllerBucket(uint8 controllerSeed, uint96 assetsRaw) public {
        address controller = _controller(controllerSeed);
        address unrelated = _otherController(controller);
        uint256 assets = _boundedAmount(assetsRaw, 10_000);

        _approveAsset(controller, address(diamond), assets);

        VM.prank(controller);
        uint256 requestId = IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);

        assertTrue(requestId == 0, "request id mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, controller) == assets, "pending mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, controller) == 0, "claimable mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, unrelated) == 0, "unrelated pending");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, unrelated) == 0, "unrelated claimable");
        assertTrue(asset.balanceOf(address(diamond)) == assets, "raw vault balance mismatch");
        assertTrue(IERC4626(address(diamond)).totalAssets() == 0, "managed assets should not change on request");
    }

    function testFuzzSettleAndClaimDepositConsumeClaimableOnly(
        uint8 controllerSeed,
        uint8 receiverSeed,
        uint96 requestRaw,
        uint96 settleRaw,
        uint96 claimRaw
    ) public {
        address controller = _controller(controllerSeed);
        address receiver = _controller(receiverSeed);
        address unrelated = _otherController(controller);
        uint256 requestAssets = _boundedAmount(requestRaw, 10_000);
        uint256 settleAssets = _boundedAmount(settleRaw, requestAssets);
        uint256 claimAssets = _boundedAmount(claimRaw, settleAssets);

        _approveAsset(controller, address(diamond), requestAssets);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(requestAssets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, settleAssets);

        VM.prank(controller);
        uint256 shares = IERC4626(address(diamond)).deposit(claimAssets, receiver);

        assertTrue(shares == claimAssets, "claim shares mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).pendingDepositRequest(0, controller) == requestAssets - settleAssets,
            "pending mismatch"
        );
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, controller) == settleAssets - claimAssets,
            "claimable mismatch"
        );
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, unrelated) == 0, "unrelated pending");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, unrelated) == 0, "unrelated claimable");
        assertTrue(IERC4626(address(diamond)).balanceOf(receiver) == shares, "receiver shares mismatch");
        assertTrue(IERC4626(address(diamond)).totalAssets() == claimAssets, "managed assets mismatch");
    }

    function testFuzzDepositMaxHelpersTrackClaimableBalance(uint8 controllerSeed, uint96 requestRaw, uint96 settleRaw)
        public
    {
        address controller = _controller(controllerSeed);
        uint256 requestAssets = _boundedAmount(requestRaw, 10_000);
        uint256 settleAssets = _boundedAmount(settleRaw, requestAssets);

        _approveAsset(controller, address(diamond), requestAssets);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(requestAssets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, settleAssets);

        VM.prank(controller);
        uint256 maxDeposit = IERC4626(address(diamond)).maxDeposit(controller);
        VM.prank(controller);
        uint256 maxMint = IERC4626(address(diamond)).maxMint(controller);

        assertTrue(maxDeposit == settleAssets, "maxDeposit should match claimable assets");
        assertTrue(maxMint == settleAssets, "maxMint should match claimable assets at book price");
    }

    function testFuzzApprovedOperatorCanRequestAndClaimDeposit(
        uint8 controllerSeed,
        uint8 receiverSeed,
        uint96 requestRaw,
        uint96 settleRaw,
        uint96 claimRaw
    ) public {
        address controller = _controller(controllerSeed);
        address operator = _otherController(controller);
        address receiver = _controller(receiverSeed);
        uint256 requestAssets = _boundedAmount(requestRaw, 10_000);
        uint256 settleAssets = _boundedAmount(settleRaw, requestAssets);
        uint256 claimAssets = _boundedAmount(claimRaw, settleAssets);

        _approveAsset(controller, address(diamond), requestAssets);

        VM.prank(controller);
        IERC7540Operators(address(diamond)).setOperator(operator, true);

        VM.prank(operator);
        IERC7540Deposit(address(diamond)).requestDeposit(requestAssets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, settleAssets);

        VM.prank(operator);
        uint256 shares = IERC7540Deposit(address(diamond)).deposit(claimAssets, receiver, controller);

        assertTrue(shares == claimAssets, "operator claim shares mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, controller) == settleAssets - claimAssets,
            "remaining claimable mismatch"
        );
        assertTrue(IERC4626(address(diamond)).balanceOf(receiver) == shares, "receiver shares mismatch");
    }

    function testFuzzUnauthorizedOperatorCannotRequestOrClaimDeposit(uint8 controllerSeed, uint96 assetsRaw) public {
        address controller = _controller(controllerSeed);
        address unauthorized = _otherController(controller);
        uint256 assets = _boundedAmount(assetsRaw, 10_000);

        _approveAsset(controller, address(diamond), assets);

        VM.prank(unauthorized);
        VM.expectRevert(
            abi.encodeWithSelector(
                ERC7540VaultDepositFacet.ERC7540VaultUnauthorizedOperator.selector, controller, unauthorized
            )
        );
        IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, assets);

        VM.prank(unauthorized);
        VM.expectRevert(
            abi.encodeWithSelector(
                ERC7540VaultDepositFacet.ERC7540VaultUnauthorizedOperator.selector, controller, unauthorized
            )
        );
        IERC7540Deposit(address(diamond)).deposit(assets, unauthorized, controller);
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
