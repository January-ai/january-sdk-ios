#!/usr/bin/env node
// Print the Maestro flow files that belong to shard <index> of <total> (1-based,
// so "shard 1 of 4" reads naturally in CI), so CI can spread the suite over
// several emulators or simulators. Flows are sorted by file name and dealt
// round-robin, which keeps the shards the same size and stable between runs.
// Live-tagged flows are listed too; the caller's --include-tags keeps them out
// of fixture runs.
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const [indexArg, totalArg] = process.argv.slice(2);
const index = Number(indexArg);
const total = Number(totalArg);
if (!Number.isInteger(index) || !Number.isInteger(total) || total < 1 || index < 1 || index > total) {
  console.error('usage: node Examples/JanuaryPartnerDemo/.maestro/shard.mjs <index 1..total> <total>');
  process.exit(2);
}

const flowsDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'flows');
const files = readdirSync(flowsDir)
  .filter((name) => name.endsWith('.yaml'))
  .sort();
const shard = files.filter((_, position) => position % total === index - 1);
console.log(
  shard.map((name) => path.join('Examples/JanuaryPartnerDemo/.maestro/flows', name)).join(' ')
);
