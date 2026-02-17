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
    bool internal _revertLatestRoundData;
    bool internal _revertDecimals;

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

    function setRevertLatestRoundData(bool shouldRevert) external {
        _revertLatestRoundData = shouldRevert;
    }

    function setRevertDecimals(bool shouldRevert) external {
        _revertDecimals = shouldRevert;
    }

    function decimals() external view returns (uint8) {
        if (_revertDecimals) {
            revert("MOCK_DECIMALS_REVERT");
        }
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_revertLatestRoundData) {
            revert("MOCK_ROUND_DATA_REVERT");
        }
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }
}

contract MalformedRoundDataFeed is IOracleFeed {
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData() external pure returns (uint80, int256, uint256, uint256, uint80) {
        // Intentionally return malformed payload to simulate bad provider ABI behavior.
        assembly {
            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }
}

contract MalformedDecimalsFeed is IOracleFeed {
    function decimals() external pure returns (uint8) {
        // Intentionally return malformed payload to simulate bad provider ABI behavior.
        assembly {
            mstore8(0x00, 0x08)
            return(0x00, 0x01)
        }
    }

    function latestRoundData()
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, 100_000_000, 999_900, 999_900, 1);
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
    address internal eve = address(0xE11E);

    uint64 internal maxStaleness = 1 hours;
    uint64 internal currentTime = 1_000_000;
    uint64 internal feedAUpdatedAt = 999_900;
    uint64 internal feedBUpdatedAt = 999_950;

    MockOracleFeed internal feedA;
    MockOracleFeed internal feedB;
    OracleAdapterHarness internal adapter;

    function setUp() public virtual {
        VM.warp(currentTime);

        feedA = new MockOracleFeed(8);
        feedB = new MockOracleFeed(18);
        feedA.setLatestRoundData(1, 100_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);
        feedB.setLatestRoundData(2, 2_000_000_000_000_000_000, feedBUpdatedAt, feedBUpdatedAt, 2);

        adapter = new OracleAdapterHarness(admin, address(feedA), maxStaleness);
    }
}
