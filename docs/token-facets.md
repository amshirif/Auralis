# Diamond Token Facets

This document is the canonical guide for the hosted token architecture in
`Auralis`.

For the decision to deploy separate hosts instead of a single shared token host,
see `docs/adr/0002-separate-diamond-hosts.md`.

The supported deployment model is:

- one ERC20-hosted diamond
- one ERC721-hosted diamond

That split is intentional. The repo preserves standard ERC20 and ERC721
external surfaces, and those standards collide on shared selectors such as
`name()`, `symbol()`, `balanceOf(address)`, and `totalSupply()`. One diamond
cannot expose both standards unchanged at the same address without namespacing
or a different routing model.

## Supported Hosts

### ERC20 Host

The ERC20 host installs:

- ERC20 metadata selectors
- core ERC20 state-changing selectors
- EIP-2612 Permit selectors
- shared control selectors for access control, pause scopes, and
  `supportsInterface`

Reference deployment flow:

- `script/DeployDiamondErc20Host.s.sol`

Reference artifact:

- `deployments/diamond-erc20.local.json`

### ERC721 Host

The ERC721 host installs:

- ERC721 core selectors
- ERC721 metadata selectors
- hosted mint, burn, and metadata-management selectors
- shared control selectors for access control, pause scopes, and
  `supportsInterface`

Reference deployment flow:

- `script/DeployDiamondErc721Host.s.sol`

Reference artifact:

- `deployments/diamond-erc721.local.json`

## Initialization Model

Each token standard owns its own one-time initializer and is initialized through
the diamond after the facet selectors are installed.

### ERC20

Initializer:

- `initializeErc20(string name, string symbol, uint8 decimals, address admin)`

Initialization seeds:

- token metadata
- Permit domain state
- shared control state when the host is first initialized
- role assignments for the provided `admin`

Initialization expectations:

- idempotent per ERC20 host
- second initialization reverts
- Permit uses the token name, version `"1"`, current `chainid`, and diamond
  address for the domain separator

### ERC721

Initializer:

- `initializeErc721(string name, string symbol, string baseURI, address admin)`

Initialization seeds:

- token metadata and base URI
- shared control state when the host is first initialized
- role assignments for the provided `admin`

Initialization expectations:

- idempotent per ERC721 host
- second initialization reverts

## Role Model And Pause Scopes

Hosted token facets reuse the shared control plane. They do not maintain a
token-local access-control or pause system.

### Shared Admin Roles

- `DEFAULT_ADMIN_ROLE`
- `TOKEN_ADMIN_ROLE`
- `PAUSER_ROLE`

`TOKEN_ADMIN_ROLE` is administered by `DEFAULT_ADMIN_ROLE`.

### ERC20 Roles

- `ERC20_MINTER_ROLE`
- `ERC20_BURNER_ROLE`

Both are administered by `TOKEN_ADMIN_ROLE`.

### ERC721 Roles

- `ERC721_MINTER_ROLE`
- `ERC721_BURNER_ROLE`
- `ERC721_METADATA_ROLE`

All are administered by `TOKEN_ADMIN_ROLE`.

### Pause Scopes

ERC20 host:

- `ERC20_TRANSFER_SCOPE`
  - gates `transfer`, `mint`, and `burn`
- `ERC20_APPROVAL_SCOPE`
  - gates `approve`, `permit`, and approval-dependent `transferFrom`

ERC721 host:

- `ERC721_TRANSFER_SCOPE`
  - gates `transferFrom`, both `safeTransferFrom` overloads, `mint`, `safeMint`,
    and `burn`
- `ERC721_APPROVAL_SCOPE`
  - gates `approve` and `setApprovalForAll`

Metadata updates on the ERC721 host are role-gated but not controlled by the
transfer or approval pause scopes.

## Storage And Upgrade Assumptions

The token facets use fixed storage slots:

- ERC20: `keccak256("auralis.token.erc20.storage")`
- ERC721: `keccak256("auralis.token.erc721.storage")`

Those layouts are separate, so ERC20 and ERC721 state do not collide at the
storage level. The repo still deploys them as separate hosts because the raw
selector surfaces collide.

Hosted token state lives in the diamond, not in the facet contract bytecode.
That means the supported replace/remove/re-add flows preserve state as long as:

- the replacement facet preserves the same storage layout
- the relevant selectors are reinstalled
- the upgrade does not rely on re-initialization

Current hardening coverage explicitly validates persistence for:

- ERC20 balances, allowances, Permit nonces, roles, and pause state
- ERC721 ownership, approvals, operator approvals, metadata, roles, and pause
  state

## Selector Ownership Model

For the reference token hosts:

- `DiamondCutFacet` owns `diamondCut`
- `DiamondLoupeFacet` owns loupe and ownership-introspection selectors
- the token facet owns its token selectors
- the token facet also owns the shared control selectors installed for that host

In practice, that means the token facet owns selectors such as:

- `supportsInterface(bytes4)`
- `hasRole(bytes32,address)`
- `grantRole(bytes32,address)`
- `pauseScope(bytes32)`
- `unpauseScope(bytes32)`
- `scopePaused(bytes32)`
- token role and scope getter selectors

That selector ownership model is part of the supported upgrade story. When a
token facet is replaced, the shared control selectors move with it for that
host.

## Supported Interface Surface

### ERC20 Host

The ERC20 host exposes:

- ERC20 core + metadata
- `IERC20Permit`
- hosted ERC20 facet admin hooks
- `IAccessControl`
- `IPausable`
- `IERC165`

### ERC721 Host

The ERC721 host exposes:

- ERC721 core + metadata
- hosted ERC721 facet admin hooks
- `IAccessControl`
- `IPausable`
- `IERC165`

## Safety Notes For Reviewers

- Separate-host deployment is the supported model in this repository.
- No selector namespacing is used.
- Re-initialization is not part of replace/remove/re-add flows.
- Facet upgrades must preserve storage layout and hosted selector intent.
- Shared control selectors are treated as part of the token host surface, not as
  independent infrastructure selectors.

## Validation References

The implemented token-host model is covered by:

- `test/DiamondTokenDeploymentIntegration.t.sol`
- `test/DiamondTokenHostHardening.t.sol`
- `test/DiamondErc20HostInvariant.t.sol`
- `test/DiamondErc721HostInvariant.t.sol`
