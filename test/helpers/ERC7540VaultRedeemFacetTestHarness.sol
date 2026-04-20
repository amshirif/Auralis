// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC7540VaultRedeemFacet} from "../../src/vault/facets/ERC7540VaultRedeemFacet.sol";
import {LibERC7540RequestAccounting} from "../../src/vault/libraries/LibERC7540RequestAccounting.sol";

contract ERC7540VaultRedeemFacetHarness is ERC7540VaultRedeemFacet {
    function harnessSettleRedeemRequest(address controller, uint256 shares) external {
        LibERC7540RequestAccounting.movePendingRedeemToClaimable(controller, shares);
    }
}
