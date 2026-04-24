// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20TokenBase} from "../src/interfaces/IERC20TokenBase.sol";
import {IERC721} from "../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../src/interfaces/IERC721Metadata.sol";
import {IERC721TokenBase} from "../src/interfaces/IERC721TokenBase.sol";
import {LibERC20TokenStorage} from "../src/token/storage/LibERC20TokenStorage.sol";
import {TokenFacetFoundationFixture} from "./helpers/TokenFacetFoundationTestHarness.sol";

contract TokenFacetFoundationCoreTest is TokenFacetFoundationFixture {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function testStorageSlotsAndConstantsAreDistinct() public pure {
        assertTrue(erc20StorageSlot() != erc721StorageSlot(), "token storage slots should differ");
        assertTrue(tokenAdminRole() != erc20MinterRole(), "token roles should differ");
        assertTrue(erc20TransferScope() != erc721ApprovalScope(), "token pause scopes should differ");
    }

    function testErc20StorageSlotAndLayoutRemainFrozen() public {
        bytes32 baseSlot = LibERC20TokenStorage.STORAGE_SLOT;
        assertTrue(baseSlot == keccak256("auralis.token.erc20.storage"), "erc20 storage slot mismatch");

        erc20.initialize("Facet Token", "FTKN", 18);
        erc20.mint(admin, 100);
        erc20.approveTokens(admin, bob, 40);

        bytes32 packedSlot0 = VM.load(address(erc20), baseSlot);
        assertTrue(uint8(uint256(packedSlot0)) == 1, "erc20 initialized offset mismatch");
        // Decimals intentionally uses 18 here so a bool<uint8 field swap cannot pass accidentally.
        assertTrue(uint8(uint256(packedSlot0 >> 8)) == 18, "erc20 decimals offset mismatch");

        assertTrue(
            VM.load(address(erc20), bytes32(uint256(baseSlot) + 1)) == _shortStringSlot("Facet Token"),
            "erc20 name slot mismatch"
        );
        assertTrue(
            VM.load(address(erc20), bytes32(uint256(baseSlot) + 2)) == _shortStringSlot("FTKN"),
            "erc20 symbol slot mismatch"
        );
        assertTrue(
            VM.load(address(erc20), bytes32(uint256(baseSlot) + 4)) == bytes32(uint256(100)),
            "erc20 total supply slot mismatch"
        );

        bytes32 balanceSlot = keccak256(abi.encode(admin, uint256(baseSlot) + 7));
        assertTrue(VM.load(address(erc20), balanceSlot) == bytes32(uint256(100)), "erc20 balance slot mismatch");

        bytes32 allowanceOwnerBase = keccak256(abi.encode(admin, uint256(baseSlot) + 8));
        bytes32 allowanceSlot = keccak256(abi.encode(bob, uint256(allowanceOwnerBase)));
        assertTrue(VM.load(address(erc20), allowanceSlot) == bytes32(uint256(40)), "erc20 allowance slot mismatch");
    }

    function testErc20InitializerSetsMetadata() public {
        erc20.initialize("Facet Token", "FTKN", 18);

        assertTrue(erc20.isErc20Initialized(), "erc20 should initialize");
        assertTrue(keccak256(bytes(erc20.name())) == keccak256(bytes("Facet Token")), "erc20 name should initialize");
        assertTrue(keccak256(bytes(erc20.symbol())) == keccak256(bytes("FTKN")), "erc20 symbol should initialize");
        assertTrue(erc20.decimals() == 18, "erc20 decimals should initialize");
    }

    function testErc20InitializerRevertsWhenCalledTwice() public {
        erc20.initialize("Facet Token", "FTKN", 18);

        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenAlreadyInitialized.selector));
        erc20.initialize("Facet Token", "FTKN", 18);
    }

    function testErc20HelpersUpdateSupplyBalancesAndAllowance() public {
        erc20.initialize("Facet Token", "FTKN", 18);

        VM.expectEmit(true, true, false, true, address(erc20));
        emit Transfer(address(0), admin, 100);
        erc20.mint(admin, 100);

        VM.expectEmit(true, true, false, true, address(erc20));
        emit Approval(admin, bob, 40);
        erc20.approveTokens(admin, bob, 40);

        VM.expectEmit(true, true, false, true, address(erc20));
        emit Approval(admin, bob, 15);
        erc20.spendAllowance(admin, bob, 25);

        VM.expectEmit(true, true, false, true, address(erc20));
        emit Transfer(admin, eve, 55);
        erc20.transferTokens(admin, eve, 55);

        VM.expectEmit(true, true, false, true, address(erc20));
        emit Transfer(admin, address(0), 15);
        erc20.burn(admin, 15);

        assertTrue(erc20.totalSupply() == 85, "erc20 total supply mismatch");
        assertTrue(erc20.balanceOf(admin) == 30, "admin balance mismatch");
        assertTrue(erc20.balanceOf(eve) == 55, "eve balance mismatch");
        assertTrue(erc20.allowance(admin, bob) == 15, "allowance should decrement");
    }

    function testErc20InfiniteAllowanceDoesNotDecrement() public {
        erc20.initialize("Facet Token", "FTKN", 18);
        erc20.approveTokens(admin, bob, type(uint256).max);
        erc20.spendAllowance(admin, bob, 50);

        assertTrue(erc20.allowance(admin, bob) == type(uint256).max, "infinite allowance should remain unchanged");
    }

    function testErc20GuardsForUninitializedAndZeroAddress() public {
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenNotInitialized.selector));
        erc20.mint(admin, 1);

        erc20.initialize("Facet Token", "FTKN", 18);

        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenZeroAddress.selector));
        erc20.mint(address(0), 1);

        erc20.mint(admin, 10);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenInsufficientBalance.selector, admin, 10, 11));
        erc20.burn(admin, 11);
    }

    function testErc721InitializerSetsMetadataAndSupportsInterfaces() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");

        assertTrue(erc721.isErc721Initialized(), "erc721 should initialize");
        assertTrue(keccak256(bytes(erc721.name())) == keccak256(bytes("Facet NFT")), "erc721 name should initialize");
        assertTrue(keccak256(bytes(erc721.symbol())) == keccak256(bytes("FNFT")), "erc721 symbol should initialize");
        assertTrue(erc721.supportsInterface(type(IERC165).interfaceId), "erc165 should be supported");
        assertTrue(erc721.supportsInterface(type(IERC721).interfaceId), "erc721 should be supported");
        assertTrue(erc721.supportsInterface(type(IERC721Metadata).interfaceId), "erc721 metadata should be supported");
        assertFalse(erc721.supportsInterface(0xffffffff), "unexpected interface support");
    }

    function testErc721InitializerRevertsWhenCalledTwice() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenAlreadyInitialized.selector));
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");
    }

    function testErc721HelpersUpdateOwnershipApprovalsAndMetadata() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");

        erc721.mint(admin, 1);

        erc721.approveToken(bob, 1);

        VM.expectEmit(true, true, false, true, address(erc721));
        emit ApprovalForAll(admin, eve, true);
        erc721.setApprovalForAll(admin, eve, true);

        erc721.setTokenURI(1, "ipfs://facet/custom-1");
        assertTrue(
            keccak256(bytes(erc721.tokenURI(1))) == keccak256(bytes("ipfs://facet/custom-1")),
            "explicit token uri mismatch"
        );

        erc721.transferTokens(admin, eve, 1);

        assertTrue(erc721.ownerOf(1) == eve, "owner should update");
        assertTrue(erc721.balanceOf(admin) == 0, "admin nft balance should decrement");
        assertTrue(erc721.balanceOf(eve) == 1, "eve nft balance should increment");
        assertTrue(erc721.getApproved(1) == address(0), "approval should clear on transfer");
        assertTrue(erc721.isApprovedOrOwner(eve, 1), "new owner should be approved or owner");
    }

    function testErc721TokenUriFallsBackToBaseUriPlusTokenId() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");
        erc721.mint(admin, 7);

        assertTrue(
            keccak256(bytes(erc721.tokenURI(7))) == keccak256(bytes("ipfs://facet/7")),
            "base uri fallback should append token id"
        );

        erc721.setBaseURI("https://example.com/meta/");
        assertTrue(
            keccak256(bytes(erc721.tokenURI(7))) == keccak256(bytes("https://example.com/meta/7")),
            "updated base uri should be reflected"
        );
    }

    function testErc721SafeTransferCallsReceiver() public {
        bytes memory payload = hex"1234";

        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");
        erc721.mint(admin, 1);
        erc721.safeTransferTokens(admin, address(receiver), 1, payload);

        assertTrue(erc721.ownerOf(1) == address(receiver), "receiver should own token");
        assertTrue(receiver.lastOperator() == address(this), "receiver should record operator");
        assertTrue(receiver.lastFrom() == admin, "receiver should record sender");
        assertTrue(receiver.lastTokenId() == 1, "receiver should record token id");
        assertTrue(keccak256(receiver.lastData()) == keccak256(payload), "receiver should record data");
    }

    function testErc721SafeTransferRejectorReverts() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");
        erc721.mint(admin, 1);

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenUnsafeReceiver.selector, address(rejector)));
        erc721.safeTransferTokens(admin, address(rejector), 1, "");
    }

    function testErc721BurnClearsOwnershipAndSupply() public {
        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");
        erc721.mint(admin, 1);

        erc721.burn(1);

        assertTrue(erc721.totalSupply() == 0, "erc721 total supply should decrement");
        assertTrue(erc721.balanceOf(admin) == 0, "erc721 owner balance should decrement");

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenNonexistentToken.selector, 1));
        erc721.ownerOf(1);
    }

    function testErc721GuardsForZeroAddressAndInvalidOperator() public {
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenNotInitialized.selector));
        erc721.mint(admin, 1);

        erc721.initialize("Facet NFT", "FNFT", "ipfs://facet/");

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenZeroAddress.selector));
        erc721.mint(address(0), 1);

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenInvalidOwner.selector, address(0)));
        erc721.balanceOf(address(0));

        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenInvalidOperator.selector, admin, admin));
        erc721.setApprovalForAll(admin, admin, true);
    }

    function _shortStringSlot(string memory value) internal pure returns (bytes32 slotValue) {
        bytes memory data = bytes(value);
        assertTrue(data.length <= 31, "short string expected");

        assembly {
            slotValue := mload(add(data, 32))
        }

        return bytes32((uint256(slotValue) & ~uint256(0xff)) | uint256(data.length * 2));
    }
}
