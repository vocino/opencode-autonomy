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
 */

import type { Plugin, Config } from "@opencode-ai/plugin";
import { AUTONOMY_CONFIG, AUTONOMY_AGENTS, AUTONOMY_PROVIDERS, AUTONOMY_MODELS } from "./autonomy.js";

// Deep clone + deep merge helpers — no deps, safe for provider merging
function deepClone<T>(obj: T): T {
  // structuredClone is available in modern Node/Bun, fallback to JSON
  try {
    if (typeof structuredClone === "function") return (structuredClone as any)(obj);
  } catch {
    // ignore
  }
  return JSON.parse(JSON.stringify(obj));
}

// Merge source into target, source wins for scalars, deep-merge for objects.
// Does NOT mutate source; mutates target (which should be a clone of defaults).
function deepMerge(target: any, source: Record<string, any>): any {
  for (const [k, v] of Object.entries(source)) {
    if (v && typeof v === "object" && !Array.isArray(v)) {
      if (!target[k] || typeof target[k] !== "object" || Array.isArray(target[k])) target[k] = {} as any;
      deepMerge(target[k], v);
    } else {
      // scalar, array, null, etc — user wins
      target[k] = v;
    }
  }
  return target;
}

export const AutonomyPlugin: Plugin = async () => {
  // Log once on init — visible via opencode logs
  // We intentionally don't console.log here to avoid spam; config hook will handle notice via tui toast if possible

  return {
    /**
     * Inject autonomy defaults into the running config.
     * This runs BEFORE agents are resolved, so it sets the baseline
     * without clobbering user's file on disk. It's also what makes
     * `npx opencode-autonomy` and plugin array both give autonomy.
     */
    config: async (input: Config) => {
      const cfg = input as any;

      // --- core autonomy — FORCE these, with opinionated values ---
      // These are what make autonomy-first work; we set them explicitly.
      cfg.subagent_depth = AUTONOMY_CONFIG.subagent_depth;
      cfg.snapshot = AUTONOMY_CONFIG.snapshot;
      cfg.formatter = AUTONOMY_CONFIG.formatter;
      cfg.lsp = AUTONOMY_CONFIG.lsp;
      cfg.tool_output = { ...AUTONOMY_CONFIG.tool_output };
      cfg.compaction = { ...AUTONOMY_CONFIG.compaction };
      cfg.experimental = { ...(cfg.experimental ?? {}), ...AUTONOMY_CONFIG.experimental };

      // Permission is the most opinionated bit — we FORCE allow-all.
      // User can still override per-agent (plan is ask-mode).
      cfg.permission = { ...AUTONOMY_CONFIG.permission };

      // --- models — only set defaults if user hasn't chosen ---
      if (!cfg.model) cfg.model = AUTONOMY_MODELS.model;
      if (!cfg.small_model) cfg.small_model = AUTONOMY_MODELS.small_model;

      // --- providers — merge, preserve user providers, add ours if missing ---
      // Regression guard for #6: user apiKey must never be overwritten by defaults.
      // deepMerge is user-wins, but we add explicit post-merge check for auth keys.
      cfg.provider ??= {};
      for (const [pId, pDef] of Object.entries(AUTONOMY_PROVIDERS)) {
        const userProv = cfg.provider[pId] as any;
        if (!userProv) {
          cfg.provider[pId] = deepClone(pDef as any);
        } else {
          const userOpts = userProv?.options as any;
          const hadUserApiKey = userOpts?.apiKey !== undefined;
          const hadUserBaseURL = userOpts?.baseURL !== undefined;
          const userApiKeyPrev = hadUserApiKey ? deepClone(userOpts.apiKey) : undefined;
          const userBasePrev = hadUserBaseURL ? deepClone(userOpts.baseURL) : undefined;
          // User values win; defaults fill missing gaps. Deep clone to avoid mutating AUTONOMY_PROVIDERS.
          const merged = deepMerge(deepClone(pDef as any), userProv);
          // Defensive: restore user auth if deepMerge somehow lost it (future regression)
          if (hadUserApiKey) {
            merged.options ??= {};
            merged.options.apiKey = userApiKeyPrev;
          }
          if (hadUserBaseURL) {
            merged.options ??= {};
            merged.options.baseURL = userBasePrev;
          }
          // Ensure user's model overwrites win per model id, while preserving nested defaults
          if ((pDef as any).models) {
            merged.models = {
              ...deepClone((pDef as any).models),
              ...(merged.models ?? {}),
            };
          }
          cfg.provider[pId] = merged;
        }
      }

      // --- agents — ensure our 4 exist, preserve user custom agents ---
      cfg.agent ??= {};
      for (const [aId, aDef] of Object.entries(AUTONOMY_AGENTS)) {
        if (!cfg.agent[aId]) {
          cfg.agent[aId] = deepClone(aDef as any);
        } else {
          // merge: keep user's model if set, fill missing mode/steps/temperature/description
          const existing = cfg.agent[aId];
          cfg.agent[aId] = {
            model: (existing as any).model ?? (aDef as any).model,
            mode: (existing as any).mode ?? (aDef as any).mode,
            steps: (existing as any).steps ?? (aDef as any).steps,
            temperature: (existing as any).temperature ?? (aDef as any).temperature,
            description: (existing as any).description ?? (aDef as any).description,
            // preserve user's permission override for plan, but for build/fixer/explore we keep ours if not set
            permission: (existing as any).permission ?? (aDef as any).permission,
            // spread any other custom keys user had
            ...((existing as any).prompt ? { prompt: (existing as any).prompt } : {}),
          } as any;
          // If user explicitly had permission for build/fixer, respect it? No, we want autonomy, so only fallback
        }
      }

      // --- commands — ensure ship/fix exist as JSON commands if no markdown files ---
      // This allows plugin users without copied markdown to still get /ship via config
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
            "6. Ship — Report changes, verification, commit message.",
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
    },

    /**
     * Optional: Toast to make permissions explicit to user once per session.
     */
    event: async ({ event }: { event: any }) => {
      if (event?.type === "session.created") {
        // We don't want to spam; only log via client.app.log on real plugin API
        // Keeping this empty to avoid noise — README documents autonomy warning.
      }
    },
  };
};

// Default export so `import opencode-autonomy` works, and named for explicit.
export default AutonomyPlugin;
