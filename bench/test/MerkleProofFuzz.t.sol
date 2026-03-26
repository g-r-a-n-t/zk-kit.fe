// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SolidityMerkleProof} from "../src/SolidityMerkleProof.sol";

interface Vm {
    function ffi(string[] calldata) external returns (bytes memory);
    function pauseGasMetering() external;
    function resumeGasMetering() external;
}

interface IFeMerkleProof {
    function computeRoot(uint256[32] calldata proof, uint256 proofLen, uint256 leaf) external pure returns (uint256);
    function verify(uint256[32] calldata proof, uint256 proofLen, uint256 root, uint256 leaf) external pure returns (bool);
}

/// @title Merkle proof differential fuzz: Fe vs Solidity
/// @notice Fuzz-tests Fe's keccak Merkle proof against a Solidity reference
/// at depths 1-5 with random leaves and siblings.
contract MerkleProofFuzzTest {
    address private constant HEVM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(HEVM_ADDRESS);

    IFeMerkleProof private fe;
    SolidityMerkleProof private sol;

    function setUp() public {
        vm.pauseGasMetering();

        string[] memory buildCmd = new string[](3);
        buildCmd[0] = "bash";
        buildCmd[1] = "-c";
        buildCmd[2] = "cd .. && fe build >/dev/null 2>&1; printf '0x'; tr -d '\\n' < out/MerkleProofBench.bin";
        bytes memory feInitcode = vm.ffi(buildCmd);
        address feAddr;
        assembly { feAddr := create(0, add(feInitcode, 0x20), mload(feInitcode)) }
        require(feAddr != address(0), "Fe deploy failed");
        fe = IFeMerkleProof(feAddr);

        sol = new SolidityMerkleProof();
        vm.resumeGasMetering();
    }

    // --- Fuzz: Fe vs Solidity at depth 1 ---

    function testFuzz_computeRoot_depth1(uint256 leaf, uint256 sibling) public view {
        uint256[32] memory proof;
        proof[0] = sibling;
        uint256 feRoot = fe.computeRoot(proof, 1, leaf);
        bytes32 solRoot = sol.computeRoot(proof, 1, bytes32(leaf));
        require(feRoot == uint256(solRoot), "depth1: Fe != Solidity");
    }

    // --- Fuzz: Fe vs Solidity at depth 3 ---

    function testFuzz_computeRoot_depth3(
        uint256 leaf, uint256 s0, uint256 s1, uint256 s2
    ) public view {
        uint256[32] memory proof;
        proof[0] = s0;
        proof[1] = s1;
        proof[2] = s2;
        uint256 feRoot = fe.computeRoot(proof, 3, leaf);
        bytes32 solRoot = sol.computeRoot(proof, 3, bytes32(leaf));
        require(feRoot == uint256(solRoot), "depth3: Fe != Solidity");
    }

    // --- Fuzz: verify roundtrip ---

    function testFuzz_verify_roundtrip(
        uint256 leaf, uint256 s0, uint256 s1, uint256 s2
    ) public view {
        uint256[32] memory proof;
        proof[0] = s0;
        proof[1] = s1;
        proof[2] = s2;
        uint256 root = fe.computeRoot(proof, 3, leaf);
        require(fe.verify(proof, 3, root, leaf), "should verify");
        require(!fe.verify(proof, 3, root ^ 1, leaf), "should not verify");
    }

    // --- Gas benchmarks ---

    function testGas_fe_computeRoot_depth5() public view {
        uint256[32] memory proof;
        proof[0] = 0x1111; proof[1] = 0x2222; proof[2] = 0x3333;
        proof[3] = 0x4444; proof[4] = 0x5555;
        fe.computeRoot(proof, 5, 0xdeadbeef);
    }

    function testGas_sol_computeRoot_depth5() public view {
        uint256[32] memory proof;
        proof[0] = 0x1111; proof[1] = 0x2222; proof[2] = 0x3333;
        proof[3] = 0x4444; proof[4] = 0x5555;
        sol.computeRoot(proof, 5, bytes32(uint256(0xdeadbeef)));
    }
}
