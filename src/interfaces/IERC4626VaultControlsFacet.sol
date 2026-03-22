// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "./IAccessControl.sol";
import {IAccessControlTime} from "./IAccessControlTime.sol";
import {IERC4626VaultControls} from "./IERC4626VaultControls.sol";
import {IPausable} from "./IPausable.sol";
import {IReentrancyGuard} from "./IReentrancyGuard.sol";

/// @title IERC4626VaultControlsFacet
/// @notice Hosted control-plane surface for future diamond vault facets.
interface IERC4626VaultControlsFacet is
    IERC4626VaultControls,
    IAccessControl,
    IAccessControlTime,
    IPausable,
    IReentrancyGuard
{}
