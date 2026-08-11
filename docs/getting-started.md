# Getting Started

## Your First MVL Program

Create `hello.mvl`:

```mvl
fn main() -> Unit ! Console {
    println("Hello, verified world!")
}
```

Run it:

```bash
mvl run hello.mvl
# Hello, verified world!
```

The `! Console` declares that this function has a console side effect. MVL tracks all effects in function signatures — nothing is hidden.

## Your First Verification

Create `positive.mvl`:

```mvl
fn double(x: Int where x > 0) -> Int where self > 0 {
    x * 2
}

fn main() -> Unit ! Console {
    let result: Int = double(5);
    println(result.to_string())
}
```

Check it:

```bash
mvl check positive.mvl
# ✓ All 11 requirements verified
```

The compiler **proves** at compile time that:

- `double(5)` satisfies `x > 0` (refinement type)
- The return value satisfies `self > 0` (return refinement)
- `result` is always positive — no runtime check needed

Try breaking it — replace the body of `main` with:

```mvl
fn main() -> Unit ! Console {
    let result: Int = double(-1);  // ← compile error!
}
```

```
error[REQ10]: refinement predicate violated
 --> positive.mvl:6:23
  |
6 |     let result: Int = double(-1);
  |                       ^^^^^^^^^^ argument to `double` violates refinement `self > 0`
```

## Assurance Report

```bash
mvl assurance positive.mvl --verbose
```

This generates a verification report showing which requirements were proven, how many proofs were discharged, and the evidence trail. Useful for compliance (DO-178C, IEC 61508, ISO 26262).

## Complete Example

This example demonstrates 7 of MVL's 11 compile-time requirements in a realistic banking scenario:

```mvl
// MVL example demonstrating 7 of the 11 compile-time requirements.

use std.ifc.{Secret, classify, release}
use std.log.{Logger, default_logger}

// ── Core functions ────────────────────────────────────────────────────────────

/// Withdraw funds — returns remaining balance, or None if insufficient.
///
/// Requirements proven:
///   - Req 10 (Refinements): amount > 0, balance >= 0 enforced at every call
///   - Req 8 (Totality): partial — may return None
///   - Req 4 (No Null): returns Option, not nullable
partial fn withdraw(
    balance: Int where self >= 0,
    amount:  Int where self > 0,
) -> Option[Int] {
    if balance < amount {
        None
    } else {
        // Compiler proves: remaining >= 0 (from balance >= amount).
        Some(balance - amount)
    }
}

/// Transfer between accounts. Because `withdraw` is `partial`, so is `transfer`.
///
/// Requirements proven:
///   - Req 5 (Error visibility): every failure mode lives in the return type
partial fn transfer(
    from_balance:    Int where self >= 0,
    transfer_amount: Int where self > 0,
) -> Result[Int, String] {
    match withdraw(from_balance, transfer_amount) {
        Some(new_balance) => Ok(new_balance),
        None              => Err("Transfer failed: insufficient funds"),
    }
}

// ── Loops: partial (while) vs total (while ... decreases) ─────────────────────

/// Count transactions until the balance is exhausted — partial, no proven bound.
partial fn count_until_exhausted(
    balance:   Int where self >= 0,
    deduction: Int where self > 0,
) -> Int {
    let remaining: ref Int = balance;
    let count:     ref Int = 0;
    while remaining >= deduction {
        remaining = remaining - deduction;
        count     = count + 1;
    }
    count
}

/// Sum the first n transaction amounts — total, guaranteed to terminate.
///
/// Requirements proven:
///   - Req 8 (Totality): the `decreases n - i` clause proves termination
total fn sum_transactions(
    amounts: List[Int],
    n:       Int where self >= 0,
) -> Int {
    let sum: ref Int = 0;
    let i:   ref Int = 0;
    while i < n decreases n - i {
        sum = sum + amounts.get(i).unwrap_or(0);
        i   = i + 1;
    }
    sum
}

// ── Information Flow Control: audited disclosure of a Secret ──────────────────

/// Mask an account ID for safe logging — keeps the last 4 characters only.
///
/// Requirements proven:
///   - Req 11 (IFC): `relabel release` crosses the Secret → bare boundary,
///     with an audit tag recorded in the assurance report.
total fn mask_account_id(account_id: Secret[String]) -> String {
    let id: String = relabel release(account_id, "MASKED-FOR-LOGGING");
    let n:  Int    = id.len();
    if n <= 4 {
        "****"
    } else {
        "****".concat(id.substring(n - 4, n))
    }
}

/// Log account activity safely — masks the secret before the log call.
total fn log_account_activity(
    account_id: Secret[String],
    action: String,
) -> Unit ! Log {
    let masked: String = mask_account_id(account_id);
    let logger: Logger = default_logger();
    logger.info(action, {"account": masked})
}

// ── Main ──────────────────────────────────────────────────────────────────────

partial fn main() -> Unit ! Log {
    // `relabel classify` audit-tags the ingestion of public data into a
    // Secret label. The audit tag appears in the assurance report so every
    // point where bare data becomes Secret is traceable.
    let alice_id: Secret[String] = relabel classify("ACCT-1234-5678-9012", "ACCT-INGEST");
    let bob_id:   Secret[String] = relabel classify("ACCT-9876-5432-1098", "ACCT-INGEST");

    // Log activity with a masked account ID (safe — uses `relabel release`).
    log_account_activity(alice_id, "Withdrawal initiated");
    log_account_activity(bob_id,   "Awaiting deposit");

    // Business logic on non-Secret data — no implicit flow into logging.
    let alice_balance: Int = 1000;
    let tx_count:      Int = count_until_exhausted(500, 75);   // partial: no proven bound
    let amounts: List[Int] = [10, 20, 30, 40, 50];
    let sum:           Int = sum_transactions(amounts, 3);     // total: `decreases` proves termination

    let logger: Logger = default_logger();
    logger.info("Batch summary", {
        "balance":  alice_balance.to_string(),
        "tx_count": tx_count.to_string(),
        "sum":      sum.to_string(),
    });

    match transfer(alice_balance, 100) {
        Ok(final_balance) => logger.info("Transfer complete", {"final": final_balance.to_string()}),
        Err(msg)          => logger.error(msg, {"reason": "insufficient"}),
    }
}
```

### Properties Demonstrated

| Req | Name | How It's Shown |
|-----|------|----------------|
| 3 | No Null | `Option[Int]`, `Result[Int, String]` — explicit handling required |
| 5 | Bounds Safety | `for i in 0..n` with `n <= amounts.len()` — compiler proves access is safe |
| 6 | Ownership | Values consumed, no aliasing of `from`/`to` possible |
| 8 | Termination | `partial fn` + `while` vs `total fn` + `for` with `decreases` clause |
| 9 | Effect Tracking | `! Console` declared — `log_info`/`log_error` calls are tracked |
| 10 | Refinement Types | `amount > 0`, `balance >= 0`, `n <= amounts.len()` — proven at compile time |
| 11 | Information Flow | `Secret[String]` blocked from Console; `relabel trust()` with audit tag |

### Key Patterns

**Totality and loops:**

- `partial fn` + `while`: No termination guarantee — compiler accepts but doesn't prove termination
- `total fn` + `for`: Bounded iteration with `decreases` clause — compiler proves termination

**Information Flow Control:**

- `Secret[String]` cannot flow to any effect (Console, FileWrite, Net)
- `relabel trust(secret, "audit_tag")` crosses the IFC boundary
- The audit tag appears in the assurance report — every trust boundary is documented

**The commented line `// log_info(account_id)` would be a compile-time error:**

```
error[E0011]: information flow violation
  --> banking.mvl:32:9
   |
32 |         log_info(account_id)
   |         ^^^^^^^^^^^^^^^^^^^^ Secret[String] cannot flow to effect Console
   |
   = help: use `relabel trust(account_id, "reason")` to cross the boundary
   = note: this will be recorded in the assurance report
```

## Next Steps

- [The 11 Properties](language/properties.md) — what the compiler proves
- [Design Principles](language/principles.md) — why MVL is built this way
- [Examples](language/examples.md) — real programs with verification
