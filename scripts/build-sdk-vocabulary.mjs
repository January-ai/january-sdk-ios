import { readFile, writeFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

export function buildSDKVocabulary(surface, contractVersion) {
  const operations = surface.operations
    .filter((operation) => operation.lifecycle?.status !== "reserved")
    .map((operation) => {
      if (!operation.publicResult?.type) {
        throw new Error(
          `${operation.operationId}: non-reserved operation is missing a public result type`,
        );
      }

      return {
        operationId: operation.operationId,
        resource: operation.resource,
        resourceType: operation.resourceType,
        publicMethod: operation.publicMethod,
        publicInput: operation.publicInput,
        publicResult: operation.publicResult.type,
      };
    });

  return {
    version: 1,
    contractVersion,
    operations,
    swiftSymbols: surface.rendering.symbols.map(({ symbol, scope, swift }) => ({
      symbol,
      scope,
      swift,
    })),
  };
}

async function main() {
  const [surfacePath, outputPath, contractVersion] = process.argv.slice(2);
  if (!surfacePath || !outputPath || !contractVersion) {
    throw new Error(
      "Usage: node scripts/build-sdk-vocabulary.mjs <sdk-surface.json> <output.json> <contract-version>",
    );
  }

  const surface = JSON.parse(await readFile(surfacePath, "utf8"));
  const vocabulary = buildSDKVocabulary(surface, contractVersion);
  await writeFile(outputPath, `${JSON.stringify(vocabulary, null, 2)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
