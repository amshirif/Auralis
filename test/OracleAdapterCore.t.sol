// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OracleAdapterFixture, OracleAdapterHarness, MockOracleFeed} from "./helpers/OracleAdapterTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract OracleAdapterCoreTest is OracleAdapterFixture {
    event OracleSourceUpdated(address indexed previousSource, address indexed newSource, address indexed sender);
    event OracleMaxStalenessUpdated(uint64 previousMaxStaleness, uint64 newMaxStaleness, address indexed sender);

    function testInitialConfig() public view {
        assertTrue(adapter.oracleSource() == address(feedA), "initial source should match constructor");
        assertTrue(adapter.maxStaleness() == maxStaleness, "initial max staleness should match constructor");
    }

    function testSupportsInterface() public view {
        assertTrue(adapter.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(adapter.supportsInterface(type(IOracleAdapter).interfaceId), "oracle adapter not supported");
        assertTrue(adapter.supportsInterface(type(IAccessControl).interfaceId), "access control not supported");
        assertTrue(adapter.supportsInterface(type(IAccessControlTime).interfaceId), "access control time not supported");
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterAlreadyInitialized.selector));
        adapter.initializeOracleAdapterExternal(address(feedA), maxStaleness);
    }

    function testZeroSourceRevertsOnConstruction() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterZeroSource.selector));
        new OracleAdapterHarness(admin, address(0), maxStaleness);
    }

    function testAdminCanSetOracleSource() public {
        VM.prank(admin);
        adapter.setOracleSource(address(feedB));
        assertTrue(adapter.oracleSource() == address(feedB), "source should update");
    }

    function testSetOracleSourceEmitsEvent() public {
        VM.expectEmit(true, true, true, false, address(adapter));
        emit OracleSourceUpdated(address(feedA), address(feedB), admin);

        VM.prank(admin);
        adapter.setOracleSource(address(feedB));
    }

    function testNonAdminCannotSetOracleSource() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.DEFAULT_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setOracleSource(address(feedB));
    }

    function testSetOracleSourceRejectsZeroAddress() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterZeroSource.selector));
        VM.prank(admin);
        adapter.setOracleSource(address(0));
    }

    function testAdminCanSetMaxStaleness() public {
        VM.prank(admin);
        adapter.setMaxStaleness(2 hours);
        assertTrue(adapter.maxStaleness() == 2 hours, "max staleness should update");
    }

    function testSetMaxStalenessEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleMaxStalenessUpdated(maxStaleness, 2 hours, admin);

        VM.prank(admin);
        adapter.setMaxStaleness(2 hours);
    }

    function testNonAdminCannotSetMaxStaleness() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.DEFAULT_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setMaxStaleness(2 hours);
    }

    function testQuoteReturnsNormalizedPayload() public view {
        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 100_000_000, "value should match source answer");
        assertTrue(readQuote.updatedAt == 100, "updatedAt should match source");
        assertTrue(readQuote.decimals == 8, "decimals should match source");
    }

    function testQuoteReflectsSourceChange() public {
        VM.prank(admin);
        adapter.setOracleSource(address(feedB));

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 2_000_000_000_000_000_000, "value should match new source");
        assertTrue(readQuote.updatedAt == 200, "updatedAt should match new source");
        assertTrue(readQuote.decimals == 18, "decimals should match new source");
    }

    function testQuoteRevertsOnUpdatedAtOverflow() public {
        feedA.setLatestRoundData(1, 100_000_000, 100, uint256(type(uint64).max) + 1, 1);

        VM.expectRevert(
            abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidUpdatedAt.selector, uint256(type(uint64).max) + 1)
        );
        adapter.quote();
    }
}
