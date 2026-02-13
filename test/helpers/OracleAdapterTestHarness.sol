// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OracleAdapter} from "../../src/oracle/OracleAdapter.sol";
import {IOracleFeed} from "../../src/interfaces/IOracleFeed.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract MockOracleFeed is IOracleFeed {
    uint8 internal _decimals;
    uint80 internal _roundId;
    int256 internal _answer;
    uint256 internal _startedAt;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    function setLatestRoundData(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _answer = answer;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }
}

contract OracleAdapterHarness is OracleAdapter {
    constructor(address initialAdmin, address initialSource, uint64 initialMaxStaleness)
        OracleAdapter(initialAdmin, initialSource, initialMaxStaleness)
    {}

    function initializeOracleAdapterExternal(address initialSource, uint64 initialMaxStaleness) external {
        _initializeOracleAdapter(initialSource, initialMaxStaleness);
    }
}

abstract contract OracleAdapterFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint64 internal maxStaleness = 1 hours;

    MockOracleFeed internal feedA;
    MockOracleFeed internal feedB;
    OracleAdapterHarness internal adapter;

    function setUp() public virtual {
        feedA = new MockOracleFeed(8);
        feedB = new MockOracleFeed(18);
        feedA.setLatestRoundData(1, 100_000_000, 100, 100, 1);
        feedB.setLatestRoundData(2, 2_000_000_000_000_000_000, 200, 200, 2);

        adapter = new OracleAdapterHarness(admin, address(feedA), maxStaleness);
    }
}

