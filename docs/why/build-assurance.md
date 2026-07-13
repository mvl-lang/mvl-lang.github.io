# Build-Time Assurance

Every MVL build produces not just an executable, but **evidence**. SBOM generation, license validation, extern rationale requirements, and supply chain audit are built into the toolchain — not optional add-ons.

---

## The Three-Layer Module System

Before diving into supply chain, understand how MVL organizes code:

```
┌─────────────────────────────────────────────────────────────┐
│  std.*    Standard library — ships with the compiler        │
│           Full 11-requirement verification                  │
│           No extern blocks (pure MVL)                       │
├─────────────────────────────────────────────────────────────┤
│  pkg.*    Extended packages — third-party libraries         │
│           Full 11-requirement verification on public API    │
│           May contain extern blocks in internal/            │
├─────────────────────────────────────────────────────────────┤
│  local    Your project code                                 │
│           Full 11-requirement verification                  │
│           May contain extern blocks with rationale          │
└─────────────────────────────────────────────────────────────┘
```

### `std.*` — Standard Library

The standard library ships with the compiler. Pure MVL, no extern blocks, fully verified.

```rust
use std.io.{println, read_file}
use std.ifc.{Tainted, trust}
use std.csv.{parse_with_headers}
use std.log.{Logger, default_logger}
use std.args.{parse_args, required}
```

**Available modules:**

| Module | Purpose |
|--------|---------|
| `std.io` | Console I/O, file operations |
| `std.ifc` | Information flow control primitives |
| `std.csv` | CSV parsing and encoding |
| `std.json` | JSON parsing and encoding |
| `std.log` | Structured logging |
| `std.args` | Command-line argument parsing |
| `std.test` | Testing primitives |
| `std.fuzz` | Fuzzing support |
| `std.runtime` | Package info, build metadata |

### `pkg.*` — Extended Packages

Third-party packages from git repositories. The package author takes responsibility for the trust boundary between their `extern` code and the verified API.

```rust
use pkg.http.{Server, Request, Response}
use pkg.sqlite.{Connection, Query}
use pkg.tls.{TlsConfig}
```

**Package structure:**

```
mvl_http/
├── mvl.toml                  # manifest with license, version, extern-rationale
├── src/
│   ├── server.mvl            # public API — full verification
│   ├── request.mvl           # Request with Tainted body
│   ├── response.mvl          # Response with refined status
│   └── internal/
│       └── ffi.mvl           # extern "rust" { hyper } — hidden from users
└── bridge.rs                 # Rust implementations
```

**The rule:** `internal/` is a hard boundary. User code cannot import `pkg.http.internal.*` — the compiler rejects it at resolve time.

### Local Modules

Your project code. Same verification as std, but you can add extern blocks when needed.

```rust
// src/main.mvl
use std.io.println
use pkg.http.{Server, Request, Response}
use auth.{validate_token}        // local module

fn main() -> Unit ! Console + Net {
    // ...
}
```

---

## Package Manifest (`mvl.toml`)

Every package declares its identity, dependencies, and — critically — why it needs native code.

```toml
[package]
name = "http"
version = "1.2.0"
license = "MIT"
requires-mvl = ">=0.24.0"

# Required when any extern block exists
extern-rationale = "wraps hyper for async HTTP; no pure-MVL HTTP stack yet"

[dependencies]
tls = { git = "https://github.com/lab271/mvl_tls", tag = "v0.4.0" }

[native]
# Rust crates used in bridge.rs — appears in SBOM
hyper = "1.0"
tokio = { version = "1.0", features = ["full"] }

[c-native]
# C libraries linked — appears in SBOM
openssl = "3.0"
```

### Required Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Always | Package identifier |
| `version` | Always | Semver version |
| `license` | Always | SPDX license identifier |
| `requires-mvl` | Always | Compiler version range |
| `extern-rationale` | When extern blocks exist | Why native code is necessary |

### The Extern Rationale Requirement

If your package contains any `extern "rust"` or `extern "c"` block, `mvl build` requires `extern-rationale` in the manifest. This is not bureaucracy — it's forced documentation of the trust boundary.

```toml
# Bad: just "we need it"
extern-rationale = "uses native code"

# Good: explains why pure MVL isn't sufficient
extern-rationale = "wraps hyper for async HTTP; no pure-MVL HTTP stack yet"
```

The rationale appears in SBOM output and audit reports. Reviewers can assess: is this a legitimate need, or a shortcut?

---

## Lock File (`mvl.lock`)

Deterministic, reproducible builds. Every resolved dependency is pinned to an exact commit and hash.

```toml
[[package]]
name = "http"
version = "1.2.0"
git = "https://github.com/lab271/mvl_http"
tag = "v1.2.0"
commit = "a1b2c3d4e5f6..."
hash = "sha256:..."

[[package]]
name = "tls"
version = "0.4.0"
git = "https://github.com/lab271/mvl_tls"
tag = "v0.4.0"
commit = "f6e5d4c3b2a1..."
hash = "sha256:..."
```

### Hash Verification

`mvl install` verifies the SHA-256 hash before extracting any package. Hash mismatch = hard error, no partial install.

```bash
$ mvl install
error: hash mismatch for package 'http'
  expected: sha256:a1b2c3...
  got:      sha256:x9y8z7...
  
This may indicate a compromised package or registry.
```

---

## SBOM Generation

`mvl sbom` generates a Software Bill of Materials in CycloneDX or SPDX format. No network access required — works entirely from `mvl.toml` + `mvl.lock`.

```bash
$ mvl sbom --format cyclonedx
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "components": [
    {
      "type": "library",
      "name": "http",
      "version": "1.2.0",
      "purl": "pkg:mvl/http@1.2.0",
      "licenses": [{"license": {"id": "MIT"}}],
      "externalReferences": [
        {"type": "vcs", "url": "https://github.com/lab271/mvl_http"}
      ]
    },
    {
      "type": "library",
      "name": "hyper",
      "version": "1.0",
      "purl": "pkg:cargo/hyper@1.0",
      "description": "Native dependency of http"
    }
  ]
}
```

### What's Included

| Source | Included | PURL format |
|--------|----------|-------------|
| MVL dependencies | Yes | `pkg:mvl/<name>@<version>` |
| Native (Rust) dependencies | Yes | `pkg:cargo/<name>@<version>` |
| C native dependencies | Yes | `pkg:generic/<name>@<version>` |
| Transitive dependencies | Yes | Recursively resolved |

### Output Formats

```bash
mvl sbom --format cyclonedx   # CycloneDX 1.5 JSON
mvl sbom --format spdx        # SPDX 2.3 JSON
mvl sbom --output sbom.json   # Write to file instead of stdout
```

---

## License Validation

`mvl audit --license` checks that all dependencies have compatible licenses.

```bash
$ mvl audit --license
License Audit
=============
Package       Version  License   Status
http          1.2.0    MIT       OK
tls           0.4.0    Apache-2.0 OK
crypto        0.1.0    GPL-3.0   WARNING: copyleft license

1 warning: GPL-3.0 in dependency chain may require source disclosure
```

### License Policy

Configure acceptable licenses in `mvl.toml`:

```toml
[policy]
allowed-licenses = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"]
denied-licenses = ["GPL-3.0", "AGPL-3.0"]
```

`mvl build` fails if a dependency violates the policy.

---

## Supply Chain Audit

`mvl audit --supply-chain` performs a comprehensive supply chain analysis:

```bash
$ mvl audit --supply-chain
Supply Chain Audit
==================

Dependencies: 4 direct, 12 transitive
Native code: 3 packages contain extern blocks

Extern Rationale Check:
  http    ✓ "wraps hyper for async HTTP; no pure-MVL HTTP stack yet"
  tls     ✓ "wraps rustls for TLS 1.3; crypto must be native"
  sqlite  ✓ "wraps sqlite3 C library; no pure-MVL SQL engine"

Hash Verification:
  All 16 packages verified against mvl.lock

Vulnerability Scan:
  No known vulnerabilities in dependency tree

PASS: supply chain audit complete
```

### What's Checked

1. **Extern rationale** — Every extern block has documentation
2. **Hash integrity** — All packages match their recorded hashes
3. **License compliance** — All licenses match policy
4. **Known vulnerabilities** — Cross-reference with advisory databases
5. **Dependency freshness** — Flag outdated packages

---

## Runtime Package Info

At runtime, your program knows its own supply chain via `std.runtime`:

```rust
use std.runtime.{package_info, PackageInfo}
use std.log.{Logger, default_logger}

fn main() -> Unit ! Log {
    let logger: Logger = default_logger();
    
    // Log package manifest at startup
    let info: PackageInfo = package_info();
    logger.info("startup", {
        "name": info.name,
        "version": info.version,
        "purl": info.purl,
        "dependencies": info.dependencies.len().to_string(),
    })
}
```

Output:

```json
{"level":"info","msg":"startup","name":"myapp","version":"0.1.0","purl":"pkg:mvl/myapp@0.1.0","dependencies":"4"}
```

This enables runtime correlation between logs and SBOM — you can trace any log entry back to its exact build.

---

## The Evidence Chain

Every MVL build produces artifacts that form an audit trail:

```
Source Code
    ↓
mvl build
    ↓
├── Binary (executable)
├── SBOM (cyclonedx.json)
├── Assurance Report (requirements coverage)
├── Lock File (exact versions + hashes)
└── Audit Log (license + supply chain checks)
```

For regulated industries (finance, healthcare, aviation), this evidence chain satisfies compliance requirements without additional tooling.

**The compiler doesn't just build your code. It builds the proof that your code is what you say it is.**
