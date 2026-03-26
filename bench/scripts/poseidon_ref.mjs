#!/usr/bin/env node
// Reference Poseidon implementation via poseidon-lite.
// Usage: node poseidon_ref.mjs <width> <arg0> <arg1> [arg2] [arg3] [arg4]
// Output: hex-encoded hash result (no 0x prefix, 64 chars)

import { poseidon2 } from 'poseidon-lite/poseidon2';
import { poseidon3 } from 'poseidon-lite/poseidon3';
import { poseidon5 } from 'poseidon-lite/poseidon5';

const args = process.argv.slice(2);
const width = parseInt(args[0]);
const inputs = args.slice(1).map(BigInt);

let result;
if (width === 2) result = poseidon2(inputs);
else if (width === 3) result = poseidon3(inputs);
else if (width === 5) result = poseidon5(inputs);
else { console.error('Unsupported width:', width); process.exit(1); }

// Output as 32-byte hex (left-padded)
process.stdout.write(result.toString(16).padStart(64, '0'));
