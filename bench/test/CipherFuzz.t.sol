// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Vm {
    function ffi(string[] calldata) external returns (bytes memory);
    function pauseGasMetering() external;
    function resumeGasMetering() external;
}

interface IFeCipher {
    function encryptBlock(uint256[3] calldata pt, uint256 kx, uint256 ky, uint256 nonce) external view returns (uint256[4] memory);
    function decryptBlock(uint256[4] calldata ct, uint256 kx, uint256 ky, uint256 nonce) external view returns (uint256[3] memory);
}

/// @title Poseidon cipher fuzz: encrypt/decrypt roundtrip
/// @notice Verifies decrypt(encrypt(plaintext)) == plaintext for random inputs.
contract CipherFuzzTest {
    address private constant HEVM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(HEVM_ADDRESS);

    uint256 private constant PRIME = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IFeCipher private fe;

    function setUp() public {
        vm.pauseGasMetering();
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "cd .. && fe build >/dev/null 2>&1; printf '0x'; tr -d '\\n' < out/PoseidonCipherBench.bin";
        bytes memory initcode = vm.ffi(cmd);
        address addr;
        assembly { addr := create(0, add(initcode, 0x20), mload(initcode)) }
        require(addr != address(0), "Fe deploy failed");
        fe = IFeCipher(addr);
        vm.resumeGasMetering();
    }

    /// @notice Fuzz: encrypt then decrypt must recover original plaintext
    function testFuzz_roundtrip(uint256 p0, uint256 p1, uint256 p2, uint256 kx, uint256 ky, uint256 nonce) public view {
        p0 = p0 % PRIME;
        p1 = p1 % PRIME;
        p2 = p2 % PRIME;
        kx = kx % PRIME;
        ky = ky % PRIME;
        nonce = nonce % (1 << 128);  // nonce < 2^128

        uint256[3] memory pt = [p0, p1, p2];
        uint256[4] memory ct = fe.encryptBlock(pt, kx, ky, nonce);
        uint256[3] memory recovered = fe.decryptBlock(ct, kx, ky, nonce);

        require(recovered[0] == p0, "p0 mismatch");
        require(recovered[1] == p1, "p1 mismatch");
        require(recovered[2] == p2, "p2 mismatch");
    }

    /// @notice Different keys must produce different ciphertext
    function testFuzz_different_keys(uint256 p0, uint256 k1, uint256 k2) public view {
        p0 = p0 % PRIME;
        k1 = k1 % PRIME;
        k2 = k2 % PRIME;
        if (k1 == k2) return;  // skip degenerate case

        uint256[3] memory pt = [p0, uint256(0), uint256(0)];
        uint256[4] memory ct1 = fe.encryptBlock(pt, k1, 0, 1);
        uint256[4] memory ct2 = fe.encryptBlock(pt, k2, 0, 1);
        require(ct1[0] != ct2[0], "same ciphertext for different keys");
    }

    /// @notice Gas benchmark
    function testGas_encrypt() public view {
        uint256[3] memory pt = [uint256(1), uint256(2), uint256(3)];
        fe.encryptBlock(pt, 12345, 67890, 42);
    }
}
