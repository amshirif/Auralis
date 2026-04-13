// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "../../src/amm/AMMPair.sol";
import {IAMMFactory} from "../../src/interfaces/IAMMFactory.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {AMMFoundationFixture} from "./AMMTestHarness.sol";

contract MockAMMToken is IERC20Metadata {
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

    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
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

contract FalseReturningAMMToken is MockAMMToken {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockAMMToken(name_, symbol_, decimals_) {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract SilentAMMToken is MockAMMToken {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockAMMToken(name_, symbol_, decimals_) {}

    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value);
        assembly {
            return(0, 0)
        }
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "INSUFFICIENT_ALLOWANCE");

        if (currentAllowance != type(uint256).max) {
            unchecked {
                _allowances[from][msg.sender] = currentAllowance - value;
            }
            emit Approval(from, msg.sender, _allowances[from][msg.sender]);
        }

        _transfer(from, to, value);
        assembly {
            return(0, 0)
        }
    }
}

contract MalformedAMMToken is MockAMMToken {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockAMMToken(name_, symbol_, decimals_) {}

    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value);
        assembly {
            mstore(0x00, 1)
            return(0x1f, 0x01)
        }
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "INSUFFICIENT_ALLOWANCE");

        if (currentAllowance != type(uint256).max) {
            unchecked {
                _allowances[from][msg.sender] = currentAllowance - value;
            }
            emit Approval(from, msg.sender, _allowances[from][msg.sender]);
        }

        _transfer(from, to, value);
        assembly {
            mstore(0x00, 1)
            return(0x1f, 0x01)
        }
    }
}

contract ReentrantAMMToken is MockAMMToken {
    address internal _pairToReenter;
    bool internal _reenterSyncEnabled;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockAMMToken(name_, symbol_, decimals_) {}

    function setReenterSync(address pair_, bool enabled) external {
        _pairToReenter = pair_;
        _reenterSyncEnabled = enabled;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (_reenterSyncEnabled && msg.sender == _pairToReenter) {
            AMMPair(_pairToReenter).sync();
        }

        _transfer(msg.sender, to, value);
        return true;
    }
}

contract AMMFactoryHarness is IAMMFactory {
    address public override feeTo;
    address public override feeToSetter;

    address[] internal _allPairs;
    mapping(address => mapping(address => address)) internal _pairs;

    constructor(address feeToSetter_) {
        feeToSetter = feeToSetter_;
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }

    function allPairs(uint256 index) external view returns (address) {
        return _allPairs[index];
    }

    function allPairsLength() external view returns (uint256) {
        return _allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != address(0) && tokenB != address(0), "ZERO_TOKEN");
        require(tokenA != tokenB, "IDENTICAL_TOKEN");
        require(_pairs[tokenA][tokenB] == address(0), "PAIR_EXISTS");

        pair = address(new AMMPair());
        AMMPair(pair).initialize(tokenA, tokenB);

        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
        _allPairs.push(pair);

        emit PairCreated(tokenA, tokenB, pair, _allPairs.length);
    }

    function setFeeTo(address feeTo_) external {
        require(msg.sender == feeToSetter, "FORBIDDEN");
        feeTo = feeTo_;
    }

    function setFeeToSetter(address feeToSetter_) external {
        require(msg.sender == feeToSetter, "FORBIDDEN");
        feeToSetter = feeToSetter_;
    }
}

    abstract contract AMMPairCoreFixture is AMMFoundationFixture {
        address internal constant BURN_SINK = 0x000000000000000000000000000000000000dEaD;

        AMMFactoryHarness internal factory;
        AMMPair internal pair;
        MockAMMToken internal token0;
        MockAMMToken internal token1;

        function setUp() public virtual override {
            super.setUp();

            factory = new AMMFactoryHarness(address(this));
            token0 = new MockAMMToken("Token 0", "TK0", 18);
            token1 = new MockAMMToken("Token 1", "TK1", 18);
            pair = AMMPair(factory.createPair(address(token0), address(token1)));
        }

        function _provideLiquidity(
            AMMPair pair_,
            MockAMMToken token0_,
            MockAMMToken token1_,
            address provider,
            uint256 amount0,
            uint256 amount1,
            address recipient
        ) internal returns (uint256 liquidity) {
            token0_.mint(provider, amount0);
            token1_.mint(provider, amount1);

            VM.startPrank(provider);
            assertTrue(token0_.transfer(address(pair_), amount0), "token0 transfer should succeed");
            assertTrue(token1_.transfer(address(pair_), amount1), "token1 transfer should succeed");
            VM.stopPrank();

            liquidity = pair_.mint(recipient);
        }

        function _seedLiquidityDirect(
            AMMPair pair_,
            MockAMMToken token0_,
            MockAMMToken token1_,
            uint256 amount0,
            uint256 amount1,
            address recipient
        ) internal returns (uint256 liquidity) {
            token0_.mint(address(pair_), amount0);
            token1_.mint(address(pair_), amount1);
            liquidity = pair_.mint(recipient);
        }

        function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
            internal
            pure
            returns (uint256)
        {
            uint256 amountInWithFee = amountIn * 997;
            return (amountInWithFee * reserveOut) / ((reserveIn * 1000) + amountInWithFee);
        }

        function _deployPair(address token0_, address token1_) internal returns (AMMPair pair_) {
            AMMFactoryHarness localFactory = new AMMFactoryHarness(address(this));
            pair_ = AMMPair(localFactory.createPair(token0_, token1_));
        }
    }
