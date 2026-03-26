// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Vm {
    function ffi(string[] calldata) external returns (bytes memory);
    function pauseGasMetering() external;
    function resumeGasMetering() external;
    function envOr(string calldata name, uint256 defaultValue) external returns (uint256);
    function toString(uint256 value) external pure returns (string memory);
}

/// @title Poseidon differential fuzz: Fe vs poseidon-lite (Node.js reference)
/// @notice Deploys the Fe PoseidonBench contract, then fuzz-tests hash2 and
/// hash3 against poseidon-lite via FFI. This catches any divergence between
/// Fe's Poseidon implementation and the canonical JS reference.
contract PoseidonFuzzTest {
    address private constant HEVM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(HEVM_ADDRESS);

    // BN254 scalar field — inputs must be < this
    uint256 private constant PRIME = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    address private feAddr;

    function setUp() public {
        vm.pauseGasMetering();

        // Build Fe workspace
        string[] memory buildCmd = new string[](3);
        buildCmd[0] = "bash";
        buildCmd[1] = "-c";
        buildCmd[2] = "cd .. && fe build >/dev/null 2>&1; printf '0x'; tr -d '\\n' < out/PoseidonBench.bin";
        bytes memory feInitcode = vm.ffi(buildCmd);
        address _fe;
        assembly { _fe := create(0, add(feInitcode, 0x20), mload(feInitcode)) }
        require(_fe != address(0), "Fe deploy failed");
        feAddr = _fe;

        vm.resumeGasMetering();
    }

    // --- Deterministic tests ---

    function test_hash2_known_vectors() public view {
        assertEq(_callFeHash2(0, 0), 0x2098f5fb9e239eab3ceac3f27b81e481dc3124d55ffed523a839ee8446b64864);
        assertEq(_callFeHash2(1, 2), 0x115cc0f5e7d690413df64c6b9662e9cf2a3617f2743245519e19607a4417189a);
        assertEq(_callFeHash2(42, 17), 0x18ddf7be412cfc792364a46eba440316dbb2427346063b747899e6ee0c3aa214);
    }

    function test_hash3_known_vectors() public view {
        assertEq(_callFeHash3(0, 0, 0), 0x0bc188d27dcceadc1dcfb6af0a7af08fe2864eecec96c5ae7cee6db31ba599aa);
        assertEq(_callFeHash3(1, 2, 3), 0x0e7732d89e6939c0ff03d5e58dab6302f3230e269dc5b968f725df34ab36d732);
        assertEq(_callFeHash3(42, 17, 99), 0x2b5752531a1355ea7d214c46270316dbc3f922bfc050325e4a47ffd9363825c5);
    }

    // --- Fuzz: Fe vs poseidon-lite (Node.js) ---

    function testFuzz_hash2_vs_poseidon_lite(uint256 a, uint256 b) public {
        a = a % PRIME;
        b = b % PRIME;

        uint256 feResult = _callFeHash2(a, b);
        uint256 refResult = _callPoseidonLite(2, a, b, 0);
        require(feResult == refResult, "hash2: Fe != poseidon-lite");
    }

    function testFuzz_hash3_vs_poseidon_lite(uint256 a, uint256 b, uint256 c) public {
        a = a % PRIME;
        b = b % PRIME;
        c = c % PRIME;

        uint256 feResult = _callFeHash3(a, b, c);
        uint256 refResult = _callPoseidonLite(3, a, b, c);
        require(feResult == refResult, "hash3: Fe != poseidon-lite");
    }

    // --- Gas benchmarks ---

    function testGas_hash2() public view {
        _callFeHash2(1, 2);
    }

    function testGas_hash3() public view {
        _callFeHash3(1, 2, 3);
    }

    // --- Internal helpers ---

    function _callFeHash2(uint256 a, uint256 b) internal view returns (uint256) {
        (bool ok, bytes memory ret) = feAddr.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("hash2(uint256,uint256)")), a, b)
        );
        require(ok, "Fe hash2 call failed");
        return abi.decode(ret, (uint256));
    }

    function _callFeHash3(uint256 a, uint256 b, uint256 c) internal view returns (uint256) {
        (bool ok, bytes memory ret) = feAddr.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("hash3(uint256,uint256,uint256)")), a, b, c)
        );
        require(ok, "Fe hash3 call failed");
        return abi.decode(ret, (uint256));
    }

    function _callPoseidonLite(uint256 width, uint256 a, uint256 b, uint256 c) internal returns (uint256) {
        string[] memory cmd;
        if (width == 2) {
            cmd = new string[](5);
            cmd[0] = "node";
            cmd[1] = "scripts/poseidon_ref.mjs";
            cmd[2] = "2";
            cmd[3] = vm.toString(a);
            cmd[4] = vm.toString(b);
        } else {
            cmd = new string[](6);
            cmd[0] = "node";
            cmd[1] = "scripts/poseidon_ref.mjs";
            cmd[2] = "3";
            cmd[3] = vm.toString(a);
            cmd[4] = vm.toString(b);
            cmd[5] = vm.toString(c);
        }
        bytes memory result = vm.ffi(cmd);
        return abi.decode(result, (uint256));
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq failed");
    }
}
