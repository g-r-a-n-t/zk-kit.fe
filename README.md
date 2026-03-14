# zk-kit-fe

Fe implementations of the main `zk-kit` tree primitives, excubia contracts, and hash helpers, with tests that mirror the Solidity behavior where practical.

## Implemented

- Binary incremental Merkle tree
- Quinary incremental Merkle tree
- Lazy incremental Merkle tree
- Lean incremental Merkle tree
- LazyTower hash chain
- Poseidon `t=3` and `t=6` helpers used by the tree code
- Excubia contracts:
- `FreeForAllExcubia`
- `ERC721Excubia`
- `GitcoinPassportExcubia`
- `HatsExcubia`
- `EASExcubia`
- `SemaphoreExcubia`
- `ZKEdDSAEventTicketPCDExcubia`
- `ZKEdDSAEventTicketPCDVerifier`

The current test suite includes direct behavior checks, Solidity-vector checks, Groth16 verifier vectors, and parity-oriented stateful tests for insert, update, remove, proof, and error handling paths.

## Run Tests

```bash
fe test src/lib.fe
```

To run a subset:

```bash
fe test src/lib.fe --filter test_quinary_
```
