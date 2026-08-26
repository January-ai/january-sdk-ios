#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const partnerKeyPattern = new RegExp(`\\b${'s' + 'k-'}[A-Za-z0-9_-]{20,}\\b`);
const stagedOnly = process.argv.includes('--staged');
const selfTest = process.argv.includes('--self-test');

if (selfTest) {
  const fakeKey = `${'s' + 'k-'}${'A'.repeat(32)}`;
  if (!partnerKeyPattern.test(fakeKey) || partnerKeyPattern.test('<development-key>')) {
    throw new Error('Partner API key detection self-test failed.');
  }
  console.log('Partner API key detection self-test passed.');
  process.exit(0);
}

const files = listFiles(stagedOnly);
const violations = [];

for (const file of files) {
  let contents;
  try {
    contents = stagedOnly
      ? execFileSync('git', ['show', `:${file}`], { encoding: 'utf8' })
      : readFileSync(file, 'utf8');
  } catch {
    continue;
  }

  if (partnerKeyPattern.test(contents)) violations.push(file);
}

if (violations.length) {
  console.error('Commit blocked: a January Partner API key was detected in staged or tracked content.');
  console.error('Remove the key from:');
  for (const file of violations) console.error(`- ${file}`);
  process.exit(1);
}

console.log(`No January Partner API keys detected in ${stagedOnly ? 'staged' : 'tracked'} files.`);

function listFiles(staged) {
  const args = staged
    ? ['diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z']
    : ['ls-files', '-z'];
  return execFileSync('git', args, { encoding: 'utf8' })
    .split('\0')
    .filter(Boolean);
}
