# zk-kit

A canonical Fe implementation of zk-kit primitives for EVM use.

This workspace consolidates the three prototype implementations in the parent directory:

- Grant's Keccak LeanIMT/SMT work and Solidity differential harness.
- Micah's package map for Poseidon, Baby Jubjub, ECDH, EdDSA, cipher, and Groth16 helpers.
- Sean's stateful tree implementations and behavior tests.

The implementation is intentionally Fe-native at the library layer and Solidity-compatible at the contract layer.
Library functions use fixed arrays and explicit lengths so their gas and memory behavior is predictable. Contract wrappers
use Solidity selectors and ABI shapes where there is an existing Solidity benchmark or consumer expectation.

## Workspace

```text
zk-kit/
  fe.toml
  ingots/
    zkkit_core/
    zkkit_poseidon/
    zkkit_merkle/
    zkkit_trees/
    zkkit_ec/
    zkkit_proofs/
    zkkit_contracts/
    zkkit/          # facade (re-exports the above)
```

## Public Contracts

`fe build zk-kit` emits:

- `ZkKitPoseidon`
  - `hash2(uint256,uint256)`
  - `hash3(uint256,uint256,uint256)`
  - `hash5(uint256,uint256,uint256,uint256,uint256)`
- `ZkKitPoseidonCipher`
  - `encryptBlock(uint256[3],uint256,uint256,uint256)`
  - `decryptBlock(uint256[4],uint256,uint256,uint256)`
- `ZkKitPoseidonProof`
  - `commit(uint256,uint256)`
  - `scopedCommit(uint256,uint256)`
  - `computeNullifier(uint256,uint256,uint256)`
  - `verifyPreimage(uint256,uint256,uint256)`
  - `verifyNullifier(uint256,uint256,uint256)`
- `ZkKitBabyJubjub`
  - `identity()`
  - `basePoint()`
  - `add(uint256[2],uint256[2])`
  - `doublePoint(uint256[2])`
  - `mulScalar(uint256[2],uint256)`
  - `negate(uint256[2])`
  - `isOnCurve(uint256[2])`
  - `isInSubgroup(uint256[2])`
- `ZkKitEcdh`
  - `derivePublicKey(uint256)`
  - `generateSharedKey(uint256,uint256[2])`
  - `generateSharedKeyUnchecked(uint256,uint256[2])`
- `ZkKitEddsaPoseidon`
  - `verify(uint256,uint256[2],uint256[2],uint256)`
- `ZkKitGroth16`
  - `verify(uint256[2],uint256[2][2],uint256[2][2],uint256[2][2],uint256[2],uint256[2],uint256[2],uint256[2][2],uint256[2],uint256)`
- `ZkKitMerkle`
  - `computeLeanIMTRoot(uint256,uint256,uint256,uint256[32])`
  - `verifyLeanIMT(uint256,uint256,uint256,uint256,uint256[32])`
  - `updateLeanIMTRoot(uint256,uint256,uint256,uint256,uint256,uint256[32])`
  - `computeSMTRoot(uint256,uint256,uint256,uint256[32])`
  - `verifySMT(uint256,uint256,uint256,uint256,uint256[32])`
  - `updateSMTRoot(uint256,uint256,uint256,uint256,uint256,uint256[32])`
- `ZkKitMerkleProof`
  - `computeRoot(uint256[32],uint256,uint256)`
  - `verify(uint256[32],uint256,uint256,uint256)`
- `ZkKitPoseidonMerkle`
  - `computeRoot(uint256,uint256,uint256[32])`
  - `verify(uint256,uint256,uint256[32],uint256)`
  - `computeBinaryRoot(uint256,uint256,uint256,uint256[32])`
  - `verifyBinary(uint256,uint256,uint256,uint256,uint256[32])`

Note: Solidity/TypeScript parity harnesses live on the `extra` branch.

## Validation

Fast compatibility gate:

```sh
fe check zk-kit
```

Build deployable contract artifacts:

```sh
fe build zk-kit
```

Targeted Fe test examples:

```sh
fe test --grouped -O0 zk-kit/ingots/zkkit_poseidon
fe test --grouped -O0 zk-kit/ingots/zkkit_merkle
fe test --grouped -O0 zk-kit/ingots/zkkit_trees
fe test --grouped -O0 zk-kit/ingots/zkkit_ec
fe test --grouped -O0 zk-kit/ingots/zkkit_contracts
```

The workspace is split into smaller ingots so you can run `fe test` per subsystem. Whole-workspace `fe test` is still
slower than targeted ingot runs; prefer per-ingot tests during development.

For Foundry parity tests (Solidity reference + `poseidon-lite`), check out the `extra` branch.

## Extra Branch

The `extra` branch contains:

- Foundry parity/bench harness (`bench/`)
- Validation reports and implementation notes (`reports/`)

## Release Gaps

- Add authoritative valid vectors for EdDSA-Poseidon and Groth16.
- Add differential harnesses for Poseidon cipher, Baby Jubjub, EdDSA, and Groth16.
- Port or intentionally separate Sean's Excubia contracts.
- Decide whether stateful tree contracts should be exposed on-chain or kept as library/test models.
