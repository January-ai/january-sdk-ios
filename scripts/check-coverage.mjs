#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = path.join(root, ".build", "coverage");
const resultBundle = path.join(outputDirectory, "JanuarySDK.xcresult");

const simulatorListing = JSON.parse(
  execFileSync("xcrun", ["simctl", "list", "devices", "available", "-j"], {
    encoding: "utf8",
  }),
);
const simulator = Object.entries(simulatorListing.devices)
  .filter(([runtime]) => runtime.includes("iOS"))
  .flatMap(([, devices]) => devices)
  .find((device) => device.isAvailable && device.name.startsWith("iPhone"));

if (!simulator) {
  throw new Error("No available iPhone Simulator was found for JanuarySDK tests.");
}

mkdirSync(outputDirectory, { recursive: true });
rmSync(resultBundle, { recursive: true, force: true });

execFileSync(
  "xcodebuild",
  [
    "-scheme", "January",
    "-destination", `platform=iOS Simulator,id=${simulator.udid}`,
    "-enableCodeCoverage", "YES",
    "-resultBundlePath", resultBundle,
    "-quiet",
    "CODE_SIGNING_ALLOWED=NO",
    "test",
  ],
  { cwd: root, stdio: "inherit" },
);

const report = JSON.parse(
  execFileSync("xcrun", ["xccov", "view", "--report", "--json", resultBundle], {
    cwd: root,
    encoding: "utf8",
  }),
);
const target = report.targets.find((candidate) => candidate.name === "January");
if (!target) {
  throw new Error("January was not present in the iOS coverage report.");
}

// Native camera and voice adapters are validated by compiling and launching the
// example app; deterministic unit coverage applies to their reusable SDK logic.
const coverageExcludedFiles = new Set([
  "JanuaryMealScanner.swift",
  "MealCameraViewController.swift",
  "ScannerLoadingSpinner.swift",
  "SystemVoiceCapture.swift",
]);
const coveredFiles = target.files.filter((file) => !coverageExcludedFiles.has(file.name));
const coveredLines = coveredFiles.reduce((total, file) => total + file.coveredLines, 0);
const executableLines = coveredFiles.reduce((total, file) => total + file.executableLines, 0);
const linePercent = (coveredLines / executableLines) * 100;
const minimumLinePercent = 85;

console.log(
  `JanuarySDK iOS coverage: ${coveredLines}/${executableLines} lines ` +
    `(${linePercent.toFixed(2)}%).`,
);

if (linePercent < minimumLinePercent) {
  throw new Error(
    `JanuarySDK iOS line coverage must remain at or above ${minimumLinePercent}%.`,
  );
}
