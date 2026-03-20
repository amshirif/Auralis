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

### Selector Collision Constraint

ERC20 and ERC721 storage layouts are intentionally separate and can coexist
without storage collision. Their raw external selector surfaces cannot.

The standard interfaces collide on shared selectors such as:

- `name()`
- `symbol()`
- `totalSupply()`
- `balanceOf(address)`
- `supportsInterface(bytes4)` once shared control and ERC165 surfaces are
  included

That means one diamond cannot expose both standards unchanged at the same
address. The reference deployment model in this repo is therefore:

- one diamond hosting ERC20
- one diamond hosting ERC721

If both standards ever need to coexist in one host, that future design will
need namespaced selectors or a different routing surface.

### Reference Host Deployment Model

The current reference deployment scripts install and initialize token facets as
separate host flows:

- `script/DeployDiamondErc20Host.s.sol`
- `script/DeployDiamondErc721Host.s.sol`

Each flow:

- deploys a fresh diamond core
- installs loupe selectors
- installs one token facet selector set
- immediately calls the token initializer through the diamond
- validates selector ownership and initialized token metadata

Deployment artifacts are written separately for replayable local validation:

- `deployments/diamond-erc20.local.json`
- `deployments/diamond-erc721.local.json`
