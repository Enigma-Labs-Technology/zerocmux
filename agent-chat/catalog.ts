export interface AgentModelCatalogEntry {
  id: string;
  label: string;
  description?: string;
  contextWindow?: string | number;
  supportsOneMillion?: boolean;
  fast?: boolean;
  minVersion?: string;
  deprecated?: boolean;
  efforts?: AgentModelChoice[];
  defaultEffort?: string;
  serviceTiers?: AgentModelServiceTier[];
  defaultServiceTier?: string | null;
}

export interface AgentModelChoice {
  value: string;
  label: string;
  description?: string;
}

export interface AgentModelServiceTier {
  id: string;
  name: string;
  description?: string;
}

export interface AgentModelProviderCatalog {
  defaultModel: string;
  models: AgentModelCatalogEntry[];
}

export interface AgentModelCatalogPayload {
  schemaVersion: 1;
  updatedAt: string;
  providers: Partial<Record<"claude" | "codex" | "gemini", AgentModelProviderCatalog>>;
}

const PROVIDERS = ["claude", "codex", "gemini"] as const;
export const AGENT_MODEL_CATALOG_TTL_MS = 60 * 60_000;

export function validateAgentModelCatalog(input: unknown): AgentModelCatalogPayload {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("model catalog must be an object");
  const raw = input as Record<string, unknown>;
  if (raw.schemaVersion !== 1) throw new Error(`unsupported model catalog schemaVersion: ${String(raw.schemaVersion)}`);
  if (typeof raw.updatedAt !== "string" || !raw.updatedAt) throw new Error("model catalog updatedAt must be a string");
  if (!raw.providers || typeof raw.providers !== "object" || Array.isArray(raw.providers)) throw new Error("model catalog providers must be an object");
  const source = raw.providers as Record<string, unknown>;
  const providers: AgentModelCatalogPayload["providers"] = {};
  for (const provider of PROVIDERS) {
    const parsed = validateProvider(source[provider]);
    if (parsed) providers[provider] = parsed;
  }
  return { schemaVersion: 1, updatedAt: raw.updatedAt, providers };
}

function validateProvider(input: unknown): AgentModelProviderCatalog | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const raw = input as Record<string, unknown>;
  if (!Array.isArray(raw.models)) return null;
  const seen = new Set<string>();
  const models = raw.models.flatMap((model) => {
    const parsed = validateModel(model);
    if (!parsed || seen.has(parsed.id)) return [];
    seen.add(parsed.id);
    return [parsed];
  });
  if (!models.length) return null;
  const requested = typeof raw.defaultModel === "string" ? raw.defaultModel : "";
  const defaultModel = models.some((model) => model.id === requested) ? requested : models[0]!.id;
  return { defaultModel, models };
}

function validateModel(input: unknown): AgentModelCatalogEntry | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const raw = input as Record<string, unknown>;
  if (typeof raw.id !== "string" || !raw.id || typeof raw.label !== "string" || !raw.label) return null;
  const out: AgentModelCatalogEntry = { id: raw.id, label: raw.label };
  if (typeof raw.description === "string") out.description = raw.description;
  if (typeof raw.contextWindow === "string" || typeof raw.contextWindow === "number") out.contextWindow = raw.contextWindow;
  for (const key of ["supportsOneMillion", "fast", "deprecated"] as const) if (typeof raw[key] === "boolean") out[key] = raw[key];
  if (typeof raw.minVersion === "string" && raw.minVersion) out.minVersion = raw.minVersion;
  if (Array.isArray(raw.efforts)) {
    const efforts = raw.efforts.flatMap((effort) => {
      if (!effort || typeof effort !== "object" || Array.isArray(effort)) return [];
      const item = effort as Record<string, unknown>;
      if (typeof item.value !== "string" || !item.value || typeof item.label !== "string" || !item.label) return [];
      return [{ value: item.value, label: item.label, ...(typeof item.description === "string" ? { description: item.description } : {}) }];
    });
    if (efforts.length) {
      out.efforts = efforts;
      const requested = typeof raw.defaultEffort === "string" ? raw.defaultEffort : "";
      out.defaultEffort = efforts.some((effort) => effort.value === requested) ? requested : efforts[0]!.value;
    }
  }
  if (Array.isArray(raw.serviceTiers)) {
    const serviceTiers = raw.serviceTiers.flatMap((tier) => {
      if (!tier || typeof tier !== "object" || Array.isArray(tier)) return [];
      const item = tier as Record<string, unknown>;
      if (typeof item.id !== "string" || !item.id || typeof item.name !== "string" || !item.name) return [];
      return [{ id: item.id, name: item.name, ...(typeof item.description === "string" ? { description: item.description } : {}) }];
    });
    if (serviceTiers.length) out.serviceTiers = serviceTiers;
    if (raw.defaultServiceTier === null) out.defaultServiceTier = null;
    else if (typeof raw.defaultServiceTier === "string" && serviceTiers.some((tier) => tier.id === raw.defaultServiceTier)) out.defaultServiceTier = raw.defaultServiceTier;
  }
  return out;
}

export function mergeCatalogModels<T extends { id: string }>(
  remote: AgentModelProviderCatalog | undefined,
  binary: T[],
  fallback: T[],
  hasRemotePayload: boolean,
  fromRemote: (model: AgentModelCatalogEntry) => T,
): T[] {
  const base = remote ? remote.models.map(fromRemote) : hasRemotePayload ? [] : fallback;
  const byId = new Map(base.map((model) => [model.id, model]));
  for (const model of binary) {
    const existing = byId.get(model.id);
    byId.set(model.id, existing ? { ...model, ...existing } : model);
  }
  return [...byId.values()];
}

export function selectEnabledModel<T extends { id: string; disabled?: boolean }>(defaultModel: string, models: T[]): string {
  const preferred = models.find((model) => model.id === defaultModel && !model.disabled);
  return preferred?.id ?? models.find((model) => !model.disabled)?.id ?? "";
}

// zerocmux: the upstream store fetched https://cmux.com/api/agent-models with
// ETag revalidation and an on-disk cache. zerocmux ships no remote catalog:
// models come from the built-in lists plus models reported by installed agent
// CLIs (mergeCatalogModels). The store keeps its upstream surface so server.ts
// is unchanged, but it never performs network or file I/O.
export class AgentModelCatalogStore {
  private state: AgentModelCatalogPayload | null = null;
  private listeners = new Set<(payload: AgentModelCatalogPayload) => void>();

  get payload(): AgentModelCatalogPayload | null { return this.state; }
  get hasPayload(): boolean { return this.state !== null; }
  provider(id: string): AgentModelProviderCatalog | undefined {
    return this.state?.providers[id as keyof AgentModelCatalogPayload["providers"]];
  }
  subscribe(listener: (payload: AgentModelCatalogPayload) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
  /** Local-only: apply a caller-supplied payload (e.g. tests, future local config). */
  apply(input: unknown): boolean {
    const payload = validateAgentModelCatalog(input);
    const changed = JSON.stringify(payload) !== JSON.stringify(this.state);
    this.state = payload;
    if (changed) for (const listener of this.listeners) listener(payload);
    return changed;
  }
  isStale(): boolean { return false; }
  refreshIfStale(): Promise<boolean> { return Promise.resolve(false); }
  refresh(): Promise<boolean> { return Promise.resolve(false); }
}

export const agentModelCatalog = new AgentModelCatalogStore();
