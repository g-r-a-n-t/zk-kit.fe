# zk-kit.fe

> **Status: Experimental / Work in Progress**

ZK-Kit is a set of libraries (algorithms or utility functions) that can be reused in different projects and zero-knowledge protocols, making it easier for developers to access user-friendly, tested, and documented code for common tasks. ZK-Kit provides different repositories for each language -- this one contains [Fe](https://fe-lang.org) code only.

The implementation is Fe-native at the library layer and Solidity-compatible at the contract layer.
Library functions use fixed arrays and explicit lengths so their gas and memory behavior is predictable.
Contract wrappers use Solidity selectors and ABI shapes for interop with existing tooling.

## Repositories

- **JavaScript:** [zk-kit](https://github.com/privacy-scaling-explorations/zk-kit)
- **Solidity:** [zk-kit.solidity](https://github.com/privacy-scaling-explorations/zk-kit.solidity)
- **Circom:** [zk-kit.circom](https://github.com/privacy-scaling-explorations/zk-kit.circom)
- **Noir:** [zk-kit.noir](https://github.com/privacy-scaling-explorations/zk-kit.noir)
- **Rust:** [zk-kit.rust](https://github.com/privacy-scaling-explorations/zk-kit.rust)
- **Cairo:** [zk-kit.cairo](https://github.com/nicblockchain/zk-kit.cairo)
- **Fe:** [zk-kit.fe](https://github.com/fe-lang/zk-kit.fe) (this repo)

## Workspace

```text
zk-kit/
  fe.toml
  ingots/
    zkkit_core/        # field arithmetic (const-generic modulus), BN254 constants
    zkkit_poseidon/    # Poseidon hash (T=3, T=4, T=6), cipher, preimage proofs
    zkkit_ec/          # Baby JubJub, ECDH, EdDSA-Poseidon
    zkkit_proofs/      # BN254 precompiles, Groth16 verifier
    zkkit_merkle/      # Lean IMT, SMT, keccak Merkle proof verification
    zkkit_trees/       # Binary IMT, Lazy IMT, Lean IMT, Quinary IMT, LazyTower
    zkkit_contracts/   # Solidity-compatible ABI wrappers
    zkkit/             # facade (re-exports the above)
```

## Public Contracts

`fe build zk-kit` emits the following contracts with Solidity-compatible selectors:

- **ZkKitPoseidon** -- `hash2`, `hash3`, `hash5`
- **ZkKitPoseidonCipher** -- `encryptBlock`, `decryptBlock`
- **ZkKitPoseidonProof** -- `commit`, `scopedCommit`, `computeNullifier`, `verifyPreimage`, `verifyNullifier`
- **ZkKitBabyJubjub** -- `identity`, `basePoint`, `add`, `doublePoint`, `mulScalar`, `negate`, `isOnCurve`, `isInSubgroup`
- **ZkKitEcdh** -- `derivePublicKey`, `generateSharedKey`, `generateSharedKeyUnchecked`
- **ZkKitEddsaPoseidon** -- `verify`
- **ZkKitGroth16** -- `verify`
- **ZkKitMerkle** -- `computeLeanIMTRoot`, `verifyLeanIMT`, `updateLeanIMTRoot`, `computeSMTRoot`, `verifySMT`, `updateSMTRoot`
- **ZkKitMerkleProof** -- `computeRoot`, `verify`
- **ZkKitPoseidonMerkle** -- `computeRoot`, `verify`, `computeBinaryRoot`, `verifyBinary`

## Usage

Check the workspace compiles:

```sh
fe check zk-kit
```

Build deployable contract artifacts:

```sh
fe build zk-kit
```

Run tests per ingot (the workspace is split so you can test subsystems independently):

```sh
fe test --grouped -O0 zk-kit/ingots/zkkit_poseidon
fe test --grouped -O0 zk-kit/ingots/zkkit_trees
fe test --grouped -O0 zk-kit/ingots/zkkit_ec
fe test --grouped -O0 zk-kit/ingots/zkkit_merkle
fe test --grouped -O0 zk-kit/ingots/zkkit_contracts
```

## Known Gaps

- Poseidon: adopt `const fn` and `static_assert` for compile-time hash verification
- Poseidon T=3: port sparse-matrix optimization for partial rounds
- Groth16: needs tests
- EdDSA-Poseidon: needs valid-signature test (only rejection test exists)
- Excubia access-control contracts: not yet ported
- Foundry differential fuzz harness: not yet integrated
