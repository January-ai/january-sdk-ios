import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = path.resolve(import.meta.dirname, "..");
const vocabulary = JSON.parse(
  await readFile(path.join(root, "Contract/sdk-vocabulary.json"), "utf8"),
);
const lock = JSON.parse(
  await readFile(path.join(root, "Contract/sdk-contract.lock.json"), "utf8"),
);

async function swiftSources(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...await swiftSources(absolute));
    if (entry.isFile() && entry.name.endsWith(".swift")) {
      result.push({ path: absolute, source: await readFile(absolute, "utf8") });
    }
  }
  return result;
}

function escaped(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const publicSources = await swiftSources(path.join(root, "Sources/JanuarySDK"));
const generatedSources = await swiftSources(path.join(root, "Sources/JanuaryPartnerTransport/Generated"));
const surfaceTest = await readFile(
  path.join(root, "Tests/JanuarySDKTests/PublicSurfaceTests.swift"),
  "utf8",
);
const errors = [];

if (vocabulary.contractVersion !== lock.contractVersion) {
  errors.push("SDK vocabulary does not match the locked contract version");
}

for (const operation of vocabulary.operations) {
  const resourcePattern = new RegExp(
    `public\\s+(?:struct|class|actor)\\s+${escaped(operation.resourceType)}\\b`,
  );
  const resourceSource = publicSources.find((file) => resourcePattern.test(file.source));
  if (!resourceSource) {
    errors.push(`${operation.operationId}: missing public resource ${operation.resourceType}`);
    continue;
  }
  if (!new RegExp(`public\\s+func\\s+${escaped(operation.publicMethod)}\\s*\\(`).test(resourceSource.source)) {
    errors.push(`${operation.operationId}: missing public method ${operation.resourceType}.${operation.publicMethod}`);
  }
  if (!new RegExp(`\\.${escaped(operation.operationId)}\\s*\\(`).test(resourceSource.source)) {
    errors.push(`${operation.operationId}: public method is not mapped to its generated transport operation`);
  }
  for (const type of [operation.publicInput, operation.publicResult]) {
    const typePattern = new RegExp(
      `public\\s+(?:struct|enum|class|actor|typealias)\\s+${escaped(type)}\\b`,
    );
    if (!publicSources.some((file) => typePattern.test(file.source))) {
      errors.push(`${operation.operationId}: missing public type ${type}`);
    }
  }
  if (!new RegExp(`public\\s+let\\s+${escaped(operation.resource)}\\s*:\\s*${escaped(operation.resourceType)}\\b`)
    .test(publicSources.map((file) => file.source).join("\n"))) {
    errors.push(`${operation.operationId}: JanuaryClient does not expose ${operation.resource}`);
  }
  if (!generatedSources.some((file) => new RegExp(`package\\s+func\\s+${escaped(operation.operationId)}\\s*\\(`).test(file.source))) {
    errors.push(`${operation.operationId}: generated transport operation is missing`);
  }
  if (!surfaceTest.includes(`"${operation.operationId}"`)) {
    errors.push(`${operation.operationId}: public surface test coverage is missing`);
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`Public Swift API matches the contract vocabulary (${vocabulary.operations.length} operations).`);
}
