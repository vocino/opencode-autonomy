/**
 * opencode-autonomy — Modern entry points
 *
 * - Default export is v1 plugin (config hook) for broad compat
 * - Also exports v2 promise/effect compatible plugins
 * - `define` usage follows @opencode-ai/plugin v2 spec
 */

import { AutonomyPlugin } from "./plugin.js";
import { AUTONOMY_NOTICE, AUTONOMY_CONFIG, AUTONOMY_AGENTS } from "./autonomy.js";

// v2 promise API — if opencode loads via v2, we provide transform hooks
// that enforce autonomy config via agent/catalog transforms where possible.
// We re-export v1 as default for max compat, since v1 config hook is the only
// place we can set permission/tool_output/etc.
import { define } from "@opencode-ai/plugin/v2/promise";

export const AutonomyPluginV2 = define({
  id: "opencode-autonomy",
  setup: async (ctx) => {
    // Transform existing agents to ensure autonomy defaults
    // Note: v2 AgentDraft has only update, not add. We update if present.
    ctx.agent.transform((draft) => {
      for (const [id, def] of Object.entries(AUTONOMY_AGENTS)) {
        const existing = draft.get(id);
        if (existing) {
          draft.update(id, (agent: any) => {
            // Force autonomy steps/mode but preserve model if user set
            agent.mode = (def as any).mode;
            agent.steps = (def as any).steps;
          });
        }
        // If not existing, we can't add via transform API — v1 config hook handles creation.
        // This is intentional: v1 is source of truth for creation, v2 for transform.
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
