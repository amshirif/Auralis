// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAMMLpToken} from "../interfaces/IAMMLpToken.sol";
import {LibECDSA} from "../libraries/LibECDSA.sol";

/// @title AMMLpToken
/// @notice Abstract ERC-20 + permit base for AMM LP shares.
abstract contract AMMLpToken is IAMMLpToken {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 internal constant NAME_HASH = keccak256("Auralis V2 LP");
    bytes32 internal constant VERSION_HASH = keccak256("1");

    bool internal _ammLpInitialized;
    uint256 internal _ammLpTotalSupply;
    mapping(address account => uint256 balance) internal _ammLpBalances;
    mapping(address owner => mapping(address spender => uint256 allowance_)) internal _ammLpAllowances;
    mapping(address owner => uint256 nonce_) internal _permitNonces;
    bytes32 internal _hashedName;
    uint256 internal _cachedChainId;
    bytes32 internal _cachedDomainSeparator;

    /// @notice Returns the LP token name.
    /// @return LP token name.
    function name() public pure virtual returns (string memory) {
        return "Auralis V2 LP";
    }

    /// @notice Returns the LP token symbol.
    /// @return LP token symbol.
    function symbol() public pure virtual returns (string memory) {
        return "AUR-V2-LP";
    }

    /// @notice Returns the LP token decimal precision.
    /// @return Decimal precision used by LP token balances.
    function decimals() public pure virtual returns (uint8) {
        return 18;
    }

    /// @notice Returns total minted LP token supply.
    /// @return Current LP token supply.
    function totalSupply() public view virtual returns (uint256) {
        return _ammLpTotalSupply;
    }

    /// @notice Returns an account's LP token balance.
    /// @param account Account to inspect.
    /// @return Current LP token balance.
    function balanceOf(address account) public view virtual returns (uint256) {
        return _ammLpBalances[account];
    }

    /// @notice Returns the LP token allowance from `owner` to `spender`.
    /// @param owner Allowance owner.
    /// @param spender Allowance spender.
    /// @return Current allowance amount.
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _ammLpAllowances[owner][spender];
    }

    /// @notice Approves `spender` to spend LP tokens from the caller.
    /// @param spender Account receiving allowance.
    /// @param value Allowance amount.
    /// @return True when approval succeeds.
    function approve(address spender, uint256 value) external virtual returns (bool) {
        _requireInitialized();
        _approveLp(msg.sender, spender, value);
        return true;
    }

    /// @notice Transfers LP tokens from the caller.
    /// @param to Recipient account.
    /// @param value LP token amount.
    /// @return True when transfer succeeds.
    function transfer(address to, uint256 value) external virtual returns (bool) {
        _transferLp(msg.sender, to, value);
        return true;
    }

    /// @notice Transfers LP tokens using the caller's allowance.
    /// @param from Account whose LP tokens are moved.
    /// @param to Recipient account.
    /// @param value LP token amount.
    /// @return True when transfer succeeds.
    function transferFrom(address from, address to, uint256 value) external virtual returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transferLp(from, to, value);
        return true;
    }

    /// @notice Approves LP token allowance using an EIP-2612 permit signature.
    /// @param owner Token owner that signed the permit.
    /// @param spender Account receiving allowance.
    /// @param value Allowance amount.
    /// @param deadline Latest timestamp at which the permit is valid.
    /// @param v Signature recovery id.
    /// @param r Signature r value.
    /// @param s Signature s value.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        virtual
    {
        _requireInitialized();

        if (block.timestamp > deadline) {
            revert AMMLpPermitExpired(deadline, block.timestamp);
        }

        uint256 nonce_ = _permitNonces[owner];
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce_, deadline));
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        address signer = _recoverSigner(digest, v, r, s);
        if (signer != owner) {
            revert AMMLpPermitInvalidSigner(signer, owner);
        }

        _permitNonces[owner] = nonce_ + 1;
        _approveLp(owner, spender, value);
    }

    /// @notice Returns the current permit nonce for an owner.
    /// @param owner Account whose nonce is read.
    /// @return Current permit nonce.
    function nonces(address owner) external view virtual returns (uint256) {
        return _permitNonces[owner];
    }

    /// @notice Returns the EIP-712 domain separator for LP token permits.
    /// @return Current domain separator.
    // forge-lint: disable-next-line(mixed-case-function)
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        bytes32 hashedName = _hashedName == bytes32(0) ? NAME_HASH : _hashedName;
        if (_cachedChainId == block.chainid && _cachedDomainSeparator != bytes32(0)) {
            return _cachedDomainSeparator;
        }
        return _buildDomainSeparator(hashedName, block.chainid);
    }

    function _initializeAmmLpToken() internal {
        if (_ammLpInitialized) {
            revert AMMLpAlreadyInitialized();
        }

        _ammLpInitialized = true;
        _hashedName = NAME_HASH;
        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator(NAME_HASH, block.chainid);
    }

    function _mintLp(address to, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(to);

        _ammLpTotalSupply += value;
        _ammLpBalances[to] += value;

        emit Transfer(address(0), to, value);
    }

    function _burnLp(address from, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(from);

        uint256 fromBalance = _ammLpBalances[from];
        if (fromBalance < value) {
            revert AMMLpInsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            _ammLpBalances[from] = fromBalance - value;
            _ammLpTotalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }

    function _transferLp(address from, address to, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(from);
        _requireNonZeroAddress(to);

        uint256 fromBalance = _ammLpBalances[from];
        if (fromBalance < value) {
            revert AMMLpInsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            _ammLpBalances[from] = fromBalance - value;
        }
        _ammLpBalances[to] += value;

        emit Transfer(from, to, value);
    }

    function _approveLp(address owner, address spender, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(owner);

        _ammLpAllowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(owner);

        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance == type(uint256).max) {
            return;
        }
        if (currentAllowance < value) {
            revert AMMLpInsufficientAllowance(owner, spender, currentAllowance, value);
        }

        unchecked {
            _approveLp(owner, spender, currentAllowance - value);
        }
    }

    function _buildDomainSeparator(bytes32 hashedName, uint256 chainId) internal view returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, hashedName, VERSION_HASH, chainId, address(this)));
    }

    function _recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        if (v != 27 && v != 28) {
            return address(0);
        }
        if (uint256(s) > LibECDSA.SECP256K1N_DIV_2) {
            return address(0);
        }

        return ecrecover(digest, v, r, s);
    }

    function _requireInitialized() internal view {
        if (!_ammLpInitialized) {
            revert AMMLpNotInitialized();
        }
    }

    function _requireNonZeroAddress(address account) internal pure {
        if (account == address(0)) {
            revert AMMLpZeroAddress();
        }
    }
}
