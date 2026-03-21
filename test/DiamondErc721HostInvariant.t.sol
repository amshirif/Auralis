// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721TokenBase} from "../src/interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../src/interfaces/IERC721TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {DiamondTokenHostHardeningFixture} from "./helpers/DiamondTokenHostHardeningTestHarness.sol";

contract DiamondErc721HostInvariantTest is DiamondTokenHostHardeningFixture {
    uint256 internal constant TOKEN_POOL = 8;
    uint256 internal constant ACTOR_COUNT = 5;

    address[ACTOR_COUNT] internal actors;

    function setUp() public override {
        super.setUp();
        _installErc721HostFacet(address(erc721Facet));
        _erc721InitDiamond();

        actors[0] = admin;
        actors[1] = bob;
        actors[2] = eve;
        actors[3] = carol;
        actors[4] = dave;
    }

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionMint(uint8 toSeed, uint8 tokenSeed) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        if (_erc721Exists(tokenId)) return;

        if (token.scopePaused(transferScope)) {
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.mint(_actor(toSeed), tokenId);
            return;
        }

        VM.prank(admin);
        token.mint(_actor(toSeed), tokenId);
    }

    function actionSafeMint(uint8 toSeed, uint8 tokenSeed, bytes4 dataSeed) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        if (_erc721Exists(tokenId)) return;

        if (token.scopePaused(transferScope)) {
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.safeMint(_actor(toSeed), tokenId, abi.encodePacked(dataSeed));
            return;
        }

        VM.prank(admin);
        token.safeMint(_actor(toSeed), tokenId, abi.encodePacked(dataSeed));
    }

    function actionApprove(uint8 operatorSeed, uint8 tokenSeed) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        if (!_erc721Exists(tokenId)) return;

        address owner = token.ownerOf(tokenId);
        address operator = _actorExcluding(owner, operatorSeed);
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();

        if (token.scopePaused(approvalScope)) {
            VM.prank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            token.approve(operator, tokenId);
            return;
        }

        VM.prank(owner);
        token.approve(operator, tokenId);
        assertTrue(token.getApproved(tokenId) == operator, "host erc721 approval should update");
    }

    function actionSetApprovalForAll(uint8 ownerSeed, uint8 operatorSeed, bool approved) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        address owner = _actor(ownerSeed);
        address operator = _actorExcluding(owner, operatorSeed);
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();

        if (token.scopePaused(approvalScope)) {
            VM.prank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            token.setApprovalForAll(operator, approved);
            return;
        }

        VM.prank(owner);
        token.setApprovalForAll(operator, approved);
        assertTrue(token.isApprovedForAll(owner, operator) == approved, "host erc721 operator approval mismatch");
    }

    function actionTransferFrom(uint8 toSeed, uint8 tokenSeed, uint8 approvalSeed) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        if (!_erc721Exists(tokenId)) return;

        address owner = token.ownerOf(tokenId);
        address to = _actorExcluding(owner, toSeed);
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();

        if (!token.scopePaused(approvalScope)) {
            VM.prank(owner);
            token.approve(_actorExcluding(owner, approvalSeed), tokenId);
        }

        if (token.scopePaused(transferScope)) {
            VM.prank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.transferFrom(owner, to, tokenId);
            return;
        }

        VM.prank(owner);
        token.transferFrom(owner, to, tokenId);
        assertTrue(token.ownerOf(tokenId) == to, "host erc721 transfer owner mismatch");
        assertTrue(token.getApproved(tokenId) == address(0), "host erc721 transfer should clear approval");
    }

    function actionSafeTransferFrom(uint8 toSeed, uint8 tokenSeed, uint8 approvalSeed, bool withData) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        if (!_erc721Exists(tokenId)) return;

        address owner = token.ownerOf(tokenId);
        address to = _actorExcluding(owner, toSeed);
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();

        if (!token.scopePaused(approvalScope)) {
            VM.prank(owner);
            token.approve(_actorExcluding(owner, approvalSeed), tokenId);
        }

        if (token.scopePaused(transferScope)) {
            VM.prank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            if (withData) {
                token.safeTransferFrom(owner, to, tokenId, hex"cafe");
            } else {
                token.safeTransferFrom(owner, to, tokenId);
            }
            return;
        }

        VM.prank(owner);
        if (withData) {
            token.safeTransferFrom(owner, to, tokenId, hex"cafe");
        } else {
            token.safeTransferFrom(owner, to, tokenId);
        }
        assertTrue(token.ownerOf(tokenId) == to, "host erc721 safe transfer owner mismatch");
        assertTrue(token.getApproved(tokenId) == address(0), "host erc721 safe transfer should clear approval");
    }

    function actionBurn(uint8 tokenSeed, uint8 approvalSeed) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        if (!_erc721Exists(tokenId)) return;

        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();
        address owner = token.ownerOf(tokenId);
        if (!token.scopePaused(approvalScope)) {
            VM.prank(owner);
            token.approve(_actorExcluding(owner, approvalSeed), tokenId);
        }

        if (token.scopePaused(transferScope)) {
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.burn(tokenId);
            return;
        }

        VM.prank(admin);
        token.burn(tokenId);
        _expectNonexistentToken(tokenId);
        assertTrue(_erc721ApprovalOrZero(tokenId) == address(0), "host erc721 burn should clear approval");
    }

    function actionSetBaseURI(bool alternate) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        string memory baseUri = alternate ? "ipfs://updated-a/" : "ipfs://updated-b/";
        VM.prank(admin);
        token.setBaseURI(baseUri);
    }

    function actionSetTokenURI(uint8 tokenSeed, bool alternate) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 tokenId = _tokenId(tokenSeed);
        if (!_erc721Exists(tokenId)) return;

        string memory customUri = alternate ? "ipfs://custom-a" : "ipfs://custom-b";
        VM.prank(admin);
        token.setTokenURI(tokenId, customUri);
        assertTrue(
            keccak256(bytes(token.tokenURI(tokenId))) == keccak256(bytes(customUri)),
            "host erc721 token uri update mismatch"
        );
    }

    function actionSetApprovalScopePaused(bool paused_) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();
        bool isPaused = token.scopePaused(approvalScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            token.pauseScope(approvalScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            token.unpauseScope(approvalScope);
        }
    }

    function actionSetTransferScopePaused(bool paused_) external {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();
        bool isPaused = token.scopePaused(transferScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            token.pauseScope(transferScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            token.unpauseScope(transferScope);
        }
    }

    function invariantTotalSupplyMatchesLiveTokenCount() public view {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256 liveCount;
        for (uint256 tokenId = 1; tokenId <= TOKEN_POOL; tokenId++) {
            if (_erc721Exists(tokenId)) {
                liveCount++;
            }
        }

        assertTrue(token.totalSupply() == liveCount, "host erc721 total supply should match live tokens");
    }

    function invariantBalancesMatchTrackedOwnershipCounts() public view {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        uint256[ACTOR_COUNT] memory counts;

        for (uint256 tokenId = 1; tokenId <= TOKEN_POOL; tokenId++) {
            address owner = _erc721OwnerOrZero(tokenId);
            for (uint256 i = 0; i < ACTOR_COUNT; i++) {
                if (owner == actors[i]) {
                    counts[i] += 1;
                    break;
                }
            }
        }

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            assertTrue(token.balanceOf(actors[i]) == counts[i], "host erc721 balances should match ownership counts");
        }
    }

    function invariantApprovalsOnlyExistForLiveTokens() public view {
        for (uint256 tokenId = 1; tokenId <= TOKEN_POOL; tokenId++) {
            if (!_erc721Exists(tokenId)) {
                assertTrue(_erc721ApprovalOrZero(tokenId) == address(0), "burned tokens must not retain approval");
            }
        }
    }

    function _tokenId(uint8 seed) internal pure returns (uint256) {
        return (uint256(seed) % TOKEN_POOL) + 1;
    }
}
