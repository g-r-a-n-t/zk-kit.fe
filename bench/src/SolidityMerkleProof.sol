// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Solidity reference Merkle proof library (keccak, sorted pairs).
/// Matches Solady MerkleProofLib and zk-kit.fe merkle/merkle_proof.fe.
contract SolidityMerkleProof {
    function computeRoot(
        uint256[32] calldata proof,
        uint256 proofLen,
        bytes32 leaf
    ) external pure returns (bytes32) {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proofLen; i++) {
            bytes32 sibling = bytes32(proof[i]);
            if (hash < sibling) {
                hash = keccak256(abi.encodePacked(hash, sibling));
            } else {
                hash = keccak256(abi.encodePacked(sibling, hash));
            }
        }
        return hash;
    }

    function verify(
        uint256[32] calldata proof,
        uint256 proofLen,
        bytes32 root,
        bytes32 leaf
    ) external view returns (bool) {
        return this.computeRoot(proof, proofLen, leaf) == root;
    }
}
