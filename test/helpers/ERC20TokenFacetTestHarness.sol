// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IAccessControl} from "../../src/interfaces/IAccessControl.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {IERC20TokenBase} from "../../src/interfaces/IERC20TokenBase.sol";
import {IERC20TokenFacet} from "../../src/interfaces/IERC20TokenFacet.sol";
import {IPausable} from "../../src/interfaces/IPausable.sol";
import {ERC20TokenFacet} from "../../src/token/facets/ERC20TokenFacet.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract ERC20TokenFacetFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ERC20TokenFacet internal facet;
    DiamondCutFacet internal cutFacet;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        facet = new ERC20TokenFacet();
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
    }

    function _erc20Init(address target) internal {
        IERC20TokenFacet(target).initializeErc20("Facet Token", "FTKN", 18, admin);
    }

    function _addErc20FacetToDiamond() internal {
        bytes4[] memory selectors = new bytes4[](26);
        selectors[0] = IERC20TokenFacet.initializeErc20.selector;
        selectors[1] = IERC20Metadata.name.selector;
        selectors[2] = IERC20Metadata.symbol.selector;
        selectors[3] = IERC20Metadata.decimals.selector;
        selectors[4] = IERC20.totalSupply.selector;
        selectors[5] = IERC20.balanceOf.selector;
        selectors[6] = IERC20.allowance.selector;
        selectors[7] = IERC20.transfer.selector;
        selectors[8] = IERC20.approve.selector;
        selectors[9] = IERC20.transferFrom.selector;
        selectors[10] = IERC20TokenFacet.mint.selector;
        selectors[11] = IERC20TokenFacet.burn.selector;
        selectors[12] = IERC20TokenBase.isErc20Initialized.selector;
        selectors[13] = IAccessControl.DEFAULT_ADMIN_ROLE.selector;
        selectors[14] = IPausable.PAUSER_ROLE.selector;
        selectors[15] = IERC20TokenFacet.TOKEN_ADMIN_ROLE.selector;
        selectors[16] = IERC20TokenFacet.ERC20_MINTER_ROLE.selector;
        selectors[17] = IERC20TokenFacet.ERC20_BURNER_ROLE.selector;
        selectors[18] = IERC20TokenFacet.ERC20_TRANSFER_SCOPE.selector;
        selectors[19] = IERC20TokenFacet.ERC20_APPROVAL_SCOPE.selector;
        selectors[20] = IAccessControl.hasRole.selector;
        selectors[21] = IAccessControl.getRoleAdmin.selector;
        selectors[22] = IAccessControl.grantRole.selector;
        selectors[23] = IPausable.pauseScope.selector;
        selectors[24] = IPausable.unpauseScope.selector;
        selectors[25] = IPausable.scopePaused.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}
