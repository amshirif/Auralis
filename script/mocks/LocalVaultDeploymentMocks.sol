// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {IOracleFeed} from "../../src/interfaces/IOracleFeed.sol";
import {IERC4626VaultStrategy} from "../../src/interfaces/IERC4626VaultStrategy.sol";
import {OracleAdapter} from "../../src/oracle/OracleAdapter.sol";

/// @title LocalMintableVaultAsset
/// @notice Minimal mintable ERC20 used for local hosted-vault deployment rehearsal.
contract LocalMintableVaultAsset is IERC20Metadata {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "INSUFFICIENT_ALLOWANCE");
        if (currentAllowance != type(uint256).max) {
            unchecked {
                _allowances[from][msg.sender] = currentAllowance - value;
            }
            emit Approval(from, msg.sender, _allowances[from][msg.sender]);
        }

        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "ZERO_TO");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;

        emit Transfer(from, to, value);
    }
}

/// @title LocalMockOracleFeed
/// @notice Minimal oracle feed used for local hosted-vault deployment rehearsal.
contract LocalMockOracleFeed is IOracleFeed {
    uint8 internal _decimals;
    uint80 internal _roundId;
    int256 internal _answer;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;

    constructor(uint8 decimals_, int256 answer_, uint256 updatedAt_) {
        _decimals = decimals_;
        _roundId = 1;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = 1;
    }

    function setRoundData(int256 answer_, uint256 updatedAt_) external {
        _roundId += 1;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = _roundId;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}

/// @title LocalHappyPathVaultStrategy
/// @notice Simple vault-bound, asset-bound strategy used for local hosted-vault deployment and smoke flows.
contract LocalHappyPathVaultStrategy is IERC4626VaultStrategy {
    address internal immutable VAULT;
    address internal immutable ASSET;
    uint256 internal _trackedAssets;

    constructor(address vault_, address asset_) {
        VAULT = vault_;
        ASSET = asset_;
    }

    modifier onlyVault() {
        if (msg.sender != VAULT) {
            revert ERC4626VaultStrategyOnlyVault(msg.sender, VAULT);
        }
        _;
    }

    function vault() external view returns (address) {
        return VAULT;
    }

    function asset() external view returns (address) {
        return ASSET;
    }

    function totalAssets() external view returns (uint256) {
        return _trackedAssets;
    }

    function maxWithdrawableAssets() external view returns (uint256) {
        return _trackedAssets;
    }

    function deployFunds(uint256 assets) external onlyVault {
        _trackedAssets += assets;
        require(LocalMintableVaultAsset(ASSET).balanceOf(address(this)) >= _trackedAssets, "STRATEGY_UNDERFUNDED");
    }

    function withdrawToVault(uint256 assets) external onlyVault returns (uint256 assetsReturned) {
        assetsReturned = assets > _trackedAssets ? _trackedAssets : assets;
        _trackedAssets -= assetsReturned;
        if (assetsReturned != 0) {
            require(LocalMintableVaultAsset(ASSET).transfer(VAULT, assetsReturned), "STRATEGY_TRANSFER_FAILED");
        }
    }

    function withdrawAllToVault() external onlyVault returns (uint256 assetsReturned) {
        assetsReturned = _trackedAssets;
        _trackedAssets = 0;
        if (assetsReturned != 0) {
            require(LocalMintableVaultAsset(ASSET).transfer(VAULT, assetsReturned), "STRATEGY_TRANSFER_FAILED");
        }
    }

    function injectProfit(uint256 assets) external {
        if (assets == 0) {
            return;
        }

        LocalMintableVaultAsset(ASSET).mint(address(this), assets);
        _trackedAssets += assets;
    }
}

/// @title LocalOracleAdapterHarness
/// @notice Concrete oracle adapter used by the local hosted-vault deployment flow.
contract LocalOracleAdapterHarness is OracleAdapter {
    constructor(address initialAdmin, address initialSource, uint64 initialMaxStaleness)
        OracleAdapter(initialAdmin, initialSource, initialMaxStaleness)
    {}
}
