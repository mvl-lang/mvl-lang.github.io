# Testing Suite

MVL's testing philosophy: **the compiler handles well-formedness, tests handle validation.**

The eleven requirements eliminate entire categories of bugs at compile time. What remains is semantic correctness — does the code do what the specification says? That's what tests verify.

MVL provides five testing mechanisms as language-level features, not bolted-on frameworks.

---

## The Testing Pyramid

```
                    ┌─────────────┐
                    │   Fuzzing   │  ← Find edge cases you didn't imagine
                    ├─────────────┤
                    │    MC/DC    │  ← Prove decision coverage for safety-critical code
                    ├─────────────┤
                    │     BDD     │  ← Validate against specifications
                    ├─────────────┤
                    │  Property   │  ← Prove invariants hold for all inputs
                    ├─────────────┤
                    │    Unit     │  ← Verify individual functions
                    └─────────────┘
```

Each layer catches different failure modes. Use all five for critical systems.

---

## 1. Unit Tests

Internal test functions verify individual functions. They have access to private APIs and live alongside the code they test.

```mvl
fn add(a: Int, b: Int) -> Int {
    a + b
}

test fn test_add_positive() -> Unit {
    assert_eq(add(2, 3), 5)
}

test fn test_add_negative() -> Unit {
    assert_eq(add(-1, 1), 0)
}

test fn test_add_overflow() -> Unit {
    // Refinement types prevent overflow at compile time
    // This test verifies the happy path
    assert_eq(add(1000000, 1000000), 2000000)
}
```

Run with `mvl test`:

```bash
$ mvl test src/math.mvl
Running 3 tests...
  test_add_positive ... ok
  test_add_negative ... ok
  test_add_overflow ... ok

3 passed, 0 failed
```

### External Tests

Tests in `*_test.mvl` files test only the public API. They survive code regeneration — when the implementation is regenerated from specs, external tests remain as permanent evidence.

```mvl
// math_test.mvl — tests public API only
use math.{add}

test fn test_add_public() -> Unit {
    assert_eq(add(1, 2), 3)
}
```

---

## 2. Property-Based Testing

Property tests verify invariants hold for *all* inputs, not just examples. MVL generates random inputs and searches for counterexamples.

```mvl
use std.test.{property, forall}

property fn add_commutative() -> Bool {
    forall |a: Int, b: Int| {
        add(a, b) == add(b, a)
    }
}

property fn add_associative() -> Bool {
    forall |a: Int, b: Int, c: Int| {
        add(add(a, b), c) == add(a, add(b, c))
    }
}

property fn sort_preserves_length() -> Bool {
    forall |xs: List[Int]| {
        sort(xs).len() == xs.len()
    }
}

property fn sort_is_sorted() -> Bool {
    forall |xs: List[Int]| {
        is_sorted(sort(xs))
    }
}
```

Run with `mvl test --property`:

```bash
$ mvl test --property src/math.mvl
Running 4 property tests (100 iterations each)...
  add_commutative ... ok (100/100)
  add_associative ... ok (100/100)
  sort_preserves_length ... ok (100/100)
  sort_is_sorted ... ok (100/100)

4 passed, 0 failed
```

### Shrinking

When a property fails, MVL automatically shrinks the counterexample to the minimal failing case:

```bash
$ mvl test --property src/buggy.mvl
  buggy_property ... FAILED
    Counterexample (shrunk): a = 0, b = -1
    Original: a = 847291, b = -5829104
```

---

## 3. BDD Scenarios

Behavior-Driven Development scenarios express tests in Given-When-Then format, directly mapping to specifications.

```mvl
use std.test.{scenario, given, when, then}

scenario fn user_login() -> Unit {
    given("a registered user with email 'alice@example.com'")
    let user: User = create_user("alice@example.com", "password123");
    
    when("they attempt to login with correct credentials")
    let result: Result[Session, AuthError] = login("alice@example.com", "password123");
    
    then("they receive a valid session token")
    assert(result.is_ok());
    assert(result.unwrap().token.len() > 0)
}

scenario fn user_login_wrong_password() -> Unit {
    given("a registered user with email 'alice@example.com'")
    let user: User = create_user("alice@example.com", "password123");
    
    when("they attempt to login with wrong password")
    let result: Result[Session, AuthError] = login("alice@example.com", "wrongpass");
    
    then("they receive an authentication error")
    assert(result.is_err());
    assert_eq(result.unwrap_err(), AuthError::InvalidCredentials)
}
```

BDD tests serve as executable specifications. The Given-When-Then structure maps directly to spec requirements, enabling traceability from spec to test to implementation.

---

## 4. MC/DC Coverage

Modified Condition/Decision Coverage is the most stringent structural coverage metric, required by:

- **DO-178C** at DAL-A (catastrophic failure in aviation)
- **ISO 26262** at ASIL-D (automotive safety)  
- **EN 50128** at SIL 4 (railway systems)

MC/DC proves that every boolean condition independently affects the decision outcome.

```mvl
fn authorize(is_admin: Bool, is_owner: Bool, is_public: Bool) -> Bool {
    is_admin || (is_owner && is_public)
}
```

For this function, MC/DC requires test cases showing:

| is_admin | is_owner | is_public | result | Independence shown for |
|----------|----------|-----------|--------|------------------------|
| T | F | F | T | is_admin |
| F | F | F | F | is_admin |
| F | T | T | T | is_owner |
| F | F | T | F | is_owner |
| F | T | T | T | is_public |
| F | T | F | F | is_public |

Run with `mvl mcdc`:

```bash
$ mvl mcdc src/auth.mvl
MC/DC Analysis
==============
Decision at auth.mvl:2 — 3 clauses (is_admin || (is_owner && is_public))

Coverage: 3/3 clauses have independence pairs
  is_admin:   (T,F,F)->T vs (F,F,F)->F
  is_owner:   (F,T,T)->T vs (F,F,T)->F  
  is_public:  (F,T,T)->T vs (F,T,F)->F

PASS: 100% MC/DC coverage
```

### Why MC/DC Matters

For safety-critical systems, branch coverage isn't enough. A function like `if a && b && c` has only two branches (true/false) but eight input combinations. MC/DC proves you've tested the *independence* of each condition — that flipping any single input can flip the output.

---

## 5. Fuzzing

Fuzz testing generates random, malformed, and adversarial inputs to find crashes, hangs, and unexpected behavior. MVL's fuzzer is coverage-guided — it tracks which code paths inputs exercise and mutates toward unexplored paths.

```mvl
use std.fuzz.{fuzz, FuzzInput}

fuzz fn fuzz_parser(input: FuzzInput) -> Unit {
    let bytes: List[Byte] = input.bytes(0, 1024);
    let text: String = String::from_utf8_lossy(bytes);
    
    // This should never panic, regardless of input
    let _ = parse_config(text);
}

fuzz fn fuzz_deserialize(input: FuzzInput) -> Unit {
    let json: String = input.ascii_string(0, 4096);
    
    // Deserialization must handle any input gracefully
    match deserialize(json) {
        Ok(_) => (),
        Err(_) => (),  // errors are fine, panics are not
    }
}
```

Run with `mvl fuzz`:

```bash
$ mvl fuzz src/parser.mvl --duration 60s
Fuzzing fuzz_parser...
  Executions: 1,247,892
  Coverage: 847 edges
  Crashes: 0
  Timeouts: 0
  Duration: 60.0s

No issues found.
```

### When to Fuzz

Fuzz anything that processes untrusted input:

- Parsers (JSON, XML, config files, protocols)
- Deserializers
- Network handlers
- File format readers
- Compression/decompression
- Cryptographic operations

---

## Test Organization

MVL encourages co-locating tests with code:

```
src/
├── auth.mvl           # implementation
├── auth_test.mvl      # external tests (public API)
├── parser.mvl
├── parser_test.mvl
└── internal/
    └── crypto.mvl     # internal module with inline test fns
```

### Internal vs External Tests

| Type | Location | Access | Survives regeneration |
|------|----------|--------|----------------------|
| Internal (`test fn`) | Same file | Private API | No |
| External (`*_test.mvl`) | Separate file | Public API only | Yes |

**Rule of thumb:** Use internal tests for implementation details, external tests for behavior contracts.

---

## Assurance Report

`mvl assurance` generates a report showing test coverage mapped to specification requirements:

```bash
$ mvl assurance
Assurance Report
================
Spec: 004-authentication

  Property 1: User login [MUST]
    Implementation: src/auth.mvl::login
    Tests:
      - auth_test.mvl::test_login_success
      - auth_test.mvl::test_login_wrong_password
      - auth_test.mvl::scenario_user_login
    Coverage: 3 tests, 94% line coverage

  Property 2: Session expiry [MUST]
    Implementation: src/auth.mvl::check_session
    Tests:
      - auth_test.mvl::test_session_valid
      - auth_test.mvl::test_session_expired
      - auth_test.mvl::property_session_expiry
    Coverage: 3 tests, 100% line coverage

Overall: 12/12 requirements covered, 97% line coverage
```

This closes the loop: spec requirements → implementation → tests → evidence.
