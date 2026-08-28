#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const clientSource = await readFile(
  path.join(root, "Sources/JanuarySDK/Core/JanuaryClient.swift"),
  "utf8",
);
const developmentProviderSource = await readFile(
  path.join(
    root,
    "Sources/JanuarySDK/Core/Authentication/JanuaryDevelopmentTokenProvider.swift",
  ),
  "utf8",
);

if (!/@available\(\*, deprecated, message: "[^"]*Local testing only\.[^"]*JanuaryTokenProvider[^"]*"\)\s+public init\(\s*developmentAPIKey:\s*String,\s*endUserID:\s*PartnerUserID/.test(clientSource)) {
  throw new Error("The API-key initializer must remain public with an explicit local-testing deprecation warning that directs production users to JanuaryTokenProvider.");
}

if (!/authenticationLogger\.warning/.test(clientSource) || !/developmentAPIKeyWarning/.test(clientSource)) {
  throw new Error("A nonempty development API key must emit a runtime warning without logging the key.");
}

if (!/@available\(\*, deprecated, message: "[^"]*Local debug testing only\.[^"]*JanuaryTokenProvider[^"]*"\)\s+public init\(\s*apiKey:\s*String,\s*endUserID:\s*PartnerUserID,\s*ttlSeconds:\s*Int\s*=\s*300/.test(developmentProviderSource)) {
  throw new Error("The development token provider must remain explicitly deprecated and direct production users to a backend-backed JanuaryTokenProvider.");
}

if (!/https:\/\/partners\.january\.ai\/v1\.2\/auth\/client-tokens/.test(developmentProviderSource)) {
  throw new Error("The development token provider must mint against January production without exposing a configurable API origin.");
}

const forbiddenInternalReferences = [
  "partners." + "dev.january.ai",
  "sandbox/" + "client-token",
  "JANUARY_" + "INTERNAL_API_BASE_URL",
];
for (const reference of forbiddenInternalReferences) {
  try {
    const matches = execFileSync(
      "git",
      ["grep", "-n", "-F", reference, "--", "."],
      { cwd: root, encoding: "utf8" },
    );
    throw new Error(
      `January-internal endpoint configuration must not be tracked:\n${matches}`,
    );
  } catch (error) {
    if (error?.status === 1) continue;
    throw error;
  }
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
  "JanuaryDevelopmentTokenProvider",
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
