#!/usr/bin/env node
/**
 * opencode-autonomy CLI — npx entry
 *
 * Usage:
 *   npx opencode-autonomy
 *   npx opencode-autonomy@latest --clean
 *   npx opencode-autonomy --dry-run
 *   opencode-autonomy --help
 *
 * What it does:
 *   - Merges autonomy keys into ~/.config/opencode/opencode.json (preserving model/provider)
 *   - Copies agents/*.md, commands/*.md, scripts/*.sh from bundled assets
 *   - With --clean, deletes stale .md files not in source + prunes backups to 3
 *   - Validates via `opencode debug config` if opencode binary present
 *
 * This file is intentionally ESM + Node builtins only (no deps) so npx works everywhere.
 */

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync, unlinkSync, statSync, rmSync } from "fs";
import { join, dirname, basename } from "path";
import { fileURLToPath } from "url";
import { execSync } from "child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// pkgRoot is one level up from bin/
const PKG_ROOT = join(__dirname, "..");
const SRC_AGENTS = join(PKG_ROOT, "agents");
const SRC_COMMANDS = join(PKG_ROOT, "commands");
const SRC_SCRIPTS = join(PKG_ROOT, "scripts");
const SRC_EXAMPLE = join(PKG_ROOT, "opencode.json.example");
const VERSION = (() => {
  try {
    const pkg = JSON.parse(readFileSync(join(PKG_ROOT, "package.json"), "utf8"));
    return pkg.version || "0.0.0";
  } catch { return "0.0.0"; }
})();

const HOME = process.env.HOME || process.env.USERPROFILE;
const DEST_BASE = process.env.XDG_CONFIG_HOME ? join(process.env.XDG_CONFIG_HOME, "opencode") : (HOME ? join(HOME, ".config", "opencode") : join(process.cwd(), ".config", "opencode"));

const AUTONOMY_NOTICE = `
⚠️  AUTONOMY MODE — Opinionated permissions enabled:

  permission: {"*":"allow", external_directory:"allow", doom_loop:"allow"}
  → Agents will edit files, run bash, install deps, WITHOUT asking.
  → They batch 3-5 files, run lint/type/test/build, auto-fix failures.
  → This is intentional for long-horizon minimal-intervention shipping.

  If you need safe mode: Tab → 'plan' agent (ask-mode), or remove permission override.
  Details: https://github.com/vocino/opencode-autonomy#autonomy--permissions

`;

function logInfo(msg) { process.stdout.write(`[INFO] ${msg}\n`); }
function logOk(msg) { process.stdout.write(`[OK] ${msg}\n`); }
function logWarn(msg) { process.stdout.write(`[WARN] ${msg}\n`); }
function logErr(msg) { process.stderr.write(`[ERR] ${msg}\n`); }

function parseArgs() {
  const raw = process.argv.slice(2);
  const flags = {
    clean: false,
    dryRun: false,
    help: false,
    disable: false,
    version: false,
    dest: DEST_BASE,
  };
  for (const a of raw) {
    if (a === "--clean") flags.clean = true;
    else if (a === "--dry-run" || a === "-n") flags.dryRun = true;
    else if (a === "--help" || a === "-h") flags.help = true;
    else if (a === "--version" || a === "-V") flags.version = true;
    else if (a === "--disable") flags.disable = true;
    else if (a.startsWith("--dest=")) flags.dest = a.slice(7);
    else if (a === "--dest" ) { /* next arg */ }
  }
  // handle --dest <path>
  const destIdx = raw.indexOf("--dest");
  if (destIdx !== -1 && raw[destIdx+1]) flags.dest = raw[destIdx+1];
  return flags;
}

function printHelp() {
  console.log(`
opencode-autonomy v${VERSION} — autonomy-first opencode suite

Usage:
  npx opencode-autonomy [options]
  opencode-autonomy --clean           # also deletes stale .md + prunes backups
  npx opencode-autonomy@latest --clean # update to latest + clean

Options:
  --clean       Delete stale *.md/*.sh in dest not in source, prune backups to 3
  --dry-run     Show what would happen without writing
  --disable     Restore backup if exists (undo autonomy)
  --dest <dir>  Override destination (default: ~/.config/opencode or $XDG_CONFIG_HOME/opencode)
  --help        This help
  --version     Show version

What it does:
  1. Creates ~/.config/opencode/{agents,commands,scripts}
  2. Merges autonomy keys into opencode.json (preserves your model/provider)
     - snapshot, formatter, lsp, tool_output, compaction, experimental, permission, agent defaults
  3. Copies agents/build.md, fixer.md, commands/ship.md, fix.md, scripts/detect-oracle.sh
  4. Validates with 'opencode debug config' if opencode installed

Notes:
${AUTONOMY_NOTICE}
  Docs: https://github.com/vocino/opencode-autonomy
  Plugin: Add "opencode-autonomy" to opencode.json "plugin": [...] for runtime enforcement.
`);
}

function ensureDir(p) {
  mkdirSync(p, { recursive: true });
}

function listFiles(dir, ext) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(f => !ext || f.endsWith(ext)).map(f => join(dir, f));
}

function syncDir(srcPatternDir, destDir, flags) {
  const srcFiles = listFiles(srcPatternDir, null).filter(f => f.endsWith(".md") || f.endsWith(".sh"));
  if (!existsSync(srcPatternDir)) {
    logWarn(`source ${srcPatternDir} missing, skipping`);
    return 0;
  }
  ensureDir(destDir);
  let cnt = 0;
  const srcBasenames = new Set();
  for (const sf of srcFiles) {
    const bn = basename(sf);
    srcBasenames.add(bn);
    const destFile = join(destDir, bn);
    if (!flags.dryRun) {
      try { cpSync(sf, destFile); } catch (e) { logWarn(`cp ${bn} failed: ${e.message}`); continue; }
      if (bn.endsWith(".sh")) {
        try { execSync(`chmod +x "${destFile}"`); } catch {}
      }
    }
    cnt++;
  }
  logOk(`${cnt} files -> ${destDir}${flags.dryRun ? " (dry-run)" : ""}`);

  if (flags.clean) {
    const destCandidates = listFiles(destDir, ".md").concat(listFiles(destDir, ".sh"));
    for (const df of destCandidates) {
      const bn = basename(df);
      if (!srcBasenames.has(bn)) {
        if (!flags.dryRun) {
          try { unlinkSync(df); } catch {}
        }
        logInfo(`[CLEAN] removed stale ${bn} from ${basename(destDir)}/`);
      }
    }
  }
  return cnt;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function writeJson(path, data, dryRun) {
  if (dryRun) {
    logInfo(`would write ${path}`);
    return;
  }
  writeFileSync(path, JSON.stringify(data, null, 2) + "\n", "utf8");
}

function main() {
  const flags = parseArgs();
  if (flags.help) { printHelp(); process.exit(0); }
  if (flags.version) { console.log(VERSION); process.exit(0); }

  const DEST = flags.dest;
  const destAgents = join(DEST, "agents");
  const destCommands = join(DEST, "commands");
  const destScripts = join(DEST, "scripts");
  const destConfig = join(DEST, "opencode.json");

  logInfo(`${PKG_ROOT} -> ${DEST} (clean=${flags.clean ? 1 : 0}, dry=${flags.dryRun ? 1 : 0}) version ${VERSION}`);

  // show autonomy notice on every run (user must see it)
  process.stdout.write(AUTONOMY_NOTICE);

  if (flags.disable) {
    // try restore latest backup
    const bakFiles = (() => {
      if (!existsSync(DEST)) return [];
      try {
        return readdirSync(DEST)
          .filter(f => f.startsWith("opencode.json.bak."))
          .map(f => join(DEST, f))
          .sort((a,b) => {
            const sa = statSync(a).mtimeMs;
            const sb = statSync(b).mtimeMs;
            return sb - sa;
          });
      } catch { return []; }
    })();
    if (bakFiles.length > 0) {
      const latest = bakFiles[0];
      logInfo(`Restoring backup ${basename(latest)}`);
      if (!flags.dryRun) cpSync(latest, destConfig);
      logOk(`restored ${basename(latest)} -> opencode.json`);
    } else {
      logWarn("No backup found to restore");
    }
    process.exit(0);
  }

  ensureDir(DEST);
  ensureDir(destAgents);
  ensureDir(destCommands);
  ensureDir(destScripts);

  // backup + prune
  if (existsSync(destConfig)) {
    if (!flags.dryRun) {
      const ts = Date.now();
      const bakPath = `${destConfig}.bak.${ts}`;
      cpSync(destConfig, bakPath);
      logInfo(`backup ${basename(bakPath)}`);
    }
    if (flags.clean) {
      try {
        const baks = readdirSync(DEST).filter(f => f.startsWith("opencode.json.bak.")).map(f => join(DEST, f)).sort((a,b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
        const KEEP = 3;
        for (const extra of baks.slice(KEEP)) {
          if (!flags.dryRun) try { unlinkSync(extra); } catch {}
          logInfo(`[CLEAN] pruned backup ${basename(extra)}`);
        }
      } catch {}
    }
  }

  // read example + dest
  const exampleJson = readJson(SRC_EXAMPLE);
  if (!exampleJson) {
    logErr(`Missing ${SRC_EXAMPLE} — cannot install`);
    process.exit(1);
  }

  const AUTONOMY_KEYS = ["subagent_depth","snapshot","formatter","lsp","tool_output","compaction","experimental","permission","agent"];
  const autonomySlice = {};
  for (const k of AUTONOMY_KEYS) {
    if (exampleJson[k] !== undefined) autonomySlice[k] = exampleJson[k];
  }

  if (!existsSync(destConfig)) {
    logInfo(`No opencode.json, creating from example`);
    if (flags.dryRun) {
      logInfo(`would create ${destConfig}`);
    } else {
      // create from example (which already contains provider meta + openrouter with placeholders)
      cpSync(SRC_EXAMPLE, destConfig);
    }
    logOk(`created opencode.json from example`);
  } else {
    // merge: preserve user's model/provider, overlay autonomy keys
    const destJson = readJson(destConfig);
    if (!destJson) {
      logWarn(`Existing ${destConfig} invalid JSON, overwriting from example`);
      if (!flags.dryRun) cpSync(SRC_EXAMPLE, destConfig);
    } else {
      // Try jq-like merge if example exists: preserve model, small_model, provider (user's)
      // Strategy: dest * autonomySlice overrides, but model/small_model/provider kept from dest if present
      // If dest has custom model, keep it.
      const userModel = destJson.model;
      const userSmall = destJson.small_model;
      const userProvider = destJson.provider;

      // start with dest, overlay autonomy
      let merged = { ...destJson, ...autonomySlice };

      // restore user model/provider
      if (userModel) merged.model = userModel;
      if (userSmall) merged.small_model = userSmall;
      // provider: merge autonomy providers into user provider, user wins on key conflict for apiKey etc but we ensure meta/openrouter exist
      if (userProvider) {
        merged.provider = { ...(autonomySlice.provider?._isFallback ? {} : {}), ...userProvider };
        // Ensure our two providers exist even if user had only custom
        for (const [pid, pdef] of Object.entries(exampleJson.provider || {})) {
          if (!merged.provider[pid]) {
            merged.provider[pid] = pdef;
          }
        }
      } else {
        merged.provider = exampleJson.provider;
      }
      // Ensure model defaults exist if not set
      if (!merged.model) merged.model = exampleJson.model;
      if (!merged.small_model) merged.small_model = exampleJson.small_model;

      // Write merged
      if (flags.dryRun) {
        logInfo(`would merge autonomy keys into ${destConfig} (preserve model=${userModel || "default"})`);
      } else {
        writeJson(destConfig, merged, false);
      }
      logOk(`merged autonomy keys (preserved model/provider)`);
    }
  }

  // sync agents/commands/scripts
  syncDir(SRC_AGENTS, destAgents, flags);
  syncDir(SRC_COMMANDS, destCommands, flags);
  // scripts: special handling (all .sh)
  if (existsSync(SRC_SCRIPTS)) {
    ensureDir(destScripts);
    const shs = listFiles(SRC_SCRIPTS, ".sh");
    for (const s of shs) {
      const bn = basename(s);
      if (!flags.dryRun) {
        cpSync(s, join(destScripts, bn));
        try { execSync(`chmod +x "${join(destScripts, bn)}"`); } catch {}
      }
    }
    logOk(`${shs.length} files -> ${destScripts}${flags.dryRun ? " (dry-run)" : ""}`);
    if (flags.clean) {
      // prune stale .sh not in source
      const srcSet = new Set(shs.map(s => basename(s)));
      const destShs = listFiles(destScripts, ".sh");
      for (const df of destShs) {
        if (!srcSet.has(basename(df))) {
          if (!flags.dryRun) try { unlinkSync(df); } catch {}
          logInfo(`[CLEAN] removed stale ${basename(df)} from scripts/`);
        }
      }
    }
  }

  // validate opencode config if binary available
  try {
    execSync("which opencode", { stdio: "ignore" });
    if (!flags.dryRun) {
      try {
        execSync("opencode debug config", { env: { ...process.env, XDG_CONFIG_HOME: process.env.XDG_CONFIG_HOME || (HOME ? join(HOME, ".config") : undefined) }, stdio: "pipe" });
        logOk("opencode debug config passes");
      } catch (e) {
        const out = e.stdout?.toString() || e.stderr?.toString() || e.message;
        logErr(`config invalid — check ${destConfig}\n${out.slice(0,500)}`);
        // Don't exit 1 on dry-run; but for real run, we should exit 1 to surface issue
        if (!flags.dryRun) process.exitCode = 1;
      }
    } else {
      logInfo("dry-run: would validate opencode debug config");
    }
  } catch {
    logWarn("opencode not installed — https://opencode.ai — skipping validation");
  }

  if (flags.dryRun) {
    logInfo("dry-run complete — no files written");
  } else {
    logOk("done. Restart opencode (quit + opencode) if running. Try: /ship Implement hello world component");
  }

  // Suggest plugin array method for runtime enforcement
  console.log(`
Next: You can also enforce autonomy at runtime by adding to opencode.json:

  "plugin": ["opencode-autonomy"]

Then opencode will auto-install this package on startup and force:
  permission allow-all, batch_tool, big tool_output, etc.

This file install is for agents/commands markdown. The plugin array is for live config.
Both work together — npx gives files, plugin gives runtime guarantees.

Update anytime:
  npx opencode-autonomy@latest --clean
`);
}

try {
  main();
} catch (err) {
  logErr(err.stack || err.message || String(err));
  process.exit(1);
}
