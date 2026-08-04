/**
 * opencode-autonomy — Modern entry points
 *
 * - Default export is v1 plugin (config hook) for broad compat
 * - Also exports v2 promise/effect compatible plugins
 * - `define` usage follows @opencode-ai/plugin v2 spec
 *
 * Durability: all transforms are wrapped so a single bad agent
 * does not crash the host session.
 */
import { AutonomyPlugin } from "./plugin.js";
import { AUTONOMY_NOTICE, AUTONOMY_CONFIG, AUTONOMY_AGENTS } from "./autonomy.js";

import { define } from "@opencode-ai/plugin/v2/promise";

export const AutonomyPluginV2 = define({
  id: "opencode-autonomy",
  setup: async (ctx) => {
    ctx.agent.transform((draft) => {
      try {
        for (const [id, def] of Object.entries(AUTONOMY_AGENTS)) {
          try {
            const existing = draft.get(id);
            if (existing) {
              draft.update(id, (agent: any) => {
                try {
                  agent.mode = (def as any).mode;
                  agent.steps = (def as any).steps;
                } catch (e: any) {
                  console.warn(
                    `[opencode-autonomy] v2 transform for ${id} failed: ${e?.message ?? e} — skipping`,
                  );
                }
              });
            }
          } catch (e: any) {
            console.warn(
              `[opencode-autonomy] v2 lookup for ${id} failed: ${e?.message ?? e} — skipping`,
            );
          }
        }
      } catch (e: any) {
        console.warn(
          `[opencode-autonomy] v2 transform outer failed: ${e?.message ?? e} — continuing`,
        );
      }
    });
  },
});

// Re-exports
export { AutonomyPlugin };
export default AutonomyPlugin;

// Also export constants for library consumers / CLI
export { AUTONOMY_CONFIG, AUTONOMY_AGENTS, AUTONOMY_NOTICE };

// For convenience in docs, export plugin as named "plugin" per some conventions
export const plugin = AutonomyPlugin;
