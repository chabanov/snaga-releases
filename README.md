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

### Distributed Bridge Mode

```bash
snaga serve
```

Multiple Snaga instances on different machines form a cluster via UARP (Unified Agent Runtime Protocol). A Head Agent delegates tasks, workers execute autonomously. Bridge agents poll for tasks, request approval for dangerous operations, and report results.

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
the model without you naming files. Index updates incrementally; persistence is
SQLite.

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
- Incremental index updates as files change
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

- **Hooks** — `before_tool_call`, `after_tool_call`, `on_error`, `on_turn_complete` lifecycle hooks
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
snaga-bridge       Bridge protocol (HMAC-signed delegations, fail-closed approval, JSON-RPC, rate_limit)
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
capability-gated host import. There are **21 capabilities**; ten have working
host backends today:

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

The remaining eleven — `gpio`, `i2c`, `spi`, `serial`, `system_info`, `process`,
`gps`, `mavlink`, `pwm`, `camera`, `mqtt` — are **declared and gated but not
implemented**. A tool may request them and the capability system will enforce
them, but the host backends return `not_implemented` until platform-specific
implementations land. Do not plan work on them today.

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
| `/tokens` | Show conversation token usage |
| `/compact` | Compress conversation to reduce tokens |
| `/save` | Save the session to a file |
| `/load` | Resume a saved session checkpoint |
| `/rebuild` | Rebuild and restart Snaga from source |
| `/memory` | Manage project memory — sub-commands: `init`, `show`, `update` |
| `/background` | Manage background tasks — sub-commands: `list`, `status`, `cancel` |
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

Self-hosted deployments that genuinely need a different endpoint can build with
`cargo build --features custom-endpoint`, which restores `--base-url` and the
custom-provider registry. It is a build-time feature rather than a runtime flag
on purpose — a runtime flag is a bypass anyone can reach.

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

[memory]
enabled = true
playbook = true
reflection = true

[permissions]
auto_approve = ["read_file", "grep", "glob"]
deny = ["rm_all"]

[hooks]
enabled = true

# An array of tables, one per hook — NOT `after_tool_call = "cmd"`.
[[hooks.after_tool_call]]
command = "cargo check"
tools = ["edit_file", "write_file"]

[[mcp.servers]]
name = "postgres"
command = "npx"
args = ["@modelcontextprotocol/server-postgres"]
env = { PGPASSWORD = "${PGPASSWORD}" }
```

Hook points: `before_tool_call`, `after_tool_call`, `on_error`,
`on_turn_complete`. `tools` narrows a hook to the tools that trigger it.

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
