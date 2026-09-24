#!/usr/bin/env node
// Runs the demo's live flows (flows/9x-live-*.yaml) one at a time against the
// January API through a token endpoint, and stops cleanly at the first failure,
// in particular when the API answers 429 rate_limited, printing the command
// that resumes the run from that flow.
//
//   node Examples/JanuaryPartnerDemo/.maestro/run-live.mjs --end-user your-test-user
//
//   --end-user ID      required: the dedicated test user the flows write to
//   --token-url URL    default: the local token relay; any endpoint must, like the local
//                      relay, need no session token: the flows never pass credentials,
//                      since the app would get them as launch arguments and Maestro
//                      records its variables in its debug output
//   --from NN          start at flow NN, e.g. --from 95 to resume
//   --only NN,NN       run only these flows
//   --pause SECONDS    wait between flows to spread the requests out (default 20)
//   --output DIR       screenshots, logs, and Maestro debug output (default ./live-run-<time>)
//   --device ID        passed to Maestro
//   --rehearse         use the local fixture server (port 18768) as both the token
//                      endpoint and the API (Debug builds only), and count the
//                      requests each flow makes
//
// Before the first flow it makes one token request and one API request, so a
// run never starts into an exhausted allowance. The weight flow runs last
// because weight logs cannot be deleted; a run that stops earlier logs none.
// MAESTRO overrides the maestro command.
import { spawn } from "node:child_process";
import { mkdirSync, readFileSync, readdirSync, createWriteStream } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const flowsDirectory = path.join(here, "flows");
const fixtureOrigin = "http://127.0.0.1:18768";
const relayURL = "http://127.0.0.1:8787/api/january/client-token";
const apiOrigin = "https://partners.january.ai";

function parseArguments(argv) {
  const options = { pause: 20 };
  for (let index = 0; index < argv.length; index += 1) {
    const name = argv[index];
    const value = () => {
      const next = argv[index + 1];
      if (next === undefined) throw new Error(`${name} needs a value`);
      index += 1;
      return next;
    };
    switch (name) {
      case "--end-user": options.endUser = value(); break;
      case "--token-url": options.tokenURL = value(); break;
      case "--from": options.from = Number(value()); break;
      case "--only": options.only = value().split(",").map(Number); break;
      case "--pause": options.pause = Number(value()); break;
      case "--output": options.output = value(); break;
      case "--device": options.device = value(); break;
      case "--rehearse": options.rehearse = true; break;
      default: throw new Error(`Unknown option ${name}`);
    }
  }
  if (!options.endUser) throw new Error("Pass --end-user with a dedicated test user.");
  return options;
}

const options = parseArguments(process.argv.slice(2));
const tokenURL = options.rehearse ? `${fixtureOrigin}/api/january/client-token` : options.tokenURL ?? relayURL;
const api = options.rehearse ? fixtureOrigin : apiOrigin;
const timezone = process.env.TIMEZONE ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
const today = new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format(new Date());
const output = path.resolve(options.output ?? `live-run-${new Date().toISOString().replace(/[:.]/g, "-")}`);
mkdirSync(output, { recursive: true });
const runLog = createWriteStream(path.join(output, "run-live.log"), { flags: "a" });
const say = (line) => {
  const redacted = String(line).replace(/(Bearer\s+)[^\s"']+/g, "$1[redacted]");
  console.log(redacted);
  runLog.write(`${new Date().toISOString()} ${redacted}\n`);
};

// Weight logs cannot be deleted, so the weight flow runs last whatever its number.
const weightLast = (name) => (name.includes("-live-weight") ? 1 : 0);
const liveFlows = readdirSync(flowsDirectory)
  .filter((name) => /^9\d-live-.*\.yaml$/.test(name))
  .sort((a, b) => weightLast(a) - weightLast(b) || a.localeCompare(b));
const flowNumber = (name) => Number(name.slice(0, 2));
// --from resumes at that flow in the running order, so a resumed run still ends with the weight flow.
const fromIndex = options.from ? liveFlows.findIndex((name) => flowNumber(name) === options.from) : 0;
const flows = options.only
  ? liveFlows.filter((name) => options.only.includes(flowNumber(name)))
  : fromIndex < 0 ? [] : liveFlows.slice(fromIndex);
if (flows.length === 0) throw new Error("No live flows match the selection.");

function resumeCommand(from) {
  const parts = ["node Examples/JanuaryPartnerDemo/.maestro/run-live.mjs", `--end-user ${options.endUser}`];
  if (options.tokenURL) parts.push(`--token-url ${options.tokenURL}`);
  if (options.rehearse) parts.push("--rehearse");
  if (options.device) parts.push(`--device ${options.device}`);
  parts.push(`--from ${from}`);
  return parts.join(" ");
}

async function preflight() {
  const token = await fetch(tokenURL, { method: "POST", headers: { "January-End-User-ID": options.endUser } });
  if (token.status === 429) return { limited: `the token endpoint answered 429: ${await token.text()}` };
  if (token.status === 401 || token.status === 403) {
    throw new Error(`The token endpoint at ${tokenURL} requires a session token (HTTP ${token.status}). The live flows run only against an endpoint that needs none, such as the local relay.`);
  }
  if (!token.ok) throw new Error(`The token endpoint at ${tokenURL} answered HTTP ${token.status}. Is it running?`);
  const { token: value } = await token.json();
  const probe = await fetch(
    `${api}/v1.2/water-logs?start_date=${today}&end_date=${today}&timezone=${encodeURIComponent(timezone)}&unit=fl_oz`,
    { headers: { Authorization: `Bearer ${value}` } },
  );
  const body = await probe.text();
  if (probe.status === 429) return { limited: body };
  if (!probe.ok) throw new Error(`The API answered HTTP ${probe.status}: ${body}`);
  say(`Preflight: token endpoint and API answered for ${options.endUser} (per-minute requests left: ${probe.headers.get("x-ratelimit-remaining") ?? "not reported"}).`);
  return {};
}

function runMaestro(flow) {
  const directory = path.join(output, path.basename(flow, ".yaml"));
  mkdirSync(directory, { recursive: true });
  const variables = [`END_USER_ID=${options.endUser}`, `TOKEN_URL=${tokenURL}`, `TIMEZONE=${timezone}`];
  if (options.rehearse) variables.push(`API_URL=${fixtureOrigin}`, "SUGGEST_QUERY=fixture", "PORTION_FOOD_ID=103", "PORTION_SERVING_ID=31");
  const args = [
    ...(options.device ? ["--device", options.device] : []),
    "test", path.join(flowsDirectory, flow), "--include-tags", "live",
    ...variables.flatMap((variable) => ["-e", variable]),
    "--debug-output", path.join(directory, "debug"), "--flatten-debug-output",
  ];
  return new Promise((resolve) => {
    const log = createWriteStream(path.join(directory, "maestro.log"));
    const child = spawn(process.env.MAESTRO ?? "maestro", args, { cwd: directory });
    let text = "";
    const collect = (chunk) => { text += chunk; log.write(chunk); };
    child.stdout.on("data", collect);
    child.stderr.on("data", collect);
    child.on("close", (code) => { log.end(); resolve({ code, text, directory }); });
  });
}

function rateLimited(result) {
  // Maestro's debug output repeats live-api.js's source, which names RATE_LIMITED and HTTP 429
  // itself, so only the error it throws counts: "RATE_LIMITED: the January API refused GET ...".
  const pattern = /RATE_LIMITED: the January API refused [^'\s]|rate_limited|Too many requests/;
  if (pattern.test(result.text)) return true;
  try {
    const debug = path.join(result.directory, "debug");
    return readdirSync(debug)
      .filter((name) => name.startsWith("commands-") || name === "maestro.log")
      .some((name) => pattern.test(readFileSync(path.join(debug, name), "utf8")));
  } catch {
    return false;
  }
}

async function fixtureRequests() {
  const response = await fetch(`${fixtureOrigin}/__requests`);
  return response.json();
}

function peakPerMinute(requests) {
  const times = requests.map((request) => request.at).filter(Boolean).sort((a, b) => a - b);
  let peak = 0;
  for (let start = 0, end = 0; end < times.length; end += 1) {
    while (times[end] - times[start] >= 60) start += 1;
    peak = Math.max(peak, end - start + 1);
  }
  return peak;
}

const results = [];
const counts = [];
say(`Live flows for ${options.endUser} against ${api} (timezone ${timezone}, day ${today}); output in ${output}`);
const gate = await preflight();
if (gate.limited) {
  say(`The January API is refusing requests (429 rate_limited): ${gate.limited}`);
  say(`Nothing was run. When the allowance reopens, run:\n  ${resumeCommand(Number(flows[0].slice(0, 2)))}`);
  process.exit(2);
}

for (const [position, flow] of flows.entries()) {
  if (position > 0 && options.pause > 0) {
    say(`Pausing ${options.pause} s before ${flow} to spread the requests out.`);
    await new Promise((resolve) => setTimeout(resolve, options.pause * 1000));
  }
  if (options.rehearse) await fetch(`${fixtureOrigin}/__reset`);
  say(`Running ${flow}`);
  const result = await runMaestro(flow);
  if (options.rehearse) {
    const requests = await fixtureRequests();
    const apiRequests = requests.filter((request) => request.path.startsWith("/v1.2/"));
    const tokenRequests = requests.filter((request) => request.path === "/api/january/client-token");
    counts.push({ flow, api: apiRequests.length, tokens: tokenRequests.length, peak: peakPerMinute([...apiRequests, ...tokenRequests]) });
    say(`  ${apiRequests.length} API requests and ${tokenRequests.length} token requests; at most ${counts.at(-1).peak} in any minute`);
  }
  if (result.code === 0) {
    results.push({ flow, status: "passed" });
    say(`  passed`);
    continue;
  }
  const limited = rateLimited(result);
  results.push({ flow, status: limited ? "stopped: API rate limit (429)" : "failed" });
  say(`  ${limited ? "stopped: the January API answered 429 rate_limited" : "failed"}; see ${result.directory}`);
  break;
}

for (const flow of flows.slice(results.length)) results.push({ flow, status: "not run" });
say("\nSummary");
for (const result of results) say(`  ${result.flow}: ${result.status}`);
if (counts.length > 0) {
  const total = counts.reduce((sum, count) => ({ api: sum.api + count.api, tokens: sum.tokens + count.tokens }), { api: 0, tokens: 0 });
  say(`  Requests: ${total.api} API and ${total.tokens} token requests over ${counts.length} flows`);
}
const stopped = results.find((result) => result.status !== "passed");
if (stopped) {
  say(`\nResume with:\n  ${resumeCommand(Number(stopped.flow.slice(0, 2)))}`);
  process.exit(stopped.status.startsWith("stopped") ? 2 : 1);
}
