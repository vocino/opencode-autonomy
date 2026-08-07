/**
 * Single source of truth for autonomy opinionated config.
 * Both the npx installer and the opencode plugin import from here.
 */

export const AUTONOMY_CONFIG = {
  subagent_depth: 3,
  snapshot: true,
  formatter: true,
  lsp: true,
  tool_output: { max_lines: 5000, max_bytes: 204_800 },
  compaction: { auto: true, tail_turns: 12, reserved: 20_000 },
  experimental: { batch_tool: true, continue_loop_on_deny: true },
  permission: { "*": "allow", external_directory: "allow", doom_loop: "allow" },
} as const;

export const AUTONOMY_AGENTS = {
  build: {
    mode: "primary" as const,
    steps: 300,
    temperature: 0.2,
    model: "meta/muse-spark-1.2-contributor",
    description: "High-autonomy build agent — ships features end-to-end",
  },
  fixer: {
    mode: "subagent" as const,
    steps: 150,
    temperature: 0.1,
    model: "openrouter/anthropic/claude-sonnet-4-5",
    description: "Fixer — closes the loop on lint, type, test, build failures",
  },
  explore: {
    mode: "subagent" as const,
    steps: 80,
    model: "openrouter/qwen/qwen3-coder",
    description: "Fast code search — parallel exploration",
  },
  plan: {
    mode: "primary" as const,
    steps: 200,
    temperature: 0.4,
    model: "meta/muse-spark-1.2-contributor",
    description: "Council orchestrator — meta leads 2 cursor specialists for robust, creative plans",
    permission: {
      bash: "ask",
      edit: "ask",
      write: "ask",
      read: "allow",
      glob: "allow",
      grep: "allow",
      list: "allow",
      task: "allow",
      external_directory: "allow",
    },
  },
  "council-critic": {
    mode: "subagent" as const,
    steps: 120,
    temperature: 0.3,
    model: "cursor/claude-opus-4-6",
    description: "Council critic — rigorous, finds flaws, risks, edge cases",
    permission: {
      bash: "ask",
      edit: "ask",
      write: "ask",
      read: "allow",
      glob: "allow",
      grep: "allow",
      list: "allow",
      task: "allow",
      external_directory: "allow",
    },
  },
  "council-creative": {
    mode: "subagent" as const,
    steps: 120,
    temperature: 0.8,
    model: "cursor/composer-2.5",
    description: "Council creative — divergent, novel, interesting approaches",
    permission: {
      bash: "ask",
      edit: "ask",
      write: "ask",
      read: "allow",
      glob: "allow",
      grep: "allow",
      list: "allow",
      task: "allow",
      external_directory: "allow",
    },
  },
};

export const AUTONOMY_PROVIDERS = {
  meta: {
    npm: "@ai-sdk/openai",
    name: "Meta",
    options: {
      baseURL: "https://api.meta.ai/v1",
      apiKey: "{file:~/.config/opencode/meta-api-key}",
    },
    models: {
      "muse-spark-1.1": {
        name: "Muse Spark 1.1",
        reasoning: true,
        limit: { context: 1_048_576, output: 131_072 },
      },
      "muse-spark-1.2": {
        name: "Muse Spark 1.2",
        reasoning: true,
        limit: { context: 1_048_576, output: 131_072 },
      },
      "muse-spark-1.2-contributor": {
        name: "Muse Spark 1.2 Contributor",
        reasoning: true,
        limit: { context: 1_048_576, output: 131_072 },
        modalities: { input: ["text", "image", "pdf", "video", "audio"], output: ["text"] },
        options: { reasoningEffort: "high", reasoningSummary: "auto", include: ["reasoning.encrypted_content"] },
      },
    },
  },
  openrouter: {
    options: { apiKey: "{env:OPENROUTER_API_KEY}" },
  },
  cursor: {
    npm: "@stablekernel/opencode-cursor",
    name: "cursor",
    options: {
      apiKey: "{file:~/.config/opencode/cursor-account1.key}",
      forwardMcp: true,
      toolDisplay: "blocks",
      systemPrompt: "rules",
      session: "auto",
      sandbox: false,
    },
  },
};

export const AUTONOMY_MODELS = {
  model: "meta/muse-spark-1.2-contributor",
  small_model: "openrouter/google/gemini-flash-latest",
};

/**
 * Human-readable notice about autonomy tradeoffs.
 */
export const AUTONOMY_NOTICE = `
⚠️  AUTONOMY MODE: This suite is opinionated for minimal user intervention.

What it sets (and why):
  - permission: {"*":"allow", external_directory:"allow", doom_loop:"allow"}
    → Agents never ask to edit/read/run bash. They ship end-to-end.
    → Risk: they CAN rm -rf, push code, install deps without asking.
  - experimental.batch_tool=true + continue_loop_on_deny=true
    → 3-5 files batched, then verified. No "should I continue?" prompts.
  - tool_output 5000 lines / 200KB, compaction tail 12, 1M context reserved 20k
    → Long tasks survive full lint→type→test→build→fix loops.
  - subagent_depth=3 → build → @explore → @fixer chains work.
  - formatter + lsp + snapshot enabled

If you want ask-mode, use Tab to switch to 'plan' agent (bash/edit/write = ask).
To disable autonomy: remove this plugin from opencode.json or run:
  opencode-autonomy --disable (restores backup if present)
`;
