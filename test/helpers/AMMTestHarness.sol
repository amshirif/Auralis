// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMFixedPoint} from "../../src/amm/libraries/AMMFixedPoint.sol";
import {AMMMath} from "../../src/amm/libraries/AMMMath.sol";
import {AMMLpToken} from "../../src/amm/AMMLpToken.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract AMMLpTokenHarness is AMMLpToken {
    function initializeAmmLpToken() external {
        _initializeAmmLpToken();
    }

    function mint(address to, uint256 value) external {
        _mintLp(to, value);
    }

    function burn(address from, uint256 value) external {
        _burnLp(from, value);
    }

    function initialized() external view returns (bool) {
        return _ammLpInitialized;
    }
}

abstract contract AMMFoundationFixture is TestBase {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 internal constant NAME_HASH = keccak256("Auralis V2 LP");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    uint256 internal constant ALICE_PK = 0xA11CE;
    uint256 internal constant BOB_PK = 0xB0B;
    uint256 internal constant CAROL_PK = 0xCAFE;

    AMMLpTokenHarness internal lpToken;
    address internal alice;
    address internal bob;
    address internal carol;

    function setUp() public virtual {
        lpToken = new AMMLpTokenHarness();
        alice = VM.addr(ALICE_PK);
        bob = VM.addr(BOB_PK);
        carol = VM.addr(CAROL_PK);
    }

    function _domainSeparator(address token) internal view returns (bytes32) {
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, token));
    }

    function _permitDigest(address token, address owner, address spender, uint256 value, uint256 nonce_, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce_, deadline));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(token), structHash));
    }

    function _signPermit(
        uint256 signerKey,
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce_,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        return VM.sign(signerKey, _permitDigest(token, owner, spender, value, nonce_, deadline));
    }

    function _recoverPermitSigner(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce_,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        return ecrecover(_permitDigest(token, owner, spender, value, nonce_, deadline), v, r, s);
    }

    function _invalidHighS(bytes32 s) internal pure returns (bytes32) {
        return bytes32(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - uint256(s)
        );
    }

    function _mathMin(uint256 x, uint256 y) internal pure returns (uint256) {
        return AMMMath.min(x, y);
    }

    function _mathSqrt(uint256 value) internal pure returns (uint256) {
        return AMMMath.sqrt(value);
    }

    function _encodeUq112x112(uint112 value) internal pure returns (uint224) {
        return AMMFixedPoint.encode(value).value;
    }

    function _uqdiv(uint112 value, uint112 divisor) internal pure returns (uint224) {
        return AMMFixedPoint.uqdiv(AMMFixedPoint.encode(value), divisor).value;
    }
}
