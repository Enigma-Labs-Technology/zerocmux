import { expect, test } from "bun:test";
import { AgentModelCatalogStore, mergeCatalogModels, selectEnabledModel, validateAgentModelCatalog } from "../catalog";
import { mergeAcpModelOption } from "../adapters/acp";
import { mergeCodexModels } from "../adapters/codex";
import { mergeRemoteModelOptionsForTest } from "../server";

const payload = {
  schemaVersion: 1,
  updatedAt: "2026-07-09T00:00:00Z",
  providers: {
    claude: {
      defaultModel: "filtered-out",
      models: [
        { id: "claude-new", label: "Claude New", minVersion: "3.0.0", supportsOneMillion: true },
        { id: "broken" },
      ],
    },
    codex: {
      defaultModel: "gpt-new",
      models: [{
        id: "gpt-new",
        label: "GPT New",
        description: "Remote description",
        contextWindow: 400000,
        efforts: [
          { value: "none", label: "none" },
          { value: "xhigh", label: "Extra high", description: "Remote effort" },
        ],
        defaultEffort: "xhigh",
        serviceTiers: [{ id: "priority", name: "Priority", description: "Remote tier" }],
        defaultServiceTier: "priority",
      }],
    },
  },
} as const;

test("catalog validation and provider merges", () => {
  expect(() => validateAgentModelCatalog({ ...payload, schemaVersion: 2 })).toThrow("unsupported");
  const parsed = validateAgentModelCatalog(payload);
  expect(parsed.providers.claude?.models).toHaveLength(1);
  expect(parsed.providers.claude?.defaultModel).toBe("claude-new");

  const acp = mergeAcpModelOption(
    { id: "model", label: "Model", kind: "select", value: "binary-current", choices: [{ value: "binary-listed", label: "Binary Listed" }] },
    [{ value: "remote", label: "Remote" }],
    "remote",
  );
  expect(acp.value).toBe("binary-current");
  expect(acp.choices?.map((choice) => choice.value)).toEqual(["remote", "binary-listed", "binary-current"]);

  const remoteCodex = parsed.providers.codex!;
  const codex = mergeCodexModels([{
    value: "gpt-new",
    label: "Binary Label",
    description: "Binary description",
    efforts: [{ value: "high", label: "high" }],
    defaultEffort: "high",
    serviceTiers: [{ id: "fast", name: "Fast" }],
    defaultServiceTier: null,
  }], remoteCodex);
  expect(codex[0]?.label).toBe("GPT New");
  expect(codex[0]?.description).toBe("Remote description");
  expect(codex[0]?.contextWindow).toBe(400000);
  expect(codex[0]?.efforts.map((effort) => effort.value)).toEqual(["xhigh"]);
  expect(codex[0]?.defaultEffort).toBe("xhigh");
  expect(codex[0]?.serviceTiers[0]?.id).toBe("priority");
  expect(codex[0]?.defaultServiceTier).toBe("priority");

  const remoteOnly = mergeCodexModels([], remoteCodex)[0]!;
  expect(remoteOnly.efforts.map((effort) => effort.value)).toEqual(["xhigh"]);
  expect(remoteOnly.defaultEffort).toBe("xhigh");
  expect(remoteOnly.serviceTiers[0]?.name).toBe("Priority");

  const catchOptions = mergeRemoteModelOptionsForTest("codex", [
    { id: "model", label: "Model", kind: "select", value: "", choices: [] },
    { id: "effort", label: "Effort", kind: "select", value: "medium", choices: [{ value: "medium", label: "medium" }] },
  ], remoteCodex);
  const catchModel = catchOptions.find((option) => option.id === "model");
  expect(catchModel?.value).toBe("gpt-new");
  expect(catchModel?.choices?.map((choice) => choice.value)).toContain("gpt-new");

  expect(selectEnabledModel("gated", [
    { id: "gated", disabled: true },
    { id: "supported", disabled: false },
  ])).toBe("supported");

  const merged = mergeCatalogModels(
    remoteCodex,
    [{ id: "gpt-new", label: "Binary" }, { id: "binary-only", label: "Binary Only" }],
    [{ id: "built-in", label: "Built In" }],
    true,
    (model) => ({ id: model.id, label: model.label }),
  );
  expect(merged.map((model) => model.id)).toEqual(["gpt-new", "binary-only"]);
  expect(merged[0]?.label).toBe("GPT New");
});

// zerocmux: the store is local-only — no fetch, no ETag revalidation, no
// on-disk cache. Payloads only enter through apply(); refresh()/refreshIfStale()
// are inert so server.ts's background refresh loop stays a no-op.
test("catalog store is local-only: apply() sets state, refresh() never fetches", async () => {
  const store = new AgentModelCatalogStore();
  expect(store.hasPayload).toBe(false);
  expect(store.payload).toBeNull();
  expect(store.provider("codex")).toBeUndefined();
  expect(store.isStale()).toBe(false);
  await expect(store.refresh()).resolves.toBe(false);
  await expect(store.refreshIfStale()).resolves.toBe(false);
  expect(store.hasPayload).toBe(false);

  const seen: string[] = [];
  const unsubscribe = store.subscribe((p) => seen.push(p.updatedAt));
  expect(store.apply(payload)).toBe(true);
  expect(seen).toEqual(["2026-07-09T00:00:00Z"]);
  expect(store.hasPayload).toBe(true);
  expect(store.provider("codex")?.models[0]?.label).toBe("GPT New");
  expect(store.provider("claude")?.defaultModel).toBe("claude-new");
  expect(store.provider("gemini")).toBeUndefined();

  // Re-applying an identical payload neither notifies nor reports a change.
  expect(store.apply(payload)).toBe(false);
  expect(seen).toEqual(["2026-07-09T00:00:00Z"]);

  // Invalid payloads throw from validation and leave prior state intact.
  expect(() => store.apply({ ...payload, schemaVersion: 99 })).toThrow("unsupported");
  expect(store.provider("codex")?.models[0]?.label).toBe("GPT New");

  unsubscribe();
  expect(store.apply({ ...payload, updatedAt: "2026-07-10T00:00:00Z" })).toBe(true);
  expect(seen).toEqual(["2026-07-09T00:00:00Z"]);
});
