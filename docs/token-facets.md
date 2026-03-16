## Token Facet Foundation

This document defines the shared foundation for hosted token facets in the
diamond roadmap.

### Shared Interfaces

The token foundation introduces:

- `IERC20Permit` for future EIP-2612 support on the ERC-20 side
- `IERC721`, `IERC721Metadata`, and `IERC721Receiver` for the ERC-721 side
- `IERC20TokenBase` and `IERC721TokenBase` for foundation-specific init/error
  surfaces used by the base contracts

### Storage Conventions

Hosted token facets use separate fixed storage slots:

- ERC-20: `keccak256("smart-contracts.token.erc20.storage")`
- ERC-721: `keccak256("smart-contracts.token.erc721.storage")`

The milestone intentionally keeps those layouts separate so ERC-20 and ERC-721
facets can coexist in one diamond without balance, allowance, ownership, or
metadata collisions.

### Initializer Pattern

Each hosted token standard owns its own one-time initializer:

- `_initializeErc20Token(...)`
- `_initializeErc721Token(...)`

The initializer guards are per-token-standard, not global to the diamond. That
lets one diamond host both token systems while still preventing duplicate init
for either storage layout.

### Access Control And Pause Rules

The shared token constants library defines the canonical integration surface for
later facets:

- roles:
  - `TOKEN_ADMIN_ROLE`
  - `ERC20_MINTER_ROLE`
  - `ERC20_BURNER_ROLE`
  - `ERC721_MINTER_ROLE`
  - `ERC721_BURNER_ROLE`
  - `ERC721_METADATA_ROLE`
- pause scopes:
  - `ERC20_TRANSFER_SCOPE`
  - `ERC20_APPROVAL_SCOPE`
  - `ERC721_TRANSFER_SCOPE`
  - `ERC721_APPROVAL_SCOPE`

Later ERC20/721 facet issues should reuse those identifiers rather than invent
parallel role or pause namespaces.

### ERC165 Notes

ERC-20 does not rely on ERC-165. ERC-721 does, and the shared ERC-721 base
advertises:

- `IERC165`
- `IERC721`
- `IERC721Metadata`

When ERC-721 is installed behind a diamond, the init or deployment flow should
ensure the diamond-level interface surface remains consistent with the facet
selectors that are actually installed.
