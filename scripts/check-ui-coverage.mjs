#!/usr/bin/env node
// Checks that the demo's Maestro suite exercises every accessibility identifier
// the demo declares. No device is needed: the script reads the Swift sources and
// the flow files.
//
//   node scripts/check-ui-coverage.mjs          # prints the summary, fails below 100%
//   node scripts/check-ui-coverage.mjs --list   # also prints every identifier and the flows using it
//
// Declared identifiers come from `.accessibilityIdentifier(...)` and from the
// identifier arguments the demo's components forward to it (`identifier:`,
// `retryIdentifier:`, `accessibilityIdentifier:`, ...), including computed
// `...Identifier` properties. Interpolated identifiers ("food-result-\(index)")
// must be listed in `interpolatedIdentifiers` below with the concrete
// identifiers that stand for them, so a new pattern cannot slip through.
//
// An identifier counts as exercised when a flow tagged `fixture` or `parity`
// (the tags CI runs) taps it, types into it after tapping it, or requires it to
// be visible: `tapOn`, `assertVisible`, `extendedWaitUntil.visible`,
// `scrollUntilVisible.element`, and `scroll-to.yaml`'s TARGET_ID. Optional
// commands, `assertNotVisible`, and `when` conditions do not count: none of them
// fails when the element is missing.
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const demoRoot = path.join(root, "Examples", "JanuaryPartnerDemo");
const sourceRoot = path.join(demoRoot, "JanuaryPartnerDemo");
const maestroRoot = path.join(demoRoot, ".maestro");
const flowsRoot = path.join(maestroRoot, "flows");
const coverageTags = new Set(["fixture", "parity"]);
const knownTags = new Set(["fixture", "parity", "recovery", "live"]);

// Every interpolated identifier in the demo, keyed by its template with each
// interpolation written as {}. A repeated row lists one identifier (the first
// row), and any row a flow reaches covers it; an enumeration lists every case,
// and each case must be reached.
const interpolatedIdentifiers = {
  "{}-range-{}": [
    "water-chart-range-week", "water-chart-range-month", "water-chart-range-year",
    "weight-chart-range-week", "weight-chart-range-month", "weight-chart-range-year",
  ],
  "autocomplete-result-{}": ["autocomplete-result-0"],
  "food-log-{}": ["food-log-0"],
  "food-picker-result-{}": ["food-picker-result-0"],
  "food-picker-suggestion-{}": ["food-picker-suggestion-0"],
  "food-result-{}": ["food-result-0"],
  "food-serving-option-{}": ["food-serving-option-0"],
  "glucose-food-{}": ["glucose-food-0"],
  "glucose-height-unit-{}": ["glucose-height-unit-imperial", "glucose-height-unit-metric"],
  "glucose-weight-unit-{}": ["glucose-weight-unit-lb", "glucose-weight-unit-kg"],
  "menu-result-{}": ["menu-result-0"],
  "restaurant-menu-item-{}": ["restaurant-menu-item-0"],
  "restaurant-result-{}": ["restaurant-result-0"],
  "search-scope-{}": ["search-scope-foods", "search-scope-restaurants"],
  "tracking-food-log-{}": ["tracking-food-log-0"],
  "water-unit-{}": ["water-unit-fl_oz", "water-unit-ml", "water-unit-cup"],
  "weight-unit-{}": ["weight-unit-lb", "weight-unit-kg"],
};

// Argument labels and properties whose string values end up in
// `.accessibilityIdentifier(...)`.
const identifierLabels = new Set([
  "accessibilityIdentifier",
  "clearIdentifier",
  "detailsBodyIdentifier",
  "detailsIdentifier",
  "identifier",
  "itemIdentifier",
  "retryIdentifier",
  "voiceIdentifier",
]);
// Foundation initializers that take an unrelated `identifier:` argument.
const unrelatedIdentifierCalls = new Set(["Calendar", "Locale", "TimeZone"]);

function files(directory, extension) {
  return readdirSync(directory).flatMap((name) => {
    const absolute = path.join(directory, name);
    if (statSync(absolute).isDirectory()) return files(absolute, extension);
    return name.endsWith(extension) ? [absolute] : [];
  });
}

// MARK: - Swift

/// Blanks out comments while keeping string literals and offsets intact.
function stripComments(source) {
  let output = "";
  let index = 0;
  const stringStack = []; // interpolation depth per open string
  let inString = false;
  let parenDepth = 0;
  while (index < source.length) {
    const character = source[index];
    const next = source[index + 1];
    if (inString) {
      if (character === "\\" && next === "(") {
        stringStack.push(parenDepth);
        parenDepth = 0;
        inString = false;
        output += "\\(";
        index += 2;
        continue;
      }
      if (character === "\\") { output += source.slice(index, index + 2); index += 2; continue; }
      if (character === "\"") inString = false;
      output += character;
      index += 1;
      continue;
    }
    if (character === "/" && next === "/") {
      while (index < source.length && source[index] !== "\n") { output += " "; index += 1; }
      continue;
    }
    if (character === "/" && next === "*") {
      while (index < source.length && !(source[index] === "*" && source[index + 1] === "/")) {
        output += source[index] === "\n" ? "\n" : " ";
        index += 1;
      }
      output += "  ";
      index += 2;
      continue;
    }
    if (character === "\"") inString = true;
    if (character === "(") parenDepth += 1;
    if (character === ")") {
      if (parenDepth === 0 && stringStack.length > 0) {
        parenDepth = stringStack.pop();
        inString = true;
        output += character;
        index += 1;
        continue;
      }
      parenDepth -= 1;
    }
    output += character;
    index += 1;
  }
  return output;
}

/// Reads a string literal starting at `start` (the opening quote). Returns the
/// template (interpolations as {}) and the index after the closing quote.
function readString(source, start) {
  let template = "";
  let index = start + 1;
  while (index < source.length) {
    const character = source[index];
    if (character === "\\" && source[index + 1] === "(") {
      let depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        if (source[index] === "\"") { index = readString(source, index).end; continue; }
        if (source[index] === "(") depth += 1;
        if (source[index] === ")") depth -= 1;
        index += 1;
      }
      template += "{}";
      continue;
    }
    if (character === "\\") { template += source[index + 1]; index += 2; continue; }
    if (character === "\"") return { template, end: index + 1 };
    template += character;
    index += 1;
  }
  throw new Error(`Unterminated string literal at offset ${start}`);
}

/// The expression that starts at `start`: up to a top-level comma, closing
/// bracket, or line break, continuing across lines while brackets are open.
function readExpression(source, start) {
  let depth = 0;
  let index = start;
  while (index < source.length) {
    const character = source[index];
    if (character === "\"") { index = readString(source, index).end; continue; }
    if ("([{".includes(character)) depth += 1;
    if (")]}".includes(character)) {
      if (depth === 0) break;
      depth -= 1;
    }
    if (depth === 0 && (character === "," || character === "\n") && index > start) {
      if (character === "," || source.slice(start, index).trim().length > 0) break;
    }
    index += 1;
  }
  return { text: source.slice(start, index), start };
}

/// The balanced block that opens at `start` (a `(` or `{`).
function readBlock(source, start) {
  const open = source[start];
  const close = open === "(" ? ")" : "}";
  let depth = 0;
  let index = start;
  while (index < source.length) {
    const character = source[index];
    if (character === "\"") { index = readString(source, index).end; continue; }
    if (character === open) depth += 1;
    if (character === close) {
      depth -= 1;
      if (depth === 0) return { text: source.slice(start + 1, index), start: start + 1 };
    }
    index += 1;
  }
  throw new Error(`Unbalanced ${open} at offset ${start}`);
}

function stringLiterals(text) {
  const literals = [];
  let index = 0;
  while (index < text.length) {
    if (text[index] === "\"") {
      const literal = readString(text, index);
      literals.push({ template: literal.template, offset: index });
      index = literal.end;
      continue;
    }
    index += 1;
  }
  return literals;
}

/// The name of the call whose argument list contains `offset`, if any.
function enclosingCall(source, offset) {
  let depth = 0;
  for (let index = offset - 1; index >= 0; index -= 1) {
    const character = source[index];
    if (character === ")") depth += 1;
    if (character === "(") {
      if (depth === 0) return source.slice(0, index).match(/([A-Za-z_][A-Za-z0-9_.]*)\s*$/)?.[1] ?? "";
      depth -= 1;
    }
    if (character === "{" || character === "}") return "";
  }
  return "";
}

function lineAt(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function declaredIdentifiers() {
  const declared = new Map(); // id -> [location]
  const templates = new Map(); // template -> [location]
  const add = (map, key, location) => map.set(key, [...(map.get(key) ?? []), location]);

  for (const file of files(sourceRoot, ".swift").sort()) {
    const source = stripComments(readFileSync(file, "utf8"));
    const relative = path.relative(root, file);
    const expressions = [];

    for (const match of source.matchAll(/\.accessibilityIdentifier\s*\(/g)) {
      expressions.push(readBlock(source, match.index + match[0].length - 1));
    }
    for (const match of source.matchAll(/\b([A-Za-z]*Identifier|identifier)\s*:(?!:)/g)) {
      if (!identifierLabels.has(match[1])) continue;
      if (unrelatedIdentifierCalls.has(enclosingCall(source, match.index))) continue;
      expressions.push(readExpression(source, match.index + match[0].length));
    }
    for (const match of source.matchAll(/\bvar\s+([A-Za-z]*Identifier)\s*:\s*String\s*\{/g)) {
      expressions.push(readBlock(source, match.index + match[0].length - 1));
    }

    const seen = new Set();
    for (const expression of expressions) {
      for (const literal of stringLiterals(expression.text)) {
        const offset = expression.start + literal.offset;
        if (seen.has(offset) || literal.template.length === 0) continue;
        seen.add(offset);
        const location = `${relative}:${lineAt(source, offset)}`;
        if (literal.template.includes("{}")) add(templates, literal.template, location);
        else add(declared, literal.template, location);
      }
    }
  }

  const problems = [];
  for (const [template, locations] of templates) {
    const expansion = interpolatedIdentifiers[template];
    if (!expansion) {
      problems.push(`Interpolated identifier "${template}" (${locations.join(", ")}) needs an entry in interpolatedIdentifiers.`);
      continue;
    }
    for (const identifier of expansion) add(declared, identifier, `${locations[0]} (${template})`);
  }
  for (const template of Object.keys(interpolatedIdentifiers)) {
    if (!templates.has(template)) problems.push(`interpolatedIdentifiers lists "${template}", which the demo no longer declares.`);
  }
  return { declared, problems };
}

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const repeatedRows = Object.entries(interpolatedIdentifiers)
  .filter(([, identifiers]) => identifiers.length === 1)
  .map(([template, [identifier]]) => ({
    pattern: new RegExp(`^${template.split("{}").map(escapeRegExp).join("[A-Za-z0-9_]+")}$`),
    identifier,
  }));

/// The declared identifiers a flow's `id` selector reaches: the identifier
/// itself, the row a repeated-row identifier stands for, or a regex match.
/// A JavaScript expression in the id picks a row at run time
/// (`food-picker-result-${output.live.foodIndex}`), so it resolves like a row
/// index.
function resolveReference(reference, declared) {
  const id = reference.replace(/\$\{[^}]*\}/g, "0");
  if (declared.has(id)) return [id];
  const row = repeatedRows.find(({ pattern }) => pattern.test(id));
  if (row) return [row.identifier];
  return [...declared.keys()].filter((identifier) => {
    try { return new RegExp(`^(?:${id})$`).test(identifier); } catch { return false; }
  });
}

// MARK: - Maestro YAML (the subset the flows use)

function parseScalar(raw) {
  const value = raw.trim();
  if (value === "") return null;
  if (value.startsWith("\"") && value.endsWith("\"")) return JSON.parse(value);
  if (value.startsWith("'") && value.endsWith("'")) return value.slice(1, -1).replace(/''/g, "'");
  if (value === "true") return true;
  if (value === "false") return false;
  return value;
}

/// Splits `key: value` outside quotes; returns null when the line is not a mapping entry.
function splitEntry(text) {
  let quote = null;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (quote) { if (character === quote) quote = null; continue; }
    if (character === "\"" || character === "'") { quote = character; continue; }
    if (character === ":" && (index === text.length - 1 || text[index + 1] === " ")) {
      return [text.slice(0, index).trim(), text.slice(index + 1)];
    }
  }
  return null;
}

function parseYAML(text, file) {
  const lines = [];
  for (const [number, line] of text.split("\n").entries()) {
    const withoutComment = line.replace(/(^|\s)#.*$/, "");
    if (withoutComment.trim() === "") continue;
    lines.push({ indent: withoutComment.search(/\S/), text: withoutComment.trim(), number: number + 1 });
  }
  let position = 0;

  function parseBlock(indent) {
    const first = lines[position];
    if (!first || first.indent < indent) return null;
    return first.text.startsWith("- ") || first.text === "-" ? parseSequence(first.indent) : parseMapping(first.indent);
  }

  function parseSequence(indent) {
    const items = [];
    while (position < lines.length && lines[position].indent === indent && (lines[position].text.startsWith("- ") || lines[position].text === "-")) {
      const line = lines[position];
      const rest = line.text.slice(1).trim();
      if (rest === "") {
        position += 1;
        items.push(parseBlock(indent + 1));
      } else if (splitEntry(rest)) {
        // "- key: value" opens a mapping whose keys align with `key`.
        lines[position] = { indent: indent + 2, text: rest, number: line.number };
        items.push(parseMapping(indent + 2));
      } else {
        position += 1;
        items.push(parseScalar(rest));
      }
    }
    return items;
  }

  function parseMapping(indent) {
    const mapping = {};
    while (position < lines.length && lines[position].indent === indent && !lines[position].text.startsWith("- ")) {
      const line = lines[position];
      const entry = splitEntry(line.text);
      if (!entry) throw new Error(`${file}:${line.number}: expected "key: value", found "${line.text}"`);
      const [key, rawValue] = entry;
      position += 1;
      if (rawValue.trim() !== "") {
        mapping[key] = parseScalar(rawValue);
      } else if (position < lines.length && lines[position].indent > indent) {
        mapping[key] = parseBlock(lines[position].indent);
      } else if (position < lines.length && lines[position].indent === indent && lines[position].text.startsWith("- ")) {
        mapping[key] = parseSequence(indent);
      } else {
        mapping[key] = null;
      }
    }
    return mapping;
  }

  const documents = [];
  const sections = [];
  let current = [];
  for (const line of lines) {
    if (line.text === "---" && line.indent === 0) { sections.push(current); current = []; continue; }
    current.push(line);
  }
  sections.push(current);
  for (const section of sections) {
    lines.splice(0, lines.length, ...section);
    position = 0;
    documents.push(lines.length === 0 ? null : parseBlock(0));
    if (position < lines.length) throw new Error(`${file}:${lines[position].number}: unexpected indentation`);
  }
  return documents;
}

function readFlow(file) {
  const documents = parseYAML(readFileSync(file, "utf8"), path.relative(root, file));
  const header = documents.length > 1 ? documents[0] ?? {} : {};
  const commands = documents.length > 1 ? documents[1] ?? [] : documents[0] ?? [];
  return { header, commands: Array.isArray(commands) ? commands : [] };
}

const substitute = (value, env) =>
  typeof value === "string" ? value.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (whole, name) => env[name] ?? whole) : value;

/// Every identifier a flow reaches, with how: "tap", "visible", or a
/// non-counting kind ("optional", "not-visible", "condition").
function flowReferences(file, env = {}, stack = []) {
  if (stack.includes(file)) throw new Error(`Recursive runFlow: ${[...stack, file].join(" -> ")}`);
  const references = [];
  const { commands } = readFlow(file);

  const selectorID = (selector) =>
    selector && typeof selector === "object" && selector.id != null ? substitute(String(selector.id), env) : null;
  const add = (selector, kind, optional) => {
    const id = selectorID(selector);
    if (id) references.push({ id, kind: optional ? "optional" : kind });
  };

  const walk = (list, subEnv, inherited) => {
    for (const command of list ?? []) {
      if (!command || typeof command !== "object") continue;
      for (const [name, argument] of Object.entries(command)) {
        const optional = inherited || (argument && typeof argument === "object" && argument.optional === true);
        switch (name) {
          case "tapOn":
          case "doubleTapOn":
          case "longPressOn":
            add(argument, "tap", optional);
            break;
          case "assertVisible":
            add(argument, "visible", optional);
            break;
          case "assertNotVisible":
            add(argument, "not-visible", optional);
            break;
          case "extendedWaitUntil":
            add(argument?.visible, "visible", optional);
            add(argument?.notVisible, "not-visible", optional);
            break;
          case "scrollUntilVisible":
            add(argument?.element, "visible", optional);
            break;
          case "copyTextFrom":
            add(argument, "visible", optional);
            break;
          case "retry":
            walk(argument?.commands, subEnv, optional);
            break;
          case "repeat":
            walk(argument?.commands, subEnv, optional);
            break;
          case "runFlow": {
            const spec = typeof argument === "string" ? { file: argument } : argument ?? {};
            const nextEnv = { ...subEnv, ...Object.fromEntries(Object.entries(spec.env ?? {}).map(([key, value]) => [key, substitute(String(value), subEnv)])) };
            // A `when` condition makes the whole block conditional.
            const conditional = optional || spec.when != null;
            if (spec.when) {
              add(spec.when.visible, "condition", true);
              add(spec.when.notVisible, "condition", true);
            }
            if (spec.file) {
              const target = path.resolve(path.dirname(file), spec.file);
              for (const reference of flowReferences(target, nextEnv, [...stack, file])) {
                references.push(conditional && reference.kind !== "condition" ? { ...reference, kind: "optional" } : reference);
              }
            }
            if (spec.commands) walk(spec.commands, nextEnv, conditional);
            break;
          }
          default:
            break;
        }
      }
    }
  };
  walk(commands, env, false);
  return references;
}

// MARK: - Report

const { declared, problems } = declaredIdentifiers();
const flowFiles = files(flowsRoot, ".yaml").sort();
const exercisedBy = new Map();
const referencedBy = new Map();
const countedFlows = [];

for (const file of flowFiles) {
  const name = path.relative(maestroRoot, file);
  const tags = readFlow(file).header.tags ?? [];
  if (!Array.isArray(tags) || tags.length === 0) {
    problems.push(`${name} has no tags; tag every flow fixture, parity, or live.`);
    continue;
  }
  for (const tag of tags) {
    if (!knownTags.has(tag)) problems.push(`${name} has an unknown tag "${tag}".`);
  }
  const counted = tags.some((tag) => coverageTags.has(tag));
  if (counted) countedFlows.push(name);
  for (const reference of flowReferences(file)) {
    const matches = resolveReference(reference.id, declared);
    if (matches.length === 0) {
      problems.push(`${name} refers to id "${reference.id}", which the demo does not declare.`);
      continue;
    }
    for (const identifier of matches) {
      referencedBy.set(identifier, new Set([...(referencedBy.get(identifier) ?? []), name]));
      if (counted && (reference.kind === "tap" || reference.kind === "visible")) {
        exercisedBy.set(identifier, new Set([...(exercisedBy.get(identifier) ?? []), name]));
      }
    }
  }
}

const identifiers = [...declared.keys()].sort();
const covered = identifiers.filter((identifier) => exercisedBy.has(identifier));
const uncovered = identifiers.filter((identifier) => !exercisedBy.has(identifier));
const percent = identifiers.length === 0 ? 100 : (covered.length / identifiers.length) * 100;

console.log(`UI coverage: ${covered.length}/${identifiers.length} (${percent.toFixed(1)}%)`);
console.log(`Declared identifiers: ${identifiers.length}; flows counted (fixture, parity): ${countedFlows.length} of ${flowFiles.length}`);
if (process.argv.includes("--list")) {
  for (const identifier of identifiers) {
    const flows = [...(exercisedBy.get(identifier) ?? [])].map((flow) => path.basename(flow, ".yaml"));
    console.log(`  ${exercisedBy.has(identifier) ? "✓" : "✗"} ${identifier}${flows.length ? `  ← ${flows.join(", ")}` : ""}`);
  }
}
if (uncovered.length > 0) {
  console.log(`Uncovered (${uncovered.length}):`);
  for (const identifier of uncovered) {
    const note = referencedBy.has(identifier) ? " (referenced only as optional, not visible, a condition, or by a live flow)" : "";
    console.log(`  - ${identifier}  ${declared.get(identifier)[0]}${note}`);
  }
}
if (problems.length > 0) {
  console.log(`Problems (${problems.length}):`);
  for (const problem of problems) console.log(`  - ${problem}`);
}
if (uncovered.length > 0 || problems.length > 0) process.exit(1);
