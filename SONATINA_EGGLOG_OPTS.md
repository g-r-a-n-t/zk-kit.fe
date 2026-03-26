# Sonatina Egglog Optimization Plan for ZK Workloads

Plan for adding egglog rewrite rules and supporting infrastructure to
Sonatina that benefit field-arithmetic-heavy code (Poseidon, Merkle trees,
PLONK/Groth16 verifiers). Based on analysis of the rosetta-fe codebase at
`/home/micah/hacker-stuff-2023/fe-stuff/rosetta-fe/`.

## Current State

**rules.egg** location:
`sonatina/crates/codegen/src/optim/egraph/rules.egg`

**Existing EVM modular arithmetic rules** (lines 183-191):
```lisp
(rewrite (EvmAddMod x y (Const (i256 0) ty)) (Const (i256 0) ty))
(rewrite (EvmMulMod x y (Const (i256 0) ty)) (Const (i256 0) ty))
(rewrite (EvmExp x (Const (i256 0) ty)) (Const (i256 1) ty))
```

Only zero-modulus and zero-exponent cases are handled today. No identity
rules, no commutativity, no strength reduction for `EvmAddMod`/`EvmMulMod`.

**Relevant Expr nodes** (from `expr.egg`):
```lisp
(EvmAddMod Expr Expr Expr)   ; addmod(a, b, modulus)
(EvmMulMod Expr Expr Expr)   ; mulmod(a, b, modulus)
(EvmExp Expr Expr)            ; exp(base, exponent)
```

**Pass config** (from `pass.rs`):
- Rules run for **4 iterations** (`(run 4)`)
- Pure expressions only; side-effecting instructions are opaque `SideEffectResult`
- Elaboration checks dominance before substituting

---

## Tier 1: Pure Algebraic Rules (no new infrastructure)

These are direct rewrites that are always correct. Add them to `rules.egg`
after the existing EVM Peepholes section (line 201).

### 1a. EvmAddMod identities

```lisp
; --- EvmAddMod identities ---
; addmod(x, 0, m) = x  (when m != 0, already guaranteed since m=0 case returns 0)
(rewrite (EvmAddMod x (Const (i256 0) ty) m) x)
(rewrite (EvmAddMod (Const (i256 0) ty) x m) x)

; addmod commutativity
(rewrite (EvmAddMod x y m) (EvmAddMod y x m))

; addmod(x, x, m) = mulmod(x, 2, m)  [enables further mulmod rules]
(rule ((= e (EvmAddMod x x m)) (= ty (expr-type x)))
      ((union e (EvmMulMod x (Const (i256 2) ty) m))))
```

**Why**: In rosetta_poseidon `lib.fe:23-27`, every round starts with
`addmod(state[i], C[rc], PRIME)`. When constant propagation resolves
`C[rc]` to zero (which happens for some round constants), the addmod
becomes a no-op. The commutativity rule lets GVN find common
subexpressions across reordered field additions.

**Caution**: The `addmod(x, 0, m) = x` rule assumes `x < m` (i.e., x is
already a valid field element). This is true for all field arithmetic in
zk-kit code because every value is a prior addmod/mulmod output, but it's
technically only correct when `x < m`. If Sonatina ever uses addmod for
non-field contexts, this rule could be wrong. Consider gating on `m` being
a known prime constant if this is a concern.

*Actually, the EVM spec says addmod(x, 0, m) = (x + 0) % m = x % m.
If x >= m, this is NOT equal to x. So this rule is only safe when we
know x < m. Skip this rule unless range analysis is available, OR
restrict it to cases where x is itself an EvmAddMod/EvmMulMod output
(which is always < m):*

```lisp
; Safe version: addmod(addmod_result, 0, m) = addmod_result
; (any addmod/mulmod output is already reduced mod m)
(rule ((= e (EvmAddMod x (Const (i256 0) ty) m))
       (= x (EvmAddMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmAddMod x (Const (i256 0) ty) m))
       (= x (EvmMulMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmAddMod (Const (i256 0) ty) x m))
       (= x (EvmAddMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmAddMod (Const (i256 0) ty) x m))
       (= x (EvmMulMod _ _ m)))
      ((union e x)))
```

### 1b. EvmMulMod identities

```lisp
; --- EvmMulMod identities ---
; mulmod(x, 1, m) = x  (same caveat as addmod: only when x < m)
; Safe version: gate on x being a prior modular op result
(rule ((= e (EvmMulMod x (Const (i256 1) ty) m))
       (= x (EvmAddMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmMulMod x (Const (i256 1) ty) m))
       (= x (EvmMulMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmMulMod (Const (i256 1) ty) x m))
       (= x (EvmAddMod _ _ m)))
      ((union e x)))
(rule ((= e (EvmMulMod (Const (i256 1) ty) x m))
       (= x (EvmMulMod _ _ m)))
      ((union e x)))

; mulmod commutativity
(rewrite (EvmMulMod x y m) (EvmMulMod y x m))

; mulmod(x, 2, m) = addmod(x, x, m)
; Neutral on gas alone (both 8 gas), but creates addmod nodes that
; downstream lazy-reduction rules (Tier 2) can eliminate entirely.
(rule ((= e (EvmMulMod x (Const (i256 2) ty) m)) (= ty (expr-type x)))
      ((union e (EvmAddMod x x m))))
```

**Why**: The `mulmod(x, 1, m)` identity fires when constant propagation
resolves a multiplier to 1. The commutativity rule lets GVN deduplicate
`mulmod(a, b, P)` and `mulmod(b, a, P)` which can appear after inlining.

### 1c. EvmExp identities

```lisp
; --- EvmExp additional identities ---
; exp(x, 1) = x
(rewrite (EvmExp x (Const (i256 1) ty)) x)

; exp(1, y) = 1
(rewrite (EvmExp (Const (i256 1) ty) y) (Const (i256 1) ty))
```

**Why**: After inlining and const propagation, exponent or base may
resolve to 1.

### Where in rosetta-fe these fire

| Rule | rosetta-fe location | Frequency |
|---|---|---|
| addmod commutativity | poseidon round constant additions | GVN dedup |
| mulmod commutativity | poseidon sparse matrix multiply | GVN dedup |
| mulmod(x, 1, m) = x | possible after const prop | occasional |
| addmod(x, 0, m) = x | round constants that are 0 | occasional |
| exp(x, 1) = x | field.fe inv() edge case | rare |

---

## Tier 2: Lazy Modular Reduction (needs range analysis from PR #224)

These rules replace `EvmAddMod` with plain `Add` when overflow is
impossible. They depend on knowing that operands are less than some
bound. PR #224 adds `range_analysis.rs` — once that infrastructure can
feed range facts into egglog, these rules become possible.

### Required infrastructure

A new egglog relation to carry range facts:

```lisp
; In expr.egg, add:
; range-upper-bound: expr -> known upper bound (exclusive)
(function range-ub (Expr) i256 :merge (min old new))
```

The range analysis pass (or a bridge between it and the egraph) would
populate this relation. Key seed rules:

```lisp
; Any EvmAddMod/EvmMulMod output is < modulus
(rule ((= e (EvmAddMod _ _ (Const m ty))))
      ((set (range-ub e) m)))
(rule ((= e (EvmMulMod _ _ (Const m ty))))
      ((set (range-ub e) m)))

; Constants have exact range
(rule ((= e (Const v ty)))
      ((set (range-ub e) (+ v (i256 1)))))
```

### The actual lazy reduction rules

```lisp
; BN254 PRIME < 2^254. Two values each < PRIME sum to < 2^255 < 2^256.
; So addmod(x, y, P) = add(x, y) when both x, y < P and P < 2^254.
;
; We express this as: if both operands have range-ub <= m, and m fits
; in 254 bits (i.e., m < 2^254), then the sum fits in 256 bits.

(rule ((= e (EvmAddMod x y (Const m ty)))
       (range-ub x x_ub)
       (<= x_ub m)
       (range-ub y y_ub)
       (<= y_ub m)
       ; m < 2^254 ensures x + y < 2^255 < 2^256 (no overflow)
       (< m (i256 0x4000000000000000000000000000000000000000000000000000000000000000)))
      ((union e (Add x y))))
```

**Gas impact**: Each `ADDMOD` -> `ADD` saves 5 gas (ADDMOD=8, ADD=3).
In Poseidon's sparse matrix multiply (lib.fe:58-64), there are 2
intermediate addmods per partial round * 57 partial rounds = 114
applications = **570 gas saved per Poseidon hash**.

Over a 32-level Merkle proof calling Poseidon at each level:
**~18,000 gas saved**.

### Chain optimization (deferred reduction)

When three field elements are summed, we can defer reduction:

```lisp
; add(x, y) + z is still safe if all three < P and P < 2^253
; (since x + y < 2^255, and (x+y) + z < 2^256)
(rule ((= e (EvmAddMod (Add x y) z (Const m ty)))
       (range-ub x x_ub) (<= x_ub m)
       (range-ub y y_ub) (<= y_ub m)
       (range-ub z z_ub) (<= z_ub m)
       (< m (i256 0x2000000000000000000000000000000000000000000000000000000000000000)))
      ((union e (Add (Add x y) z))))
```

This directly optimizes the Poseidon MDS matrix multiply pattern in
`mix()` (lib.fe:101-106), which sums three mulmod results with nested
addmod calls.

---

## Tier 3: If-Conversion (needs phi-to-branch linkage in egraph)

### Goal

Turn diamond-shaped CFGs into branchless `select` operations:

```
; Before: branch cond -> blockA (x = ...) + blockB (y = ...) -> merge (phi [x, y])
; After:  select(cond, x, y) — no branch
```

### Where it fires in rosetta-fe

`rosetta_merkle/src/merkle_proof.fe:21-32`:
```fe
if hash < sibling {
    ops::mstore(scratch, hash)
    ops::mstore(scratch + 32, sibling)
} else {
    ops::mstore(scratch, sibling)
    ops::mstore(scratch + 32, hash)
}
```

This compiles to a diamond CFG with mstore side effects in both arms,
so it would NOT be caught by a pure-expression-only egraph rule.

The simpler case — a phi whose inputs are pure expressions guarded by a
branch — is the egglog-friendly version. But the Merkle swap involves
stores (side effects), which means it's better handled by a dedicated
IR pass rather than egglog.

### If egglog-expressible cases exist

For pure diamond phis (no side effects in branches), the approach would be:

1. **Extend the egraph encoding** (in `pass.rs` `func_to_egglog`):
   when a phi has exactly 2 predecessors and those predecessors form a
   diamond with a single branch instruction, emit a relation linking the
   phi to the branch condition:

   ```lisp
   ; New relation in expr.egg:
   (function phi-branch-cond (i64) Expr :merge old)
   ; phi_id -> the condition expression that selects pred 0 vs pred 1
   ```

2. **Add a Select node** to the Expr datatype in `expr.egg`:
   ```lisp
   (Select Expr Expr Expr)  ; (cond, true_val, false_val)
   ```

3. **Rewrite rule** in `rules.egg`:
   ```lisp
   (rule ((= e (PhiResult phi_id ty))
          (= 2 (phi-num-preds phi_id))
          (= cond (phi-branch-cond phi_id))
          (= t_val (phi-val phi_id 0))
          (= f_val (phi-val phi_id 1)))
         ((union e (Select cond t_val f_val))))
   ```

4. **EVM lowering**: The elaboration pass (or EVM codegen) lowers
   `Select(cond, a, b)` to: `xor(a, and(xor(a, b), sub(0, cond)))` or
   equivalent branchless sequence.

### Complexity estimate

- Extending `func_to_egglog` to detect diamond patterns and emit
  `phi-branch-cond`: ~50-80 lines of Rust
- Adding `Select` to expr.egg: 2 lines
- The egglog rule: 6 lines
- EVM lowering of Select in elaboration/codegen: ~30-50 lines
- Tests: ~100 lines

**This is the most invasive change** since it touches the egraph
encoding, not just rules.egg. Recommend implementing Tier 1 first and
evaluating Tier 3 separately with Sean.

---

## Tier 4: Future / Requires Discussion

### Const array folding

When loop unrolling (separate pass) produces `C[known_index]` where `C`
is a const array, fold to the literal. This is likely better handled by
SCCP (which already does const propagation) than by egglog. The egraph
doesn't currently encode array structure.

**Recommendation**: Verify that SCCP handles const array indexing after
loop unrolling. If it does, no egglog work needed. If not, SCCP is the
right place to add it (not egglog).

### Calldataload promotion

When a function receives a read-only array argument, skip the ABI-decode
copy and use `calldataload` directly. This is an ABI-layer optimization,
not an egraph concern.

### MCOPY lowering

Post-Cancun EVM instruction for bulk memory copies. This is instruction
selection in the EVM codegen backend, not an egraph concern.

---

## Testing Strategy

### For Tier 1 rules

Add tests to the existing egraph test suite in `pass.rs`. Each test
should:

1. Construct a minimal Sonatina IR function containing the pattern
2. Run the egraph pass
3. Assert the expected rewrite occurred

Example test patterns:

```rust
#[test]
fn test_mulmod_by_one() {
    // mulmod(addmod(a, b, P), 1, P) should simplify to addmod(a, b, P)
    // Build IR: %0 = addmod(%arg0, %arg1, PRIME)
    //           %1 = mulmod(%0, 1, PRIME)
    // After egraph: %1 should be unified with %0
}

#[test]
fn test_addmod_commutativity_gvn() {
    // addmod(a, b, P) and addmod(b, a, P) should unify
    // Build IR with both, verify one is eliminated
}

#[test]
fn test_mulmod_by_two_to_addmod() {
    // mulmod(x, 2, P) should become addmod(x, x, P)
}

#[test]
fn test_exp_by_one() {
    // exp(x, 1) should simplify to x
}
```

### For Tier 2 rules (once range analysis is wired up)

Test with actual BN254 prime constant:

```rust
const BN254_PRIME: &str = "0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001";

#[test]
fn test_lazy_reduction_two_field_elems() {
    // addmod(mulmod(a, b, P), mulmod(c, d, P), P)
    // Both mulmod outputs are < P, and P < 2^254
    // Should become: add(mulmod(a, b, P), mulmod(c, d, P))
}

#[test]
fn test_lazy_reduction_chain_of_three() {
    // addmod(addmod(x, y, P), z, P) where all < P and P < 2^253
    // Should become: add(add(x, y), z)
}

#[test]
fn test_no_lazy_reduction_when_overflow_possible() {
    // addmod(x, y, m) where m > 2^254
    // Should NOT be rewritten (sum could overflow u256)
}
```

### End-to-end validation

After adding rules, rebuild the Fe compiler and re-run the rosetta-fe
test suites:

```bash
# Rebuild sonatina + fe
cd /home/micah/hacker-stuff-2023/fe-stuff/sonatina && cargo build
cd /home/micah/hacker-stuff-2023/fe-stuff/fe && cargo build

# Run rosetta-fe tests
cd /home/micah/hacker-stuff-2023/fe-stuff/rosetta-fe
fe test rosetta_poseidon    # Poseidon hash vectors must still match
fe test rosetta_verifier    # PLONK intermediate values must still match

# Run Foundry differential tests
cd merkle/bench && forge test --ffi --offline -vvv
cd ../../math/bench && forge test --ffi --offline -vvv
```

**Critical**: The Poseidon test vectors (`hash(0,0)`, `hash(1,2)`,
`hash(42,17)`) are the ground truth. If any optimization changes the
output, the rule is wrong.

---

## Implementation Order

```
1. Tier 1 rules          (add to rules.egg, write unit tests)
   - EvmMulMod/EvmAddMod commutativity
   - mulmod(x, 2, m) -> addmod(x, x, m)
   - exp(x, 1) -> x, exp(1, y) -> 1
   - Safe identity rules (gated on input being modular op output)

2. Validate               (rebuild compiler, run rosetta-fe tests)

3. Tier 2 rules           (after PR #224 range analysis merges)
   - Wire range facts into egraph
   - Lazy reduction: addmod -> add when provably safe
   - Chain reduction for triple sums

4. Tier 3 if-conversion   (discuss with Sean re: Select node)
   - Extend egraph encoding with phi-branch linkage
   - Add Select to expr.egg
   - Write rewrite rule + EVM lowering
```

---

## Files to Modify

| File | Change |
|---|---|
| `sonatina/crates/codegen/src/optim/egraph/rules.egg` | Add Tier 1 rules |
| `sonatina/crates/codegen/src/optim/egraph/pass.rs` | Add tests |
| `sonatina/crates/codegen/src/optim/egraph/expr.egg` | Tier 2: range-ub function; Tier 3: Select node, phi-branch-cond |
| `sonatina/crates/codegen/src/optim/egraph/pass.rs` | Tier 3: diamond detection in func_to_egglog |

## Reference: Rosetta-Fe Hot Paths

These are the specific code locations where the optimizations have the
most impact, for validating that rules fire correctly:

- **Poseidon round constants**: `rosetta_poseidon/src/lib.fe:23-27, 30-38`
- **Poseidon sparse matrix multiply**: `rosetta_poseidon/src/lib.fe:58-64`
- **Poseidon MDS mix**: `rosetta_poseidon/src/lib.fe:101-106`
- **Poseidon S-box**: `rosetta_poseidon/src/lib.fe:88-91`
- **Merkle conditional swap**: `rosetta_merkle/src/merkle_proof.fe:21-32`
- **PLONK field arithmetic**: `rosetta_verifier/src/plonk.fe` (throughout)
- **Field ops**: `rosetta_verifier/src/field.fe:12-48`
- **Groth16 pairing setup**: `rosetta_verifier/src/groth16.fe:50-86`
