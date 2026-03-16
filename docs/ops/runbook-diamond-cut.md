# Runbook: Diamond Cut Execution

Use this runbook for production-facing selector upgrades on the diamond core.

## Preconditions

- Upgrade is reviewed and approved through your governance process.
- Caller is the current diamond owner (`IERC173.owner()`).
- Facet bytecode, init target, and init calldata are finalized.

## Pre-Cut Checklist

1. Build the exact selector diff (`add`, `replace`, `remove`).
2. Confirm every add/replace facet target has runtime code.
3. Confirm every remove action uses `facetAddress = address(0)`.
4. Confirm no empty selector lists exist.
5. If using init delegatecall:
   - `init` target has code.
   - calldata is non-empty.
   - init routine is idempotent and storage-safe.
6. Rehearse the cut path locally with:
   - `bash script/run-local-diamond-upgrade-rehearsal.sh`

## Execution

1. Submit `diamondCut(cut, init, initCalldata)` from owner account.
2. Wait for transaction finality.
3. Record tx hash and emitted `DiamondCut` payload.

## Post-Cut Verification

1. Read loupe state:
   - `facetAddresses()`
   - `facetFunctionSelectors(address)`
   - `facetAddress(selector)`
2. Verify expected selector ownership matches planned diff.
3. Run smoke checks on critical external functions.
4. For broader branch validation, run:
   - `bash script/run-local-system-hardening.sh`
5. Verify owner is unchanged unless ownership transfer was planned.

## Failure Handling

- If the cut reverts, inspect revert reason and payload assumptions first.
- Do not submit ad-hoc follow-up cuts without updating the reviewed diff.
- If a bad cut succeeds, execute a reviewed corrective cut immediately and
  consider pausing user-facing flows if available.
