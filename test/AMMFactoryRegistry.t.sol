// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {AMMPair} from "../src/amm/AMMPair.sol";
import {AMMPairCoreFixture, MockAMMToken} from "./helpers/AMMPairTestHarness.sol";

contract AMMFactoryRegistryTest is AMMPairCoreFixture {
    function testConstructorSetsFeeToSetterAndPairCodeHash() public view {
        assertTrue(factory.feeToSetter() == address(this), "feeToSetter mismatch");
        assertTrue(factory.pairCodeHash() == keccak256(type(AMMPair).creationCode), "pair code hash mismatch");
    }

    function testCreatePairSortsTokensAndStoresBothLookupDirections() public {
        MockAMMToken unsortedA = new MockAMMToken("Token A", "TKA", 18);
        MockAMMToken unsortedB = new MockAMMToken("Token B", "TKB", 18);

        address expectedToken0 = address(unsortedA) < address(unsortedB) ? address(unsortedA) : address(unsortedB);
        address expectedToken1 = address(unsortedA) < address(unsortedB) ? address(unsortedB) : address(unsortedA);
        address createdPair = factory.createPair(address(unsortedB), address(unsortedA));

        assertTrue(factory.getPair(address(unsortedA), address(unsortedB)) == createdPair, "forward lookup mismatch");
        assertTrue(factory.getPair(address(unsortedB), address(unsortedA)) == createdPair, "reverse lookup mismatch");
        assertTrue(factory.allPairs(1) == createdPair, "allPairs entry mismatch");
        assertTrue(factory.allPairsLength() == 2, "allPairs length mismatch");

        AMMPair sortedPair = AMMPair(createdPair);
        assertTrue(sortedPair.factory() == address(factory), "pair factory mismatch");
        assertTrue(sortedPair.token0() == expectedToken0, "token0 sort mismatch");
        assertTrue(sortedPair.token1() == expectedToken1, "token1 sort mismatch");
    }

    function testCreatePairRevertsForZeroIdenticalAndDuplicatePairs() public {
        VM.expectRevert(AMMFactory.AMMFactoryZeroAddress.selector);
        factory.createPair(address(0), address(token0));

        VM.expectRevert(AMMFactory.AMMFactoryIdenticalTokens.selector);
        factory.createPair(address(token0), address(token0));

        VM.expectRevert(
            abi.encodeWithSelector(
                AMMFactory.AMMFactoryPairExists.selector,
                address(token0) < address(token1) ? address(token0) : address(token1),
                address(token0) < address(token1) ? address(token1) : address(token0)
            )
        );
        factory.createPair(address(token1), address(token0));
    }

    function testPredictedCreate2AddressMatchesDeployedPair() public {
        MockAMMToken localToken0 = new MockAMMToken("Local Token 0", "LT0", 18);
        MockAMMToken localToken1 = new MockAMMToken("Local Token 1", "LT1", 18);

        address predictedPair = _predictPairAddress(address(factory), address(localToken0), address(localToken1));
        address deployedPair = factory.createPair(address(localToken1), address(localToken0));

        assertTrue(deployedPair == predictedPair, "predicted pair mismatch");
    }

    function testSetFeeToRequiresFeeToSetterAndPersists() public {
        VM.prank(alice);
        VM.expectRevert(AMMFactory.AMMFactoryForbidden.selector);
        factory.setFeeTo(carol);

        factory.setFeeTo(carol);
        assertTrue(factory.feeTo() == carol, "feeTo mismatch");

        factory.setFeeTo(address(0));
        assertTrue(factory.feeTo() == address(0), "feeTo should clear");
    }

    function testSetFeeToSetterRequiresCurrentFeeToSetterAndPersists() public {
        VM.prank(alice);
        VM.expectRevert(AMMFactory.AMMFactoryForbidden.selector);
        factory.setFeeToSetter(carol);

        VM.expectRevert(AMMFactory.AMMFactoryZeroFeeToSetter.selector);
        factory.setFeeToSetter(address(0));

        factory.setFeeToSetter(carol);
        assertTrue(factory.feeToSetter() == carol, "feeToSetter mismatch");

        VM.expectRevert(AMMFactory.AMMFactoryForbidden.selector);
        factory.setFeeTo(address(this));

        VM.prank(carol);
        factory.setFeeTo(alice);
        assertTrue(factory.feeTo() == alice, "new feeToSetter should control feeTo");
    }

    function _predictPairAddress(address factory_, address tokenA, address tokenB) internal view returns (address) {
        (address sortedToken0, address sortedToken1) = _sortTokens(tokenA, tokenB);
        bytes32 salt = keccak256(abi.encodePacked(sortedToken0, sortedToken1));
        bytes32 rawAddress = keccak256(abi.encodePacked(hex"ff", factory_, salt, factory.pairCodeHash()));
        return address(uint160(uint256(rawAddress)));
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0_, address token1_) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
