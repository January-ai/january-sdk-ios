import assert from "node:assert/strict";
import { buildSDKVocabulary } from "./build-sdk-vocabulary.mjs";

const operation = {
  operationId: "getFood",
  resource: "foods",
  resourceType: "FoodsResource",
  publicMethod: "get",
  publicInput: "GetFoodRequest",
  publicResult: { type: "Food" },
  lifecycle: { status: "active" },
};

const surface = {
  operations: [
    operation,
    {
      ...operation,
      operationId: "autocompleteFoods",
      publicMethod: "autocomplete",
      publicResult: null,
      lifecycle: { status: "reserved" },
    },
  ],
  rendering: {
    symbols: [{ symbol: "resources.foods", scope: "resources", swift: "foods" }],
  },
};

const vocabulary = buildSDKVocabulary(surface, "1.2.0");
assert.deepEqual(
  vocabulary.operations.map(({ operationId }) => operationId),
  ["getFood"],
  "reserved operations must not be projected into the public Swift vocabulary",
);
assert.throws(
  () => buildSDKVocabulary({ ...surface, operations: [{ ...operation, publicResult: null }] }, "1.2.0"),
  /non-reserved operation is missing a public result type/,
);

console.log("PASS Swift SDK vocabulary projection");
