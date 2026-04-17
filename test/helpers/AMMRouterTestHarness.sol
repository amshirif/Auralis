// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMRouter} from "../../src/amm/AMMRouter.sol";
import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {AMMPair} from "../../src/amm/AMMPair.sol";
import {IWrappedNative} from "../../src/interfaces/IWrappedNative.sol";
import {AMMPairCoreFixture, FalseReturningAMMToken, MockAMMToken} from "./AMMPairTestHarness.sol";

contract MockWrappedNative is MockAMMToken, IWrappedNative {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockAMMToken(name_, symbol_, decimals_) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _balances[msg.sender] += msg.value;
        _totalSupply += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 value) external {
        uint256 balance = _balances[msg.sender];
        require(balance >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[msg.sender] = balance - value;
            _totalSupply -= value;
        }

        emit Transfer(msg.sender, address(0), value);

        (bool success,) = payable(msg.sender).call{value: value}("");
        require(success, "NATIVE_TRANSFER_FAILED");
    }
}

contract RejectingNativeReceiver {
    receive() external payable {
        revert("REJECT_NATIVE");
    }
}

abstract contract AMMRouterFixture is AMMPairCoreFixture {
    uint256 internal constant DEADLINE = type(uint256).max;

    AMMRouter internal router;
    MockWrappedNative internal wrappedNativeToken;
    MockAMMToken internal token2;

    function setUp() public virtual override {
        super.setUp();

        wrappedNativeToken = new MockWrappedNative("Wrapped Native", "WNATIVE", 18);
        token2 = new MockAMMToken("Token 2", "TK2", 18);
        router = new AMMRouter(address(factory), address(wrappedNativeToken));
    }

    function _mintOrWrapTo(MockAMMToken token, address recipient, uint256 amount) internal {
        if (address(token) == address(wrappedNativeToken)) {
            VM.deal(recipient, recipient.balance + amount);
            VM.prank(recipient);
            wrappedNativeToken.deposit{value: amount}();
            return;
        }

        token.mint(recipient, amount);
    }

    function _provideRouterLiquidity(
        MockAMMToken tokenA_,
        MockAMMToken tokenB_,
        address provider,
        uint256 amountA,
        uint256 amountB,
        address recipient
    ) internal returns (AMMPair pair_, uint256 liquidity) {
        address pairAddress = factory.getPair(address(tokenA_), address(tokenB_));
        if (pairAddress == address(0)) {
            pairAddress = factory.createPair(address(tokenA_), address(tokenB_));
        }

        pair_ = AMMPair(pairAddress);
        (MockAMMToken pairToken0, MockAMMToken pairToken1, uint256 amount0, uint256 amount1) = address(tokenA_)
                < address(tokenB_)
            ? (tokenA_, tokenB_, amountA, amountB)
            : (tokenB_, tokenA_, amountB, amountA);

        _mintOrWrapTo(pairToken0, provider, amount0);
        _mintOrWrapTo(pairToken1, provider, amount1);

        VM.startPrank(provider);
        assertTrue(pairToken0.transfer(address(pair_), amount0), "token0 transfer should succeed");
        assertTrue(pairToken1.transfer(address(pair_), amount1), "token1 transfer should succeed");
        VM.stopPrank();

        liquidity = pair_.mint(recipient);
    }

    function _path(address tokenA_, address tokenB_) internal pure returns (address[] memory path_) {
        path_ = new address[](2);
        path_[0] = tokenA_;
        path_[1] = tokenB_;
    }

    function _path(address tokenA_, address tokenB_, address tokenC_) internal pure returns (address[] memory path_) {
        path_ = new address[](3);
        path_[0] = tokenA_;
        path_[1] = tokenB_;
        path_[2] = tokenC_;
    }

    function _deployFalseReturningToken() internal returns (FalseReturningAMMToken token_) {
        token_ = new FalseReturningAMMToken("False Token", "FTK", 18);
    }
}
