#!/usr/bin/env node

import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const clientSource = await readFile(
  path.join(root, "Sources/JanuarySDK/Core/JanuaryClient.swift"),
  "utf8",
);

if (!/@available\(\*, deprecated, message: "[^"]*Local testing only\.[^"]*JanuaryTokenProvider[^"]*"\)\s+public init\(developmentAPIKey:/.test(clientSource)) {
  throw new Error("The API-key initializer must remain public with an explicit local-testing deprecation warning that directs production users to JanuaryTokenProvider.");
}

if (!/authenticationLogger\.warning/.test(clientSource) || !/developmentAPIKeyWarning/.test(clientSource)) {
  throw new Error("A nonempty development API key must emit a runtime warning without logging the key.");
}

async function markdownFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await markdownFiles(absolute));
    if (entry.isFile() && entry.name.endsWith(".md")) files.push(absolute);
  }
  return files;
}

const publicDocs = [
  path.join(root, "README.md"),
  ...await markdownFiles(path.join(root, "Documentation/GitBook")),
  ...await markdownFiles(path.join(root, "Sources/JanuarySDK/JanuarySDK.docc")),
];

const combinedDocs = (await Promise.all(
  publicDocs.map((file) => readFile(file, "utf8")),
)).join("\n");

for (const phrase of [
  "JanuaryTokenProvider",
  "developmentAPIKey",
  "local development",
  "Do not use it in production",
]) {
  if (!combinedDocs.includes(phrase)) {
    throw new Error(`Public documentation must include authentication guidance containing: ${phrase}`);
  }
}

if (!/URLSession\.shared\.data\(for: request\)/.test(combinedDocs)) {
  throw new Error("Public documentation must show a token provider calling the partner backend with URLSession.");
}

console.log("Public authentication documents production token providers and local-only API keys.");
