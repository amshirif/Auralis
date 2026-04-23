// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC721} from "../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../src/interfaces/IERC721Metadata.sol";
import {IERC721TokenBase} from "../src/interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../src/interfaces/IERC721TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC721TokenFacetFixture} from "./helpers/ERC721TokenFacetTestHarness.sol";

contract ERC721TokenFacetCoreTest is ERC721TokenFacetFixture {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function testInitializeSeedsMetadataAndSharedRoles() public {
        _erc721Init(address(facet));

        assertTrue(IERC721TokenFacet(address(facet)).isErc721Initialized(), "facet should initialize");
        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(facet)).name())) == keccak256(bytes("Facet NFT")), "name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(facet)).symbol())) == keccak256(bytes("FNFT")), "symbol mismatch"
        );
        assertTrue(IERC721TokenFacet(address(facet)).totalSupply() == 0, "initial supply mismatch");
    }

    function testStandaloneFacetInitializationRemainsAvailableWithoutDiamondOwner() public {
        _erc721Init(address(facet));

        assertTrue(IERC721TokenFacet(address(facet)).isErc721Initialized(), "standalone facet should initialize");
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).DEFAULT_ADMIN_ROLE(), admin),
            "standalone facet should seed admin role"
        );
    }

    function testInitializeSeedsRoleHierarchyAndBaseUri() public {
        _erc721Init(address(facet));
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(admin, 1);

        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(facet)).tokenURI(1))) == keccak256(bytes("ipfs://facet/1")),
            "base uri mismatch"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).DEFAULT_ADMIN_ROLE(), admin),
            "admin should have default admin role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(), admin),
            "admin should have token admin role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).ERC721_MINTER_ROLE(), admin),
            "admin should have minter role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).ERC721_BURNER_ROLE(), admin),
            "admin should have burner role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).ERC721_METADATA_ROLE(), admin),
            "admin should have metadata role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).hasRole(IERC721TokenFacet(address(facet)).PAUSER_ROLE(), admin),
            "admin should have pauser role"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).getRoleAdmin(IERC721TokenFacet(address(facet)).TOKEN_ADMIN_ROLE())
                == IERC721TokenFacet(address(facet)).DEFAULT_ADMIN_ROLE(),
            "token admin admin mismatch"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).getRoleAdmin(IERC721TokenFacet(address(facet)).ERC721_MINTER_ROLE())
                == IERC721TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(),
            "minter admin mismatch"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).getRoleAdmin(IERC721TokenFacet(address(facet)).ERC721_BURNER_ROLE())
                == IERC721TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(),
            "burner admin mismatch"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).getRoleAdmin(IERC721TokenFacet(address(facet)).ERC721_METADATA_ROLE())
                == IERC721TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(),
            "metadata admin mismatch"
        );
    }

    function testInitializeRevertsWhenCalledTwice() public {
        _erc721Init(address(facet));

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenAlreadyInitialized.selector));
        _erc721Init(address(facet));
    }

    function testMintBurnTransferAndMetadataFlows() public {
        _erc721Init(address(facet));

        VM.expectEmit(true, true, true, true, address(facet));
        emit Transfer(address(0), bob, 1);
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(bob, 1);

        VM.expectEmit(true, true, true, true, address(facet));
        emit Approval(bob, eve, 1);
        VM.prank(bob);
        IERC721TokenFacet(address(facet)).approve(eve, 1);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).setTokenURI(1, "ipfs://facet/custom-1");

        VM.expectEmit(true, true, true, true, address(facet));
        emit Transfer(bob, admin, 1);
        VM.prank(eve);
        IERC721TokenFacet(address(facet)).transferFrom(bob, admin, 1);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).setBaseURI("https://example.com/meta/");

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).burn(1);

        assertTrue(IERC721TokenFacet(address(facet)).totalSupply() == 0, "total supply mismatch");
        assertTrue(IERC721TokenFacet(address(facet)).balanceOf(bob) == 0, "bob balance mismatch");
        assertTrue(IERC721TokenFacet(address(facet)).balanceOf(admin) == 0, "admin balance mismatch");
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenNonexistentToken.selector, 1));
        IERC721TokenFacet(address(facet)).ownerOf(1);
    }

    function testTokenUriPrefersExplicitUriAndClearsApprovalOnTransfer() public {
        _erc721Init(address(facet));

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(bob, 7);
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).setTokenURI(7, "ipfs://facet/custom-7");

        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(facet)).tokenURI(7)))
                == keccak256(bytes("ipfs://facet/custom-7")),
            "explicit token uri mismatch"
        );

        VM.prank(bob);
        IERC721TokenFacet(address(facet)).approve(eve, 7);

        VM.prank(eve);
        IERC721TokenFacet(address(facet)).transferFrom(bob, admin, 7);

        assertTrue(IERC721TokenFacet(address(facet)).getApproved(7) == address(0), "approval should clear");
    }

    function testSafeTransferAndSafeMintHandleReceivers() public {
        _erc721Init(address(facet));
        bytes memory payload = hex"1234";

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).safeMint(address(receiver), 1, payload);

        assertTrue(IERC721TokenFacet(address(facet)).ownerOf(1) == address(receiver), "receiver should own token");
        assertTrue(receiver.lastOperator() == admin, "safe mint operator mismatch");
        assertTrue(receiver.lastFrom() == address(0), "safe mint from mismatch");
        assertTrue(receiver.lastTokenId() == 1, "safe mint token id mismatch");
        assertTrue(keccak256(receiver.lastData()) == keccak256(payload), "safe mint data mismatch");

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(admin, 2);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).safeTransferFrom(admin, address(receiver), 2, payload);

        assertTrue(IERC721TokenFacet(address(facet)).ownerOf(2) == address(receiver), "safe transfer owner mismatch");

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(admin, 3);
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenUnsafeReceiver.selector, address(rejector)));
        IERC721TokenFacet(address(facet)).safeTransferFrom(admin, address(rejector), 3);
    }

    function testApproveAndTransferRequireAuthorizedOperator() public {
        _erc721Init(address(facet));
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(bob, 1);

        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenFacet.ERC721TokenUnauthorizedOperator.selector, eve, 1));
        IERC721TokenFacet(address(facet)).approve(admin, 1);

        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenFacet.ERC721TokenUnauthorizedOperator.selector, eve, 1));
        IERC721TokenFacet(address(facet)).transferFrom(bob, admin, 1);

        VM.prank(bob);
        IERC721TokenFacet(address(facet)).setApprovalForAll(eve, true);
        VM.prank(eve);
        IERC721TokenFacet(address(facet)).transferFrom(bob, admin, 1);

        assertTrue(IERC721TokenFacet(address(facet)).ownerOf(1) == admin, "operator transfer should succeed");
    }

    function testUnauthorizedMintBurnAndMetadataUpdatesRevert() public {
        _erc721Init(address(facet));
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(admin, 1);

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC721TokenFacet(address(facet)).ERC721_MINTER_ROLE()
            )
        );
        IERC721TokenFacet(address(facet)).mint(bob, 2);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC721TokenFacet(address(facet)).ERC721_BURNER_ROLE()
            )
        );
        IERC721TokenFacet(address(facet)).burn(1);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC721TokenFacet(address(facet)).ERC721_METADATA_ROLE()
            )
        );
        IERC721TokenFacet(address(facet)).setBaseURI("ipfs://other/");
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC721TokenFacet(address(facet)).ERC721_METADATA_ROLE()
            )
        );
        IERC721TokenFacet(address(facet)).setTokenURI(1, "ipfs://other/1");
        VM.stopPrank();
    }

    function testPauseScopesBlockOnlyTheirIntendedPaths() public {
        _erc721Init(address(facet));
        bytes32 approvalScope = IERC721TokenFacet(address(facet)).ERC721_APPROVAL_SCOPE();
        bytes32 transferScope = IERC721TokenFacet(address(facet)).ERC721_TRANSFER_SCOPE();

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).mint(bob, 1);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).pauseScope(approvalScope);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC721TokenFacet(address(facet)).approve(eve, 1);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC721TokenFacet(address(facet)).setApprovalForAll(eve, true);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).pauseScope(transferScope);

        VM.prank(admin);
        IERC721TokenFacet(address(facet)).setBaseURI("https://example.com/meta/");
        VM.prank(admin);
        IERC721TokenFacet(address(facet)).setTokenURI(1, "https://example.com/meta/custom-1");

        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(facet)).tokenURI(1)))
                == keccak256(bytes("https://example.com/meta/custom-1")),
            "metadata updates should remain available"
        );

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).transferFrom(bob, admin, 1);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).safeTransferFrom(bob, admin, 1);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).safeTransferFrom(bob, admin, 1, "");

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).mint(bob, 2);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).safeMint(bob, 2, "");

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC721TokenFacet(address(facet)).burn(1);
    }

    function testSupportsFacetAndControlInterfaces() public {
        _erc721Init(address(facet));

        assertTrue(IERC721TokenFacet(address(facet)).supportsInterface(type(IERC165).interfaceId), "erc165 unsupported");
        assertTrue(IERC721TokenFacet(address(facet)).supportsInterface(type(IERC721).interfaceId), "erc721 unsupported");
        assertTrue(
            IERC721TokenFacet(address(facet)).supportsInterface(type(IERC721Metadata).interfaceId),
            "erc721 metadata unsupported"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).supportsInterface(type(IAccessControl).interfaceId),
            "access control unsupported"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).supportsInterface(type(IPausable).interfaceId), "pausable unsupported"
        );
        assertTrue(
            IERC721TokenFacet(address(facet)).supportsInterface(type(IERC721TokenFacet).interfaceId),
            "facet interface unsupported"
        );
    }

    function testDiamondRoutingAndInitWorkThroughFallback() public {
        _addErc721FacetToDiamond();

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).mint(bob, 1);

        VM.prank(bob);
        IERC721TokenFacet(address(diamond)).approve(eve, 1);

        VM.prank(eve);
        IERC721TokenFacet(address(diamond)).transferFrom(bob, admin, 1);

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).setApprovalForAll(eve, true);

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).safeMint(address(receiver), 2, hex"cafe");

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).mint(admin, 3);

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).safeTransferFrom(admin, address(receiver), 3);

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).setTokenURI(1, "ipfs://facet/custom-1");

        assertTrue(IERC721TokenFacet(address(diamond)).isErc721Initialized(), "diamond erc721 should initialize");
        assertTrue(IERC721TokenFacet(address(diamond)).ownerOf(1) == admin, "diamond owner mismatch");
        assertTrue(IERC721TokenFacet(address(diamond)).ownerOf(2) == address(receiver), "diamond safe mint mismatch");
        assertTrue(
            IERC721TokenFacet(address(diamond)).ownerOf(3) == address(receiver), "diamond safe transfer mismatch"
        );
        assertTrue(IERC721TokenFacet(address(diamond)).balanceOf(admin) == 1, "diamond admin balance mismatch");
        assertTrue(IERC721TokenFacet(address(diamond)).totalSupply() == 3, "diamond total supply mismatch");
        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(diamond)).tokenURI(1)))
                == keccak256(bytes("ipfs://facet/custom-1")),
            "diamond token uri mismatch"
        );
        assertTrue(
            IERC721TokenFacet(address(diamond))
                .hasRole(IERC721TokenFacet(address(diamond)).ERC721_METADATA_ROLE(), admin),
            "diamond metadata role missing"
        );
    }

    function testDiamondReinitializeReverts() public {
        _addErc721FacetToDiamond();

        VM.prank(admin);
        IERC721TokenFacet(address(diamond)).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenAlreadyInitialized.selector));
        IERC721TokenFacet(address(diamond)).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);
    }
}
