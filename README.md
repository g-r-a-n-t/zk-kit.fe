# zk-kit-fe

Fe implementations of the main `zk-kit` tree primitives, Excubia helper logic, and hash helpers, with tests that mirror the Solidity behavior where practical.

## Implemented

- Binary incremental Merkle tree
- Quinary incremental Merkle tree
- Lazy incremental Merkle tree
- Lean incremental Merkle tree
- LazyTower hash chain
- Poseidon `t=3` and `t=6` helpers used by the tree code
- Excubia validation helpers and mock dependency contracts

The current active test suite includes direct behavior checks, Solidity-vector checks, and parity-oriented stateful tests for insert, update, remove, proof, and error handling paths. The full Excubia wrapper and contract-level parity surface is intentionally disabled while the Fe implementation stays library-first.

## Run Tests

```bash
fe test
```

To run a subset:

```bash
fe test --filter test_quinary_
```
