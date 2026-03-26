// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {IOracleFeed} from "../../src/interfaces/IOracleFeed.sol";
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
    uint8 internal immutable _decimals;
    uint80 internal immutable _roundId;
    int256 internal immutable _answer;
    uint256 internal immutable _updatedAt;
    uint80 internal immutable _answeredInRound;

    constructor(uint8 decimals_, int256 answer_, uint256 updatedAt_) {
        _decimals = decimals_;
        _roundId = 1;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = 1;
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

/// @title LocalOracleAdapterHarness
/// @notice Concrete oracle adapter used by the local hosted-vault deployment flow.
contract LocalOracleAdapterHarness is OracleAdapter {
    constructor(address initialAdmin, address initialSource, uint64 initialMaxStaleness)
        OracleAdapter(initialAdmin, initialSource, initialMaxStaleness)
    {}
}
