// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {ERC4626Vault} from "../../src/vault/ERC4626Vault.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract MockVaultAsset is IERC20Metadata {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;

    bool internal _failTransfer;
    bool internal _failTransferFrom;

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

    function setFailTransfer(bool shouldFail) external {
        _failTransfer = shouldFail;
    }

    function setFailTransferFrom(bool shouldFail) external {
        _failTransferFrom = shouldFail;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        if (_failTransfer) {
            return false;
        }

        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (_failTransferFrom) {
            return false;
        }

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

contract ERC4626VaultCoreHarness is ERC4626Vault {
    function initialize(address vaultAsset, string calldata vaultName, string calldata vaultSymbol) external {
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    function seedPosition(address owner, uint256 shares, uint256 assets) external {
        _mintShares(owner, shares);
        _increaseManagedAssets(assets);
    }
}

abstract contract ERC4626CoreFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    MockVaultAsset internal asset;
    ERC4626VaultCoreHarness internal vault;

    function setUp() public virtual {
        asset = new MockVaultAsset("Mock USD", "mUSD", 6);
        vault = new ERC4626VaultCoreHarness();
        vault.initialize(address(asset), "Vault Share", "vSHARE");

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);
    }

    function _approveAsset(address owner, uint256 amount) internal {
        VM.prank(owner);
        asset.approve(address(vault), amount);
    }

    function _seedPosition(address owner, uint256 shares, uint256 assetsAmount) internal {
        vault.seedPosition(owner, shares, assetsAmount);
        asset.mint(address(vault), assetsAmount);
    }
}
