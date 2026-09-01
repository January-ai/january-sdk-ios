#!/usr/bin/env node

import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const docsRoot = path.join(root, "Documentation", "GitBook");
const summaryPath = path.join(docsRoot, "SUMMARY.md");

async function markdownFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await markdownFiles(absolute));
    if (entry.isFile() && entry.name.endsWith(".md")) files.push(absolute);
  }
  return files;
}

const summary = await readFile(summaryPath, "utf8");
const summaryTargets = [...summary.matchAll(/\[[^\]]+\]\(([^)#]+\.md)(?:#[^)]+)?\)/g)]
  .map((match) => path.resolve(docsRoot, match[1]));

for (const target of summaryTargets) await access(target);

const docs = (await markdownFiles(docsRoot)).filter((file) => file !== summaryPath);
const unlisted = docs.filter((file) => !summaryTargets.includes(path.resolve(file)));
if (unlisted.length > 0) {
  throw new Error(`GitBook pages missing from SUMMARY.md:\n${unlisted.join("\n")}`);
}

const markdown = [path.join(root, "README.md"), ...docs];
for (const file of markdown) {
  const source = await readFile(file, "utf8");
  for (const match of source.matchAll(/(?<!!)\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = match[1];
    if (/^(?:https?:|mailto:|#)/.test(target)) continue;
    const relative = target.split("#", 1)[0];
    if (relative.length > 0) await access(path.resolve(path.dirname(file), relative));
  }
}

const restaurantGuide = await readFile(path.join(docsRoot, "guides", "restaurants.md"), "utf8");
const referenceCandidates = [
  path.join(docsRoot, "reference", "restaurants-api.md"),
  path.join(docsRoot, "reference", "discovery-and-scanning-api.md"),
];
let restaurantReference;
for (const candidate of referenceCandidates) {
  try {
    restaurantReference = await readFile(candidate, "utf8");
    break;
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}

const changelog = await readFile(path.join(docsRoot, "reference", "changelog.md"), "utf8");
for (const [name, source] of [
  ["restaurant guide", restaurantGuide],
  ["restaurant reference", restaurantReference ?? ""],
  ["GitBook changelog", changelog],
]) {
  if (!/getMenuItems|restaurant-menu lookup/i.test(source)) {
    throw new Error(`${name} does not document restaurant-menu lookup by ID.`);
  }
}

console.log(`Validated ${docs.length} GitBook pages, internal links, and restaurant-menu documentation.`);
