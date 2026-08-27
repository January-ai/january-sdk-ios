#!/usr/bin/env node

import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const clientSource = await readFile(
  path.join(root, "Sources/JanuarySDK/Core/JanuaryClient.swift"),
  "utf8",
);

if (!/@_spi\(JanuaryDevelopment\)\s+public init\(developmentAPIKey:/.test(clientSource)) {
  throw new Error("The development API-key initializer must remain behind JanuaryDevelopment SPI.");
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

for (const file of publicDocs) {
  const contents = await readFile(file, "utf8");
  if (/developmentAPIKey|JANUARY_DEMO_API_KEY/.test(contents)) {
    throw new Error(`${path.relative(root, file)} exposes private API-key authentication.`);
  }
}

console.log("Public documentation exposes client-token authentication only.");

