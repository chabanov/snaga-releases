<div align="center">

# Snaga

**Self-Extending AI Coding Agent**

[![Rust](https://img.shields.io/badge/Rust-2024-orange?logo=rust)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)
[![Version](https://img.shields.io/github/v/release/chabanov/snaga-releases?label=version&color=green)](https://github.com/chabanov/snaga-releases/releases/latest)

[Installation](#installation) · [Getting Started](#getting-started) · [Architecture](#architecture) · [Tools](#tools) · [Slash Commands](#slash-commands) · [Skills](#skills) · [Security](https://snaga.ai/security) · [Changelog](https://snaga.ai/changelog)

</div>

---

Snaga is an AI coding agent built in Rust that can **create its own tools at runtime**. It compiles Rust code to WebAssembly, registers it instantly, and runs it in a capability-based sandbox — no redeployment, no restarts.

The agent combines native tools, runtime-created WASM tools, multi-agent orchestration, semantic code search, memory components, and a distributed bridge mode. The exact active tool count and enabled capabilities depend on build features and runtime configuration. Binary size, startup latency, and memory usage vary by build profile and platform; measure the artifact you deploy rather than relying on fixed headline numbers.

```
┌ snaga
│ I want to create a tool for getting the BTC price
│ ┌─ create_tool ──────────────────────────────
│ │ {"name": "crypto_price", ...}
│ └─ ✓ Tool 'crypto_price' created ─── 10.5s
│ ┌─ crypto_price ──────────────────────────────
│ │ {"currency": "BTC"}
│ └─ ✓ BTC = 71,594.005 USD ─── 298ms
└ done
```

## Why Snaga

| | Snaga | Claude Code | Cursor | Aider |
|---|---|---|---|---|
| **Self-extending (runtime tools)** | ✅ | ❌ | ❌ | ❌ |
| **Open source** | ✅ | ❌ | ❌ | ✅ |
| **Distributed cluster** | ✅ | ❌ | ❌ | ❌ |
| **Multi-agent teams** | ✅ | ✅ | ✅ | ❌ |
| **Skills system** | ✅ | ✅ | ❌ | ❌ |
| **MCP support** | ✅ | ✅ | ✅ | ❌ |
| **MCP server mode** | ✅ | ✅ | ✅ | ❌ |
| **Voice coding** | ✅ | ❌ | ❌ | ✅ |
| **Rust-native** | ✅ | ❌ | ❌ | ❌ |
| **Browser automation** | ✅ | ❌ | ❌ | ❌ |
| **Agent modes (Plan/Act)** | ✅ | ✅ | ❌ | ❌ |
| **Auto-checkpoints** | ✅ | ✅ | ❌ | ❌ |

## Core Capabilities

### Self-Extending Tool System

Snaga can create new tools at runtime. When the agent encounters a task it can't solve with existing tools, it can write Rust code, compile it to WASM, and register the tool immediately — all within the same session.

```
Agent decides it needs a new tool
  → CreateToolTool generates Rust scaffold
  → cargo build --target wasm32-wasip2 --release
  → wasmtime loads and validates the WASM component
  → ToolRegistry.register_dynamic() — available instantly
  → Agent uses the tool in the same session
```

> ⚠ **Build prerequisites:** `create_tool` and `spec_build` shell out to `cargo build --target wasm32-wasip2 --release`, so they need a working Rust toolchain on the host plus the `wasm32-wasip2` target installed (`rustup target add wasm32-wasip2`). Without them, the agent can still install pre-built SPECs from the registry (`spec_install @scope/name` skips the local toolchain), but it cannot author new tools or build local SPEC bundles. The single 38 MB binary distribution does not bundle a Rust compiler — that's an explicit design choice to keep the image small.

Tools run in a 4-layer sandbox:
1. **Compilation isolation** — each tool built in its own `wasm32-wasip2` workspace
2. **Component validation** — wasmtime verifies WIT world implementation
3. **Capability-based access** — bitflags per tool (`file_read`, `http_get`, `kv_store`, `logging`, `shell_exec`)
4. **Runtime limits** — epoch-interruption CPU budget, pooling-allocator memory cap, shell-injection regex

### Multi-Agent Orchestration

Snaga can construct purpose-specific worker agents at runtime and run independent work in parallel. Dynamic workers receive a task-specific name, prompt, tool allowlist, model-routing role, and round budget. The following legacy roles remain available for compatibility and as prompt templates:

- **Planner** — breaks down complex tasks into subtasks
- **Coder** — implements code changes
- **Reviewer** — reviews code for quality and security
- **Tester** — generates and runs tests
- **Architect** — designs system architecture

Workers can run in-process (shared memory) or in tmux panes (visible). Teams support auto-review and auto-test after coding.

### Connect a machine to the web (bridge mode)

```bash
snaga connect          # `snaga serve` is an alias
snaga connect --json   # status as JSON lines, for scripts
```

`snaga connect` registers this machine as an executor for your account:
the web (or a Head Agent) sends it tasks, it runs them here with your
local tools, and every dangerous tool call waits for approval on the web.
Nothing listens on this machine — the daemon makes outbound connections
only.

What the wire does today (measured against the production API on
2026-09-07, `docs/BRIDGE-AUDIT-2026-09-07.md` and the plan next to it):

- **Versioned protocol.** The client declares `protocol_version: 2`; the
  server answers with the behaviours it has switched on. The banner shows
  the negotiation: `Protocol: v2 · server v2 · capabilities: cancel,
  task_states, approval_options, ws_events`. Against an older API every
  version-2 behaviour stays off.
- **WebSocket first, HTTP as the fallback — per event.** Tasks are pushed
  over the socket; events go over it too when the server acknowledges
  frames, and any single event the socket does not acknowledge within
  5 s goes over HTTP as the same event. A daemon that fell back to HTTP
  polling tries the socket again every five minutes.
- **Cancel from the web stops the machine in under a second** (was: on the
  next event, 82 s into a `sleep 90`). A pending approval is answered
  `cancelled` instead of timing out.
- **Approvals offer four answers** — `allow_once`, `allow_always`,
  `reject_once`, `reject_always` (the Agent Client Protocol's); an
  `always` is kept for the session, so a tool asked about once is not
  asked about again.
- **A status line** once a minute and on `SIGUSR1`: transport, heartbeat
  failures, events acked / failed, handshakes, reconnects; the same
  counters reach the server every five minutes and show in the agent
  list on the web.
- **Delegations.** Head-agent delegations auto-approve dangerous tools
  only when both sides hold `SNAGA_BRIDGE_DELEGATION_KEY`; the banner's
  `Delegations:` line says which side is missing it and what that means.

### Enhanced Memory

Snaga contains several memory components, but their production wiring differs:

- **KV memory tool/router** — wired when memory initialization succeeds
- **Memory stream, playbook, and reflection** — wired through enhanced memory
- **Session Memory** — implemented, currently default-off and not wired into the main agent loop
- **Long-term Memory** — implemented, currently default-off and not wired into the main agent loop

See the module-level wiring notes in `crates/snaga-core/src/enhanced_memory/mod.rs` before treating an implemented tier as active runtime behaviour.

### Codebase search

The `@codebase` context provider indexes the project locally (TF-IDF) and
retrieves snippets by similarity to the current query, so relevant code reaches
the model without you naming files.

The index is built on first use per working directory and held in memory for
the life of the process — three directories at a time. It is rebuilt when any
file it indexed has changed or gone, checked by `stat` on every lookup.

This paragraph used to say "Index updates incrementally; persistence is
SQLite". Measured 2026-09-22, all of it was wrong: `IndexWatcher` and
`run_watcher_task` are never constructed anywhere, `IndexPersistence` has no
caller outside its own module, and the cache rebuilt only when it was missing
— so a file edited mid-session was still searched at its old content. The
staleness check is new; the watcher and the SQLite persistence are still
unused, and are not claimed here.

The standalone semantic `code_search` tool was removed in the v0.9.9
slim-kernel cleanup — `@codebase`, `grep` and `glob` are the search surface now.

### Voice

`voice_transcribe` and `voice_synthesize` route through the UARP proxy —
speech-to-text and text-to-speech are served by the platform, using the API key
in `~/.snaga/credentials.json`. There is no local Whisper, `say` or `espeak`
path; this README described one until 2026-09-03, and it had not been true for
some time.

### Post-task verification

`--verify` runs a check pass after the turn completes: each modified file is
syntax-checked, and a frontend smoke test runs when the turn wrote an
`index.html` alongside CSS/JS. Results are printed as a summary; on failure the
agent does **not** auto-retry — it surfaces the issues so you decide.

Syntax checking is exposed to the agent as per-language tools (`rust`, `python`,
`typescript`, `go`, and the rest listed under Tools). The standalone
`linter_check` tool that drove clippy/ruff/eslint/golangci-lint was removed in
the v0.9.9 slim-kernel cleanup; run those through `shell`, or install them as
SPECs.

### Circuit Breaker

Built-in circuit breaker for LLM API calls prevents cascading failures:

```
Closed ──(failure_threshold)──► Open
  ▲                                │
  │                          (reset_timeout)
  │                                ▼
  └──(success_threshold)───── HalfOpen
```

### Plan Branches

The `/plan` command creates git-worktree-based plan branches for structured task execution:

```
/plan new <name>       # Create a new plan branch with worktree
/plan branch           # Show current plan branch info
/plan diff             # Show changes in the plan branch
/plan apply            # Merge plan branch into main
/plan discard          # Discard the plan branch and worktree
/plan list             # List all plan branches
```

Plan branches isolate changes in separate worktrees, keeping the main working directory clean until you're ready to apply or discard.

### MCP Server Mode

```bash
snaga mcp-server
```

Exposes Snaga's tools to other agents and applications via the Model Context Protocol over stdio. Any MCP-compatible client (Claude Code, Cursor, etc.) can discover and invoke Snaga tools directly.

### Docker Sandbox

```bash
snaga --sandbox <image>
```

Runs all tool execution inside an ephemeral Docker container. Shell commands, file operations, and other tool calls are isolated from the host system, providing a secure execution environment for untrusted code.

### Memory Router

Unified memory provider architecture with `MemoryRouter`:

- **KV Provider** — simple key-value storage for fast lookups
- **EnhancedMemory Provider** — three-layer memory (working, session, long-term) with semantic search
- **MemoryRouter** — routes memory operations to the appropriate provider based on key patterns and access patterns

### Codebase Search

The `@codebase <query>` context provider enables natural-language code search:

- TF-IDF local indexing for fast, offline code search
- File content chunking with overlap for precise matches
- Rebuilt when an indexed file changes (`stat` per lookup, not a file watcher)
- No external API required — runs entirely locally

### TTL Compaction

System messages support a `ttl_rounds` field that automatically expires stale context between agent rounds. This keeps the context window lean by removing outdated instructions, previous tool results, and intermediate reasoning that's no longer relevant.

### Rate Limiting

Built-in rate limiting for API calls via the `snaga-bridge` `rate_limit` module:

- Configurable requests-per-second and burst capacity
- Per-provider and per-model rate limits
- Automatic backoff when limits are approached
- Prevents API throttling and quota exhaustion

### Skills Install

```bash
/skills install <git-url>
```

Clone skill repositories directly into `.snaga/skills/`. Share and reuse skill definitions across projects and teams.

### SPEC Registry

Snaga ships with a first-class publish/install workflow for sharing
community-authored skills and WASM tools via the SPEC Registry.

```bash
snaga spec init my-skill --kind skill   # scaffold a new SPEC
snaga spec build                        # pack bundle into .snaga/bundles/
snaga spec publish                      # upload to the registry
snaga spec install @alice/code-reviewer # pull someone else's SPEC
snaga spec list                         # view the local snaga.lock
snaga spec search "linter"              # search published SPECs
```

The registry URL is configurable via `SNAGA_REGISTRY_URL` for staging
/ self-hosted deployments.

### Interrupt Checkpoint

On `Ctrl+C`, Snaga saves the current session state as a checkpoint. Resume later with `/load` — no lost work from accidental interruptions.

### Tree-sitter Symbol Extraction

Added Tree-sitter grammars for improved code understanding:

- **TypeScript** — functions, classes, interfaces, type aliases
- **Python** — functions, classes, decorators
- **Go** — functions, types, methods, interfaces

Enables precise symbol-level navigation and refactoring across these languages.

### Conversation Management

Intelligent context window handling:
- **Truncate** — remove oldest messages
- **Summarize** — compress old messages into summaries
- **Hierarchical** — multi-level summarization for large contexts

### Agent Modes (Plan/Act)

Switch between read-only planning and full execution modes:

```
/mode plan    # Read-only mode — blocks write/execute tools
/mode act     # Full execution mode (default)
```

Plan mode allows only read-only tools (`read_file`, `grep`, `glob`, `list_dir`, `git_status`, `git_diff`, `git_log`, `web_search`, etc.) and those `mcp_*` tools whose verb is read-only (`search_`, `read_`, `get_`, `list_`, `describe_`, `fetch_`, `query_`, `show_`, `find_`, `lookup_`, `head_`, `info_`). Write and execute tools (`edit_file`, `write_file`, `shell`, …) are refused. This lets the agent explore and plan with no risk of unintended changes.

### Auto-Checkpoints

Before every destructive tool call (`edit_file`, `write_file`, `patch`, `shell`, `git_commit`, `git_reset`, `git_checkout`), Snaga automatically creates a git stash checkpoint. Up to 20 checkpoints per session are retained.

```
/rewind       # Undo the last action by restoring the most recent checkpoint
```

If something goes wrong, `/rewind` restores the working tree to the state before the last destructive operation — no manual git wrangling needed.

### Config Loader (snaga.toml)

A new config loader supports advanced project-level configuration:

- **Hooks** — ten lifecycle points: `session_start`, `user_prompt_submit`, `before_model`, `after_model`, `pre_compact`, `before_tool_call`, `after_tool_call`, `on_error`, `on_turn_complete`, `session_end`
- **MCP servers** — define servers with environment variable interpolation
- **Agent overrides** — per-agent `model`, `temperature`, `max_rounds` settings
- **Auto-connect** — MCP servers defined in config are connected automatically on startup

See the [Configuration](#configuration) section for the full `snaga.toml` format.

### MCP Auto-Connect

MCP servers defined in `snaga.toml` under `[[mcp.servers]]` are automatically connected on startup. Environment variables are interpolated in server commands and arguments, making it easy to share configs across teams without hardcoding secrets:

```toml
[[mcp.servers]]
name = "github"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }
```

### Browser Feature Flag

Browser automation is now opt-in via the `--features browser` flag. The browser dependency (chromiumoxide + Chrome DevTools Protocol) is heavy, so it's excluded from the default build:

```bash
# Build with browser automation support
cargo install --path crates/snaga-cli --features browser
```

## Architecture

```
snaga-cli          CLI + Bridge mode (interactive / daemon)
snaga-core         Agent loop, tool registry (RwLock), skills, permissions,
                  memory, circuit breaker, teams, voice, indexing, config_loader
snaga-tools        40+ native tools (impl Tool for ...)
snaga-wasm         WASM Component Model runtime (wasmtime + WIT contracts)
snaga-llm          LLM client layer (Stels/UARP platform, with transparent failover)
snaga-mcp          Model Context Protocol client + server
snaga-bridge       Bridge protocol: versioned `{type}` frames over WebSocket + HTTP, HMAC-signed delegations, fail-closed approval, rate_limit
snaga-browser      Browser automation (Chromium via Chrome DevTools Protocol)
```

**Key design decisions:**
- **RwLock-based tool registry** — O(1) lookup, concurrent reads, exclusive writes
- **WASM Component Model** — typed contracts via WIT, not raw FFI
- **Capability-based security** — no ambient authority, every access is gated
- **Streaming-first** — all LLM calls stream tokens to the user
- **Repetition detection** — prevents LLM loops with structural phrase filtering

## Tools

### Native

The kernel ships a deliberately small tool set. Heavier domain tools — Docker,
databases, LSP, test runners, package and service management, schedulers — were
removed in the v0.9.9 slim-kernel cleanup and are expected to return as
installable SPECs rather than as always-present built-ins.

| Category | Tools |
|----------|-------|
| **Files** | `read_file`, `write_file`, `edit_file`, `list_dir`, `glob`, `grep`, `diff_review`, `undo` |
| **Code search** | `symbols` — where a name is *declared*, as `path:line`. Escalate `grep` → `symbols` → `@codebase`: exact strings first, declarations second, conceptual questions last |
| **Git (read-only)** | `git_status`, `git_diff`, `git_log` |
| **Shell** | `shell` (risk-classified policy, injection detection), `bg_list`, `bg_logs`, `bg_wait`, `bg_kill` |
| **Web** | `http_request`, `scrape`, `web_search` |
| **Documents & media** | `read_pdf`, `vision`, `voice_transcribe`, `voice_synthesize` |
| **Agent** | `delegate`, `task_manage`, `monitor`, `read_tool_result` |
| **Syntax check** | `rust`, `python`, `typescript`, `javascript`, `go`, `java`, `kotlin`, `c`, `cpp`, `php`, `ruby`, `lua`, `sql`, `json`, `yaml`, `toml` |
| **Browser** | `browser` (Chromium via CDP — requires `--features browser`) |

Git is read-only on purpose: commits and branch changes go through the shell,
where the shell policy and the approval flow can see them.

### SPEC Registry

Fourteen tools drive the registry lifecycle — `spec_search`, `spec_info`,
`spec_list`, `spec_validate`, `spec_update`, `spec_init`, `spec_build`,
`spec_install`, `spec_uninstall`, `spec_rollback`, `spec_publish`, `spec_yank`,
`spec_unyank`, `spec_share`. The seven that mutate state require confirmation.

### WASM Management

| Tool | Description |
|------|-------------|
| `create_tool` | Author a tool in Rust, compile it to WASM, register it live |
| `create_js_tool` | Author a tool in JavaScript — no Rust toolchain needed |
| `remove_tool` | Remove a WASM tool (files + live registry) |
| `list_wasm_tools` | List installed WASM tools with capabilities |
| `find_tool` | Search available WASM tools by keyword |
| `activate_tool` | Load and activate a WASM tool |
| `deactivate_tool` | Hide a WASM tool (stays on disk) |

`create_tool` needs a Rust toolchain and the `wasm32-wasip2` target on the
machine. `create_js_tool` needs neither: the JavaScript interpreter is compiled
to WASM when Snaga itself is built and travels inside the binary, so authoring a
tool is three file writes and a smoke run. It also *executes* the tool before
registering it, which the compiled path does not — there, acceptance is "cargo
build exited 0", which says the code type-checks and nothing about whether it
works.

Created tools are stored in `.snaga/tools/`:
```
.snaga/tools/
├── my_tool.wasm          # Compiled WASM component
├── my_tool.rs            # Source (preserved)
└── my_tool.policy.toml   # Security policy (capabilities, limits)
```

### Host Capabilities for WASM Tools

WASM tools have no ambient authority. Every access goes through a
capability-gated host import. There are **21 capabilities**; twelve have working
host backends today (measured 2026-09-07 — the two below the line used to be
listed as stubs here while their tests said otherwise):

| Capability | Function | Details |
|------------|----------|---------|
| `file_read` | `read_file(path, offset, limit)` | Absolute paths and symlinks allowed; 10MB max file size |
| `file_write` | `write_file(path, bytes)` | Counts as destructive — triggers an auto-checkpoint |
| `http_get` | `http_get(url, headers)` | Up to 100 requests per execution; redirects limited to 10, and the SSRF guard re-runs on **every** 3xx hop |
| `http_post` | `http_post(url, body, content_type, headers)` | Same limits as `http_get` |
| `kv_store` | `kv_get/set/delete(key)` | 1000 entries, 1MB per value |
| `logging` | `log(level, message)` | Always available |
| `log_read` | reads the tool's own log | |
| `telemetry` | counters and timings | |
| `env_read` | `get_env(name)` | **Not** blanket access: a secret-name denylist plus `policy.env_allowlist`, which is empty by default and therefore denies everything |
| `shell_exec` | `shell_exec(cmd, args)` | 15-command allowlist, injection-substring filter on argv, timeout, output limits |
| `system_info` | `get_system_info()` | Host OS, CPU, memory via `sysinfo`; live data, not a stub (`system_info_granted_returns_data`) |
| `process` | `list_processes()` | Running processes via `sysinfo`; live data (`list_processes_granted_returns_data`) |

The remaining nine — all hardware buses: `gpio`, `i2c`, `spi`, `serial`,
`pwm`, `camera`, `gps`, `mavlink`, `mqtt` — are **declared and gated but not
implemented**. Count them with
`grep -oE 'not_implemented: .[a-z0-9_]+. host import' crates/snaga-wasm/src/capabilities.rs`
(21 host functions across those nine) rather than trusting this paragraph. A tool may request them and the capability system will enforce
them, but the host backends return `not_implemented` until platform-specific
implementations land. Do not plan work on them today.

### Granting what a tool requests

A manifest may put only `logging`, `kv_store` and `env_read` in
`capabilities_granted`; `snaga spec install` rejects anything else there,
`file_read` included. Everything else goes in `capabilities_requested` with
a `reason`, and the operator grants it — at the prompt when the tool asks,
or ahead of time:

```bash
snaga permissions policy add @local/probe --cap http_get --scope 'api.example.com'
snaga permissions policy add @local/probe --any-cap --scope '**'   # any target
snaga permissions policy list                                       # prints the file it read
```

Rules live in `permissions.toml` in the platform config directory
(`dirs::config_dir()`): `~/.config/snaga/permissions.toml` on Linux
(`$XDG_CONFIG_HOME` is honoured), `~/Library/Application
Support/snaga/permissions.toml` on macOS, `%APPDATA%\snaga\permissions.toml`
on Windows.

A scope is a closed allowlist. `*` or `**` alone means any target. Otherwise:
hosts (`api.example.com`, `*.example.com`) or URLs
(`https://api.example.com/v1/**`) for `http_get`/`http_post`; paths,
absolute or relative to the working directory, with an optional trailing
`*` (one level) or `**` (recursive) for `file_read`/`file_write` — matched
after `..` is folded, so `src/../secret` is not inside `src/**`; exact
command prefixes (`git status`) for `shell_exec`. `policy add` refuses a
pattern that can never match, and says why.

## Worktrees

```bash
snaga --worktree feature-x
```

Starts in a git worktree on `snaga-plan/feature-x`, creating it if it is
new and switching to it if it is not. Every file tool inherits that
working directory, so edits land on the branch instead of the tree you
launched from — `/plan diff`, `/plan apply` and `/plan discard` then do
what they say.

The worktree itself is the `/plan` machinery, which already existed. The
flag is the missing half: without it you open a session, create the
plan, and restart to get the isolation you asked for.

`--working-dir` wins if both are given, and a directory that is not a
git repository exits 2 rather than quietly working in place.

## Review

```bash
snaga review                        # uncommitted work, staged or not
snaga review --base origin/main     # what this branch added since main
snaga review --staged               # what is about to be committed
snaga --output-format json review   # findings as one object
```

Exit codes are the point — this is meant to be called by a pre-push hook
or by CI, not read: **0** nothing found, **1** findings, **2** the review
could not be done. An unparseable or failed review exits 2 rather than 0,
because a review that did not happen is not a clean one.

`--base` diffs against the merge base (`ref...HEAD`), so commits other
people landed on `ref` are not reported as this branch's removals.

## Skill evals

```bash
snaga eval skill terse              # every case twice: with the skill, and without
snaga eval skill terse --no-baseline
snaga --output-format json eval skill terse
```

A suite lives at `evals/<skill>.toml`:

```toml
[[case]]
name = "answers in one word"
prompt = "What is the capital of France?"

[[case.grader]]
kind = "contains"          # contains | not_contains | tool_called | tool_not_called
pattern = "(?i)^\\s*paris\\s*$"
```

**The baseline is the point.** A case that passes with the skill and
without it says nothing about the skill; the report prints both scores
and the difference, so a suite that is really measuring the model rather
than the skill is visible rather than flattering. With `--no-baseline`
the report says the contribution is unmeasured instead of printing a
delta of zero.

Exits 1 when any grader fails with the skill active, 2 when the suite is
missing or malformed. A case with no graders, or a pattern that does not
compile, is refused at load — both would raise the score while measuring
nothing.

Graders are deterministic on purpose. A rubric judged by a second model
is not offered: its own accuracy is unmeasured, and sitting it beside
checks a reader can verify invites trusting all of them equally.

## Slash Commands

Type `/` on an empty prompt to open the interactive picker (arrow-key navigation, fuzzy filter, sub-menu drill-down). All commands also work as plain text input.

| Command | Description |
|---------|-------------|
| `/help` | Show all commands and shortcuts |
| `/quit`, `/exit` | Exit Snaga (`Ctrl+C×2` or `Ctrl+D` also work) |
| `/clear` | Reset conversation history |
| `/tools` | List available agent tools |
| `/skills` | Manage skills — sub-commands: `list`, `show`, `activate`, `deactivate`, `create`, `edit`, `delete`, `reload`, `install` |
| `/model` | Reports that the model is platform-managed. There is nothing to set. |
| `/tokens` | Show conversation token usage and session cost |
| `/context` | Context budget, when compaction triggers, and **where the context went** — a breakdown by source, with each tool named |
| `/compact` | Compress conversation to reduce tokens |
| `/save` | Save the session to a file |
| `/load` | Resume a saved session checkpoint |
| `/rebuild` | Rebuild and restart Snaga from source |
| `/memory` | Manage project memory — sub-commands: `init`, `show`, `update`, `inbox` |
| `/memory inbox` | Review what passive extraction proposed: `accept <key>\|all`, `reject <key>\|all`. Nothing is recalled until accepted |
| `/agents` | Everything running in the background, grouped by state: needs you / running / done. Covers workers, monitors and detached shell processes. `/tasks` and `/background` are aliases for the listing |
| `/background` | `run <task>` starts a worker; `status`/`cancel <id>` act on one. Bare `/background` opens `/agents` |
| `/map` | Display repository structure |
| `/test` | Run tests with auto-fix |
| `/mcp` | Connect to MCP servers — sub-commands: `connect`, `list` |
| `/mode plan` | Switch to read-only mode (blocks write/execute tools) |
| `/mode act` | Switch to full execution mode (default) |
| `/rewind` | Undo last action by restoring the most recent auto-checkpoint |
| `/plan` | Manage git-worktree plan branches — sub-commands: `new <name>`, `branch [<source>] <new>`, `switch [<name>]`, `current`, `diff [<name>]`, `apply [<name>]`, `discard [<name>]`, `deactivate`, `list` |
| `/voice` | Voice input settings |

**Shortcuts:** `! cmd` runs a shell command directly · `\` at end of line continues input on the next line · `Tab` triggers completion · `Ctrl+C` cancels generation (twice to exit) · `Ctrl+D` exits on empty line.

## Skills

Skills are guided workflows defined in SKILL.md files. They inject instructions and restrict available tools:

```bash
/skills                           # List skills
/skills activate create-tool      # Guided tool creation
/skills activate code-reviewer    # Code review mode
/skills deactivate                # Back to normal
```

**Available skills:** `code-reviewer`, `test-generator`, `security-auditor`, `git-commit-helper`, `bug-fixer`, `refactor-expert`, `debug-helper`, `api-documenter`, `readme-updater`, `deploy-workflow`, `frontend-design`, `dependency-auditor`, `create-tool`.

Skills support:
- **Tool restrictions** — limit which tools the agent can use
- **Argument substitution** — `$ARGUMENTS`, `$0`, `$1`, etc.
- **Shell command substitution** — `` !`command` `` blocks (with security validation)
- **Chaining** — skills can chain to the next skill automatically

## The model

Snaga runs on the Stels platform, and the platform chooses the model. There is
no model picker and no way to point the CLI at another endpoint: `--base-url`,
`/model providers` and `~/.snaga/custom-providers.toml` are gone.

This is a product decision, not an omission. The platform's choice moves as
models improve, and a pinned name silently diverges from it the moment it does.
Streaming, tool calling and transparent failover to a backup are handled for
you; when a failover happens the session says so without naming what it
switched to.

There is no build that does otherwise: local providers (Ollama, LM Studio) and
custom endpoints are not in the code.

## Installation

### macOS and Linux

```bash
curl -fsSL https://snaga.ai/install.sh | bash
```

Detects OS and architecture, downloads the matching tarball from
`https://snaga.ai/dist/`, verifies it against the published SHA-256 sums,
installs into `~/.snaga/bin`, and adds that to `PATH` via your shell profile.
No `sudo` required.

```bash
curl -fsSL https://snaga.ai/install.sh | bash -s -- --version 1.3.0
curl -fsSL https://snaga.ai/install.sh | INSTALL_DIR=/usr/local/bin sudo -E bash
```

Options: `--version`, `--dir` (or `INSTALL_DIR`), `--libc` (or `SNAGA_LIBC`),
`--help`. On Linux the default build is statically linked against musl and runs
on any distro; pass `SNAGA_LIBC=gnu` for the dynamic build, which needs
glibc 2.30 or newer.

> The script served at `snaga.ai/install.sh` is **not** the `install.sh` in this
> repository — they are different programs, and editing the one here changes
> nothing about what users run. See the header comment in `install.sh`.

### Pre-built binaries

Seven targets per release — macOS x86_64 and ARM64, Linux x86_64 and ARM64
(gnu and musl), Windows x86_64 — plus a `.deb`. Every artifact ships a cosign
signature (`.sig`) and certificate (`.pem`) alongside `sha256sums.txt`.

Download from [releases](https://github.com/chabanov/snaga-releases/releases).

There is no ARM64 Windows build: `ring` ships no assembly for that target.

### From source

Requires access to this repository.

```bash
cargo install --path crates/snaga-cli
```

> **Homebrew is not currently available.** Earlier revisions of this README
> documented `brew tap chabanov/snaga …`, which cannot work: the tapped
> repository contains no `Formula/` or `Casks/` directory, and
> `chabanov/homebrew-snaga` does not exist. Use the install script instead.

## Getting Started

> **Build prerequisites for self-extension:** authoring WASM tools (`create_tool`, `spec_build`) requires a Rust toolchain and `rustup target add wasm32-wasip2`. The stock binary runs without them; see [Self-Extending](#self-extending-tool-system) for details.

```bash
# Start interactive mode
snaga

# Run a single prompt
snaga -p "fix the bug in src/main.rs"

# Start bridge daemon (distributed mode)
snaga serve

# Start MCP server mode (expose tools to other agents)
snaga mcp-server

```

## Configuration

`snaga.toml`, read from the working directory or `~/.config/snaga/`. Layered:
defaults, then global, then project, then environment.

The recognised sections are `agent`, `memory`, `permissions`, `hooks`, `mcp`
and `models` — that list is `SnagaTomlConfig` in
`crates/snaga-cli/src/config_loader.rs`, whose doc comment carries the canonical
example. Earlier revisions of this section documented `[llm]`, `[tools]`,
`[cli]`, `[security]`, `[context]` and `[plugins]`, none of which the loader
has ever recognised, and showed hooks as bare strings, which is not their shape.

```toml
[agent]
max_rounds = 20
temperature = 0.7

[agent]
# Ceiling on one delegated worker's LLM call. Default 600 — raise it for
# a decomposition whose steps are long.
worker_call_timeout_secs = 900

# Parsed and inert. Memory is initialised on every run that is not
# `--fast`, and none of these toggles is read — verified 2026-09-22:
# nothing in the CLI reads `snaga_config.memory` at all. They are kept
# for forward compatibility, and shown here so the shape is right when
# they start working, not because setting them does anything.
#
# `enabled = false` in particular does NOT turn memory off, which is the
# reading that matters: it looks like a switch and is not one. The flag
# that does turn it off is `--fast`.
[memory]
enabled = true
playbook = true
reflection = true

[permissions]
# `--permission-mode auto` sits between asking about everything and
# `--yolo`: it also approves, with no prompt, a path inside the working
# directory and a command the shell guard accepts while a sandbox is
# active. Everything else still asks, and a `deny` rule outranks it.
#
# An entry is a bare tool name, or `tool(glob)` to match the call's
# principal argument — the command for `shell`, the path for the file
# tools. A matching `deny` outranks every `auto_approve`, and outranks
# `--yolo` too: the approval callback is never reached.
auto_approve = ["read_file", "grep", "glob", "shell(git status*)"]
deny = ["rm_all", "write_file(/etc/**)"]

[hooks]
enabled = true

# An array of tables, one per hook — NOT `after_tool_call = "cmd"`.
#
# `tools` is an exact list and `matcher` a regex over the tool name;
# given both, both must pass. A hook may print a JSON object on stdout:
#   {"decision": "block", "reason": "..."}   refuse the call
#   {"additional_context": "..."}            add a note to the result
# `decision` is honoured only on a `before_tool_call` entry declared
# `blocking = true`, so which hooks can refuse a call stays readable
# from this file. Anything else a hook prints is ignored.
[[hooks.after_tool_call]]
command = "cargo check"
tools = ["edit_file", "write_file"]

# `before_tool_call` observes by default. `blocking = true` makes a
# non-zero exit REFUSE the call — the only hook point that can, since
# the other three fire once the work is already done.
[[hooks.before_tool_call]]
command = "scripts/deny-writes-outside-repo.sh"
tools = ["write_file", "edit_file"]
blocking = true

[[mcp.servers]]
name = "postgres"
command = "npx"
args = ["@modelcontextprotocol/server-postgres"]
env = { PGPASSWORD = "${PGPASSWORD}" }
```

Hook points, in firing order: `session_start`, `user_prompt_submit`,
`before_model`, `after_model`, `pre_compact`, `before_tool_call`,
`after_tool_call`, `on_error`, `on_turn_complete`, `session_end`.

`before_model` and `after_model` fire **every round**, not every turn: a
turn that calls five tools makes six model calls. That is a subprocess
per call — opt-in, since a point with no hooks does nothing, but worth
knowing before you write one.
`pre_compact` is the last moment to keep what compaction is about to
summarise away — afterwards only the summary remains.

`session_end` runs when the session ends **normally**. It runs from a
drop guard, so it covers every path that returns and none that aborts
the process — the same coverage an `atexit` handler has. Write one that
can be skipped. `tools` narrows a hook to the tools that
trigger it, `matcher` is a regex over the tool name, and both must pass
when both are given.

Three of the points run **before** the work they could stop, and only
those three honour `blocking` and `{"decision":"block"}`:
`session_start` refuses the session outright, `user_prompt_submit`
refuses one turn before the model is called, `before_tool_call` refuses
one tool call. A refusal names which point it came from. `blocking` anywhere else is inert, and `/hooks`
prints it as such.

`{"additional_context":"…"}` is carried by four points:
`session_start`, `user_prompt_submit`, `before_tool_call` and
`after_tool_call`. Offered anywhere else it reaches nothing, and the
runner says so rather than accepting it in silence. At `session_start`
it becomes a system message for the whole session — context that should
still be there twenty turns later. At `user_prompt_submit` it is
prepended to the prompt — background is read
before the request it is background for — and elsewhere it is appended to
the tool result. Either way it is labelled `[hook context]`, so a hook
cannot put words in the user's mouth or forge tool output.

A failing hook that is not `blocking` is reported and the remaining hooks
still run — one hook exiting non-zero does not cancel the ones after it.

There is no model selection here. See "The model" above.

### Project-local configs are untrusted

A `snaga.toml` can declare shell hooks and MCP servers — commands to run and
subprocesses to spawn — and it can be committed to a public repository. So a
project-local one does not take effect silently: when it asks for side effects,
`project_trust.rs` prints what it wants and waits for the operator.

Approval is per project, and a CHANGED `snaga.toml` re-prompts, so a commit that
lands later does not inherit a decision made about a different file. A global
config in `~/.config/snaga/` is the operator's own and is exempt.

## File Structure

```
{working_dir}/
├── .snaga/
│   ├── tools/           # WASM tools (.wasm + .rs + .policy.toml)
│   ├── tool-build/      # Temp build dir (cleaned after compilation)
│   ├── cache/wasm/      # AOT precompiled .cwasm files
│   ├── skills/          # Skill definitions (SKILL.md)
│   ├── memory/          # Local memory store (KV + sessions)
│   ├── index/           # Semantic search index (SQLite)
│   └── tasks.json       # Task board

~/.snaga/
├── credentials.json     # API keys (global, user identity)
└── memory/              # Enhanced memory (sessions.db, knowledge.db)
```

## Project Stats

- **Language:** Rust (edition 2024)
- **Workspace members:** derive from `cargo metadata --no-deps --format-version 1`
- **Lines/files:** measure the current checkout; generated files and counting method materially change the result
- **Binary size, memory, startup:** benchmark the intended release profile on the target platform
- **Runtime prerequisites:** the main CLI is a native binary; authoring WASM tools additionally requires a Rust toolchain and the `wasm32-wasip2` target

## License

MIT
