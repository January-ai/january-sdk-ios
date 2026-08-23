#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const root = new URL("../", import.meta.url).pathname;

execFileSync(
  "swift",
  ["test", "--disable-automatic-resolution", "--enable-code-coverage"],
  { cwd: root, stdio: "inherit" },
);

const coveragePath = execFileSync("swift", ["test", "--show-codecov-path"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const coverage = JSON.parse(readFileSync(coveragePath, "utf8"));
const sourceMarker = "/Sources/JanuaryPartnerSDK/";
const files = coverage.data[0].files.filter((file) => file.filename.includes(sourceMarker));

if (files.length === 0) {
  throw new Error("No handwritten JanuaryPartnerSDK source files were present in the coverage report.");
}

const uncovered = files.filter(
  (file) =>
    file.summary.lines.covered !== file.summary.lines.count ||
    file.summary.regions.covered !== file.summary.regions.count,
);
if (uncovered.length > 0) {
  for (const file of uncovered) {
    const lines = file.summary.lines;
    const regions = file.summary.regions;
    console.error(
      `${file.filename}: ${lines.covered}/${lines.count} lines (${lines.percent.toFixed(2)}%), ` +
        `${regions.covered}/${regions.count} regions (${regions.percent.toFixed(2)}%)`,
    );
  }
  throw new Error("Handwritten JanuaryPartnerSDK line and region coverage must remain at 100%.");
}

const totals = files.reduce(
  (result, file) => ({
    linesCovered: result.linesCovered + file.summary.lines.covered,
    linesCount: result.linesCount + file.summary.lines.count,
    regionsCovered: result.regionsCovered + file.summary.regions.covered,
    regionsCount: result.regionsCount + file.summary.regions.count,
  }),
  { linesCovered: 0, linesCount: 0, regionsCovered: 0, regionsCount: 0 },
);
console.log(
  `Handwritten JanuaryPartnerSDK coverage: ${totals.linesCovered}/${totals.linesCount} lines and ` +
    `${totals.regionsCovered}/${totals.regionsCount} regions (100%).`,
);
