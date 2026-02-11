# Shared Libraries

Use this directory for cross-module libraries that are intentionally shared
across multiple domains (access, vault, oracle, etc.).

Module-specific libraries should stay close to their module code (for example,
`src/access/storage/`) to keep ownership and reasoning localized.
