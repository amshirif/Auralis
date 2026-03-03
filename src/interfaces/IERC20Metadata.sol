// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "./IERC20.sol";

/// @title IERC20Metadata
/// @notice ERC-20 metadata extension interface.
interface IERC20Metadata is IERC20 {
    /// @notice Returns token display name.
    /// @return Token name.
    function name() external view returns (string memory);

    /// @notice Returns token ticker symbol.
    /// @return Token symbol.
    function symbol() external view returns (string memory);

    /// @notice Returns token decimals used for display.
    /// @return Token decimals.
    function decimals() external view returns (uint8);
}
