// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC7540VaultDepositFacet} from "../../src/vault/facets/ERC7540VaultDepositFacet.sol";
import {LibERC7540RequestAccounting} from "../../src/vault/libraries/LibERC7540RequestAccounting.sol";

contract ERC7540VaultDepositFacetHarness is ERC7540VaultDepositFacet {
    function harnessSettleDepositRequest(address controller, uint256 assets) external {
        LibERC7540RequestAccounting.movePendingDepositToClaimable(controller, assets);
    }
}
