// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IERC20Permit} from "../src/interfaces/IERC20Permit.sol";
import {IERC20TokenBase} from "../src/interfaces/IERC20TokenBase.sol";
import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {LibERC20TokenStorage} from "../src/token/storage/LibERC20TokenStorage.sol";
import {ERC20TokenFacetFixture} from "./helpers/ERC20TokenFacetTestHarness.sol";

contract ERC20TokenFacetCoreTest is ERC20TokenFacetFixture {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function testInitializeSeedsMetadataAndSharedRoles() public {
        _erc20Init(address(facet));

        assertTrue(IERC20TokenFacet(address(facet)).isErc20Initialized(), "facet should initialize");
        assertTrue(
            keccak256(bytes(IERC20TokenFacet(address(facet)).name())) == keccak256(bytes("Facet Token")),
            "name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC20TokenFacet(address(facet)).symbol())) == keccak256(bytes("FTKN")), "symbol mismatch"
        );
        assertTrue(IERC20TokenFacet(address(facet)).decimals() == 18, "decimals mismatch");
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).DEFAULT_ADMIN_ROLE(), admin),
            "admin should have default admin role"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(), admin),
            "admin should have token admin role"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).ERC20_MINTER_ROLE(), admin),
            "admin should have minter role"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).ERC20_BURNER_ROLE(), admin),
            "admin should have burner role"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).PAUSER_ROLE(), admin),
            "admin should have pauser role"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).getRoleAdmin(IERC20TokenFacet(address(facet)).ERC20_MINTER_ROLE())
                == IERC20TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(),
            "minter admin mismatch"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).getRoleAdmin(IERC20TokenFacet(address(facet)).ERC20_BURNER_ROLE())
                == IERC20TokenFacet(address(facet)).TOKEN_ADMIN_ROLE(),
            "burner admin mismatch"
        );
    }

    function testStandaloneFacetInitializationRemainsAvailableWithoutDiamondOwner() public {
        _erc20Init(address(facet));

        assertTrue(IERC20TokenFacet(address(facet)).isErc20Initialized(), "standalone facet should initialize");
        assertTrue(
            IERC20TokenFacet(address(facet)).hasRole(IERC20TokenFacet(address(facet)).DEFAULT_ADMIN_ROLE(), admin),
            "standalone facet should seed admin role"
        );
    }

    function testInitializeRevertsWhenCalledTwice() public {
        _erc20Init(address(facet));

        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenAlreadyInitialized.selector));
        _erc20Init(address(facet));
    }

    function testMintBurnTransferAndApprovalFlows() public {
        _erc20Init(address(facet));

        VM.expectEmit(true, true, false, true, address(facet));
        emit Transfer(address(0), bob, 100);
        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, 100);

        VM.expectEmit(true, true, false, true, address(facet));
        emit Approval(bob, eve, 45);
        VM.prank(bob);
        IERC20TokenFacet(address(facet)).approve(eve, 45);

        VM.expectEmit(true, true, false, true, address(facet));
        emit Transfer(bob, admin, 10);
        VM.prank(bob);
        IERC20TokenFacet(address(facet)).transfer(admin, 10);

        VM.expectEmit(true, true, false, true, address(facet));
        emit Approval(bob, eve, 20);
        VM.prank(eve);
        IERC20TokenFacet(address(facet)).transferFrom(bob, admin, 25);

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).burn(bob, 20);

        assertTrue(IERC20TokenFacet(address(facet)).totalSupply() == 80, "total supply mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).balanceOf(bob) == 45, "bob balance mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).balanceOf(admin) == 35, "admin balance mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).allowance(bob, eve) == 20, "allowance mismatch");
    }

    function testUnauthorizedMintAndBurnRevert() public {
        _erc20Init(address(facet));

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC20TokenFacet(address(facet)).ERC20_MINTER_ROLE()
            )
        );
        IERC20TokenFacet(address(facet)).mint(bob, 1);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector,
                bob,
                IERC20TokenFacet(address(facet)).ERC20_BURNER_ROLE()
            )
        );
        IERC20TokenFacet(address(facet)).burn(admin, 1);
        VM.stopPrank();
    }

    function testTransferScopePauseBlocksTransferAndMintBurn() public {
        _erc20Init(address(facet));
        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, 50);
        VM.startPrank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(transferScope);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).transfer(admin, 1);
        VM.stopPrank();

        VM.startPrank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).mint(bob, 1);
        VM.stopPrank();

        VM.startPrank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).burn(bob, 1);
        VM.stopPrank();
    }

    function testApprovalScopePauseBlocksApproveAndTransferFrom() public {
        _erc20Init(address(facet));
        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, 50);
        VM.startPrank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(approvalScope);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC20TokenFacet(address(facet)).approve(eve, 1);
        VM.stopPrank();

        VM.startPrank(admin);
        IERC20TokenFacet(address(facet)).unpauseScope(approvalScope);
        VM.stopPrank();

        VM.prank(bob);
        IERC20TokenFacet(address(facet)).approve(eve, 10);

        VM.startPrank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(approvalScope);
        VM.stopPrank();

        VM.startPrank(eve);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC20TokenFacet(address(facet)).transferFrom(bob, admin, 1);
        VM.stopPrank();
    }

    function testSupportsFacetAndControlInterfaces() public {
        _erc20Init(address(facet));

        assertTrue(IERC20TokenFacet(address(facet)).supportsInterface(type(IERC165).interfaceId), "erc165 unsupported");
        assertTrue(
            IERC20TokenFacet(address(facet)).supportsInterface(type(IAccessControl).interfaceId),
            "access control unsupported"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).supportsInterface(type(IPausable).interfaceId), "pausable unsupported"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).supportsInterface(type(IERC20Permit).interfaceId), "permit unsupported"
        );
        assertTrue(
            IERC20TokenFacet(address(facet)).supportsInterface(type(IERC20TokenFacet).interfaceId),
            "facet interface unsupported"
        );
    }

    function testDiamondRoutingAndInitWorkThroughFallback() public {
        _addErc20FacetToDiamond();
        bytes32 transferScope = IERC20TokenFacet(address(diamond)).ERC20_TRANSFER_SCOPE();

        VM.prank(admin);
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);

        assertTrue(IERC20TokenFacet(address(diamond)).isErc20Initialized(), "diamond erc20 should initialize");
        assertTrue(
            keccak256(bytes(IERC20TokenFacet(address(diamond)).name())) == keccak256(bytes("Facet Token")),
            "diamond name mismatch"
        );

        VM.prank(admin);
        IERC20TokenFacet(address(diamond)).mint(bob, 120);

        VM.prank(bob);
        IERC20TokenFacet(address(diamond)).approve(eve, 50);

        VM.prank(eve);
        IERC20TokenFacet(address(diamond)).transferFrom(bob, admin, 20);

        assertTrue(IERC20TokenFacet(address(diamond)).balanceOf(bob) == 100, "diamond bob balance mismatch");
        assertTrue(IERC20TokenFacet(address(diamond)).balanceOf(admin) == 20, "diamond admin balance mismatch");
        assertTrue(IERC20TokenFacet(address(diamond)).allowance(bob, eve) == 30, "diamond allowance mismatch");
        assertTrue(
            IERC20TokenFacet(address(diamond)).hasRole(IERC20TokenFacet(address(diamond)).ERC20_MINTER_ROLE(), admin),
            "diamond admin should have minter role"
        );

        VM.startPrank(admin);
        IERC20TokenFacet(address(diamond)).pauseScope(transferScope);
        VM.stopPrank();

        VM.startPrank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(diamond)).transfer(admin, 1);
        VM.stopPrank();
    }

    function testDiamondReinitializeReverts() public {
        _addErc20FacetToDiamond();

        VM.prank(admin);
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenAlreadyInitialized.selector));
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);
    }

    function testPermitSetsAllowanceEmitsApprovalAndIncrementsNonce() public {
        _erc20Init(address(facet));
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, 55, 0, deadline);

        VM.expectEmit(true, true, false, true, address(facet));
        emit Approval(bob, eve, 55);
        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline, v, r, s);

        assertTrue(IERC20TokenFacet(address(facet)).allowance(bob, eve) == 55, "permit allowance mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).nonces(bob) == 1, "permit nonce mismatch");
    }

    function testPermitRevertsOnReplay() public {
        _erc20Init(address(facet));
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, 55, 0, deadline);

        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline, v, r, s);

        address replaySigner = _recoverPermitSigner(address(facet), bob, eve, 55, 1, deadline, v, r, s);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitInvalidSigner.selector, replaySigner, bob));
        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline, v, r, s);
    }

    function testPermitRevertsOnExpiredDeadline() public {
        _erc20Init(address(facet));
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, 55, 0, deadline);

        VM.warp(block.timestamp + 1);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitExpired.selector, deadline, block.timestamp));
        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline, v, r, s);
    }

    function testPermitRevertsOnWrongPayload() public {
        _erc20Init(address(facet));
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, 55, 0, deadline);

        address wrongSpenderSigner = _recoverPermitSigner(address(facet), bob, admin, 55, 0, deadline, v, r, s);
        VM.expectRevert(
            abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitInvalidSigner.selector, wrongSpenderSigner, bob)
        );
        IERC20TokenFacet(address(facet)).permit(bob, admin, 55, deadline, v, r, s);

        address wrongValueSigner = _recoverPermitSigner(address(facet), bob, eve, 54, 0, deadline, v, r, s);
        VM.expectRevert(
            abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitInvalidSigner.selector, wrongValueSigner, bob)
        );
        IERC20TokenFacet(address(facet)).permit(bob, eve, 54, deadline, v, r, s);

        address wrongDeadlineSigner = _recoverPermitSigner(address(facet), bob, eve, 55, 0, deadline + 1, v, r, s);
        VM.expectRevert(
            abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitInvalidSigner.selector, wrongDeadlineSigner, bob)
        );
        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline + 1, v, r, s);
    }

    function testDomainSeparatorMatchesInitializedContext() public {
        _erc20Init(address(facet));

        bytes32 expectedSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Facet Token")),
                keccak256(bytes("1")),
                block.chainid,
                address(facet)
            )
        );

        assertTrue(
            IERC20TokenFacet(address(facet)).DOMAIN_SEPARATOR() == expectedSeparator, "domain separator mismatch"
        );
    }

    function testErc20PermitStorageLayoutRemainsFrozen() public {
        _erc20Init(address(facet));

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, 100);

        VM.prank(bob);
        IERC20TokenFacet(address(facet)).approve(eve, 45);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, dave, 77, 0, deadline);
        IERC20TokenFacet(address(facet)).permit(bob, dave, 77, deadline, v, r, s);

        bytes32 baseSlot = LibERC20TokenStorage.STORAGE_SLOT;
        assertTrue(baseSlot == keccak256("auralis.token.erc20.storage"), "erc20 storage slot mismatch");
        assertTrue(
            VM.load(address(facet), bytes32(uint256(baseSlot) + 3)) == keccak256(bytes("Facet Token")),
            "erc20 hashed name slot mismatch"
        );
        assertTrue(
            VM.load(address(facet), bytes32(uint256(baseSlot) + 5)) == bytes32(uint256(block.chainid)),
            "erc20 cached chain id slot mismatch"
        );
        assertTrue(
            VM.load(address(facet), bytes32(uint256(baseSlot) + 6))
                == IERC20TokenFacet(address(facet)).DOMAIN_SEPARATOR(),
            "erc20 cached domain separator slot mismatch"
        );

        bytes32 balanceSlot = keccak256(abi.encode(bob, uint256(baseSlot) + 7));
        assertTrue(VM.load(address(facet), balanceSlot) == bytes32(uint256(100)), "erc20 facet balance slot mismatch");

        bytes32 allowanceOwnerBase = keccak256(abi.encode(bob, uint256(baseSlot) + 8));
        bytes32 approvalSlot = keccak256(abi.encode(eve, uint256(allowanceOwnerBase)));
        assertTrue(
            VM.load(address(facet), approvalSlot) == bytes32(uint256(45)), "erc20 approval allowance slot mismatch"
        );

        bytes32 permitAllowanceSlot = keccak256(abi.encode(dave, uint256(allowanceOwnerBase)));
        assertTrue(
            VM.load(address(facet), permitAllowanceSlot) == bytes32(uint256(77)), "erc20 permit allowance slot mismatch"
        );

        bytes32 nonceSlot = keccak256(abi.encode(bob, uint256(baseSlot) + 9));
        assertTrue(VM.load(address(facet), nonceSlot) == bytes32(uint256(1)), "erc20 nonce slot mismatch");
    }

    function testPermitRespectsApprovalPauseScope() public {
        _erc20Init(address(facet));
        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, 55, 0, deadline);

        VM.startPrank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(approvalScope);
        VM.stopPrank();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC20TokenFacet(address(facet)).permit(bob, eve, 55, deadline, v, r, s);
    }

    function testDiamondPermitWorksThroughFallback() public {
        _addErc20FacetToDiamond();

        VM.prank(admin);
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(diamond), bob, eve, 77, 0, deadline);

        IERC20TokenFacet(address(diamond)).permit(bob, eve, 77, deadline, v, r, s);

        assertTrue(IERC20TokenFacet(address(diamond)).allowance(bob, eve) == 77, "diamond permit allowance mismatch");
        assertTrue(IERC20TokenFacet(address(diamond)).nonces(bob) == 1, "diamond permit nonce mismatch");
    }
}
