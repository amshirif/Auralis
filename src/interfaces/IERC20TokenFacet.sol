// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "./IAccessControl.sol";
import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC20Permit} from "./IERC20Permit.sol";
import {IERC20TokenBase} from "./IERC20TokenBase.sol";
import {IPausable} from "./IPausable.sol";

/// @title IERC20TokenFacet
/// @notice Hosted ERC-20 facet surface for diamond deployments.
interface IERC20TokenFacet is IERC20Metadata, IERC20TokenBase, IERC20Permit, IAccessControl, IPausable {
    /// @notice Thrown when a Permit signature is expired.
    /// @param deadline Permit deadline.
    /// @param currentTimestamp Current block timestamp.
    error ERC20PermitExpired(uint256 deadline, uint256 currentTimestamp);
    /// @notice Thrown when a Permit signature does not recover the expected signer.
    /// @param signer Recovered signer.
    /// @param owner Expected owner.
    error ERC20PermitInvalidSigner(address signer, address owner);

    /// @notice Returns the shared token admin role identifier.
    /// @return The role identifier.
    function TOKEN_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-20 minter role identifier.
    /// @return The role identifier.
    function ERC20_MINTER_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-20 burner role identifier.
    /// @return The role identifier.
    function ERC20_BURNER_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-20 transfer pause scope identifier.
    /// @return The scope identifier.
    function ERC20_TRANSFER_SCOPE() external view returns (bytes32);

    /// @notice Returns the ERC-20 approval pause scope identifier.
    /// @return The scope identifier.
    function ERC20_APPROVAL_SCOPE() external view returns (bytes32);

    /// @notice Initializes the hosted ERC-20 facet.
    /// @param tokenName Token name.
    /// @param tokenSymbol Token symbol.
    /// @param tokenDecimals Token decimals.
    /// @param admin Admin account seeded into the shared control plane.
    function initializeErc20(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        address admin
    ) external;

    /// @notice Mints `value` tokens to `to`.
    /// @param to Recipient account.
    /// @param value Amount to mint.
    function mint(address to, uint256 value) external;

    /// @notice Burns `value` tokens from `from`.
    /// @param from Token holder.
    /// @param value Amount to burn.
    function burn(address from, uint256 value) external;
}
