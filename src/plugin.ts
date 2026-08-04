/**
 * opencode-autonomy — v1 plugin (config hook) — opinionated autonomy injection
 *
 * This is the primary plugin entry. opencode loads it when you add
 * "opencode-autonomy" to your opencode.json plugin array, or when the
 * package is installed via Bun cache.
 *
 * It injects autonomy defaults (permissions, tool_output, etc) at runtime
 * without overwriting your file, and ensures build/fixer/explore/plan
 * agents + ship/fix commands exist.
 *
 * Durability: config hook must NEVER throw and crash the host session.
 * Each section is isolated so one bad key does not block the rest.
 */

import type { Plugin, Config } from "@opencode-ai/plugin";
import { AUTONOMY_CONFIG, AUTONOMY_AGENTS, AUTONOMY_PROVIDERS, AUTONOMY_MODELS } from "./autonomy.js";

// Deep clone + deep merge helpers — no deps, safe for provider merging
function deepClone<T>(obj: T): T {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj !== "object") return obj;
  try {
    if (typeof structuredClone === "function") return (structuredClone as any)(obj);
  } catch {
    // fall through to JSON
  }
  try {
    return JSON.parse(JSON.stringify(obj));
  } catch {
    // Last resort: if JSON fails (circular etc), return original reference
    // Caller must not mutate. This prevents throw in durability path.
    return obj;
  }
}

// Merge source into target, source wins for scalars, deep-merge for objects.
// Does NOT mutate source; mutates target (which should be a clone of defaults).
function deepMerge(target: any, source: Record<string, any>): any {
  if (!target || typeof target !== "object") target = {};
  if (!source || typeof source !== "object") return target;
  for (const [k, v] of Object.entries(source)) {
    if (v && typeof v === "object" && !Array.isArray(v)) {
      if (!target[k] || typeof target[k] !== "object" || Array.isArray(target[k])) target[k] = {} as any;
      try {
        deepMerge(target[k], v);
      } catch {
        // If nested merge fails, prefer source value (user wins)
        target[k] = deepClone(v);
      }
    } else {
      target[k] = v;
    }
  }
  return target;
}

function isObject(v: unknown): v is Record<string, any> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function safeApply(label: string, fn: () => void): boolean {
  try {
    fn();
    return true;
  } catch (e: any) {
    const msg = e?.message ?? String(e);
    console.warn(`[opencode-autonomy] ${label} failed — continuing with partial config: ${msg}`);
    return false;
  }
}

export const AutonomyPlugin: Plugin = async () => {
  return {
    config: async (input: Config) => {
      if (!isObject(input)) {
        console.warn("[opencode-autonomy] config input not an object — skipping injection");
        return;
      }
      const cfg = input as any;

      // 1. core autonomy — FORCE these
      safeApply("core", () => {
        cfg.subagent_depth = AUTONOMY_CONFIG.subagent_depth;
        cfg.snapshot = AUTONOMY_CONFIG.snapshot;
        cfg.formatter = AUTONOMY_CONFIG.formatter;
        cfg.lsp = AUTONOMY_CONFIG.lsp;
        cfg.tool_output = { ...AUTONOMY_CONFIG.tool_output };
        cfg.compaction = { ...AUTONOMY_CONFIG.compaction };
        cfg.experimental = { ...(cfg.experimental ?? {}), ...AUTONOMY_CONFIG.experimental };
        cfg.permission = { ...AUTONOMY_CONFIG.permission };
      });

      // 2. models — only set defaults if user hasn't chosen
      safeApply("models", () => {
        if (!cfg.model) cfg.model = AUTONOMY_MODELS.model;
        if (!cfg.small_model) cfg.small_model = AUTONOMY_MODELS.small_model;
      });

      // 3. providers — merge, preserve user providers, add ours if missing
      safeApply("providers", () => {
        if (cfg.provider !== undefined && !isObject(cfg.provider)) {
          console.warn("[opencode-autonomy] provider is not an object, resetting");
          cfg.provider = {};
        }
        cfg.provider ??= {};
        for (const [pId, pDef] of Object.entries(AUTONOMY_PROVIDERS)) {
          const userProv = cfg.provider[pId] as any;
          if (!userProv) {
            cfg.provider[pId] = deepClone(pDef as any);
          } else {
            if (!isObject(userProv)) {
              cfg.provider[pId] = deepClone(pDef as any);
              continue;
            }
            const userOpts = userProv?.options as any;
            const hadUserApiKey = isObject(userOpts) && userOpts?.apiKey !== undefined;
            const hadUserBaseURL = isObject(userOpts) && userOpts?.baseURL !== undefined;
            const userApiKeyPrev = hadUserApiKey ? deepClone(userOpts.apiKey) : undefined;
            const userBasePrev = hadUserBaseURL ? deepClone(userOpts.baseURL) : undefined;
            const merged = deepMerge(deepClone(pDef as any), userProv);
            if (hadUserApiKey) {
              merged.options ??= {};
              merged.options.apiKey = userApiKeyPrev;
            }
            if (hadUserBaseURL) {
              merged.options ??= {};
              merged.options.baseURL = userBasePrev;
            }
            if ((pDef as any).models) {
              merged.models = {
                ...deepClone((pDef as any).models),
                ...(merged.models ?? {}),
              };
            }
            cfg.provider[pId] = merged;
          }
        }
      });

      // 4. agents — ensure ours exist, preserve user custom agents
      safeApply("agents", () => {
        if (cfg.agent !== undefined && !isObject(cfg.agent)) {
          console.warn("[opencode-autonomy] agent config not an object, resetting");
          cfg.agent = {};
        }
        cfg.agent ??= {};
        for (const [aId, aDef] of Object.entries(AUTONOMY_AGENTS)) {
          if (!cfg.agent[aId]) {
            cfg.agent[aId] = deepClone(aDef as any);
          } else {
            const existing = cfg.agent[aId];
            if (!isObject(existing)) {
              cfg.agent[aId] = deepClone(aDef as any);
              continue;
            }
            cfg.agent[aId] = {
              model: (existing as any).model ?? (aDef as any).model,
              mode: (existing as any).mode ?? (aDef as any).mode,
              steps: (existing as any).steps ?? (aDef as any).steps,
              temperature: (existing as any).temperature ?? (aDef as any).temperature,
              description: (existing as any).description ?? (aDef as any).description,
              permission: (existing as any).permission ?? (aDef as any).permission,
              ...((existing as any).prompt ? { prompt: (existing as any).prompt } : {}),
            } as any;
          }
        }
      });

      // 5. commands — ensure ship/fix exist as JSON commands if no markdown files
      safeApply("commands", () => {
        if (cfg.command !== undefined && !isObject(cfg.command)) {
          console.warn("[opencode-autonomy] command config not an object, resetting");
          cfg.command = {};
        }
        cfg.command ??= {};
        if (!cfg.command["ship"]) {
          cfg.command["ship"] = {
            description: "Ship — closed loop from concept to verified outcome",
            agent: "build",
            template: [
              "Goal: $ARGUMENTS",
              "",
              "## The closed loop — do not skip phases",
              "1. Concept — Parse intent into concrete outcome + constraints. Scan repo, package.json, AGENTS.md, git status. Use @explore in parallel if needed.",
              "2. Plan — If 3+ steps, TodoWrite immediately (5-15 todos, ONE in_progress).",
              "3. Implement — Batch 3-5 related files. Follow existing patterns.",
              "4. Verify — Run `bash scripts/detect-oracle.sh` or infer from package.json, capture evidence. This is DoD.",
              "5. Fix — Any failure → @fixer, rerun until green or 3x same error.",
              "6. Version — semver.org MAJOR.MINOR.PATCH: MAJOR=baking API, MINOR=feature compat, PATCH=bugfix compat. 0.y.z: MINOR for breaking-ish, PATCH for fix. fix:→PATCH, feat:→MINOR, feat!:→MAJOR. Use smallest appropriate.",
              "7. Ship — Report changes, verification, semver bump + why, commit message (type matches bump).",
            ].join("\n"),
          };
        }
        if (!cfg.command["fix"]) {
          cfg.command["fix"] = {
            description: "Fix — quick repair with verification loop",
            agent: "build",
            template: [
              "Fix: $ARGUMENTS",
              "",
              "## Protocol",
              "1. Understand context — relevant files, @explore, git diff",
              "2. TodoWrite if 3+ steps",
              "3. Batch fix 3-5 files",
              "4. Verify loop via scripts/detect-oracle.sh",
              "5. Report",
            ].join("\n"),
          };
        }
      });
    },

    event: async ({ event }: { event: any }) => {
      try {
        if (event?.type === "session.created") {
          // noop — README documents autonomy warning
        }
      } catch {
        // event hook must never throw
      }
    },
  };
};

// Default export so `import opencode-autonomy` works, and named for explicit.
export default AutonomyPlugin;
