<div align="center">

# Snaga

**Self-Extending AI Coding Agent**

[![Rust](https://img.shields.io/badge/Rust-2024-orange?logo=rust)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/v/release/chabanov/snaga-releases?label=Version&color=green)](https://github.com/chabanov/snaga-releases/releases)

[Installation](#installation) · [Getting Started](#getting-started) · [Architecture](#architecture) · [Tools](#tools) · [Slash Commands](#slash-commands) · [Skills](#skills) · [Security](https://github.com/chabanov/snaga/blob/main/SECURITY.md) · [Changelog](https://github.com/chabanov/snaga/blob/main/CHANGELOG.md)

</div>

---

Snaga is an AI coding agent built in Rust that can **create its own tools at runtime**. It compiles Rust code to WebAssembly, registers it instantly, and runs it in a capability-based sandbox — no redeployment, no restarts.

The agent operates with a lean native kernel (~25 tools), a 14-tool SPEC registry for community tools, and unlimited runtime-compiled WASM tools — plus multi-agent orchestration, enhanced memory, and a distributed bridge mode for clustering machines. Heavier domain tools (docker, database, LSP, test_runner, …) were spun out in the v0.9.9 slim-kernel cleanup and return as installable SPECs. It runs as a single ~18MB binary with <100ms startup and ~30MB memory footprint.

## Install
```
curl -fsSL https://snaga.ai/install.sh | bash
```

## Why Snaga

| | Snaga | Claude Code | Cursor | Aider |
|---|---|---|---|---|
| **Self-extending (runtime tools)** | ✅ | ❌ | ❌ | ❌ |
| **Open source** | ✅ | ❌ | ❌ | ✅ |
| **BYOM (bring your own model)** | ✅ | ❌ | Partial | ✅ |
| **Distributed cluster** | ✅ | ❌ | ❌ | ❌ |
| **Multi-agent teams** | ✅ | ✅ | ✅ | ❌ |
| **Skills system** | ✅ | ✅ | ❌ | ❌ |
| **MCP support** | ✅ | ✅ | ✅ | ❌ |
| **MCP server mode** | ✅ | ✅ | ✅ | ❌ |
| **Voice coding** | ✅ | ✅ | ❌ | ✅ |
| **Rust-native** | ✅ | ❌ | ❌ | ❌ |
| **Browser automation** | ✅ | ❌ | ❌ | ❌ |
| **Agent modes (Plan/Act)** | ✅ | ✅ | ❌ | ❌ |
| **Auto-checkpoints** | ✅ | ✅ | ❌ | ❌ |

## Core Capabilities

### Self-Extending Tool System

Snaga is the only AI coding agent that can create new tools at runtime. When the agent encounters a task it can't solve with existing tools, it writes Rust code, compiles it to WASM, and registers the tool immediately — all within the same session.

```
Agent decides it needs a new tool
  → CreateToolTool generates Rust scaffold
  → cargo build --target wasm32-wasip2 --release
  → wasmtime loads and validates the WASM component
  → ToolRegistry.register_dynamic() — available instantly
  → Agent uses the tool in the same session
```

Tools run in a 4-layer sandbox:
1. **Compilation isolation** — each tool built in its own `wasm32-wasip2` workspace
2. **Component validation** — wasmtime verifies WIT world implementation
3. **Capability-based access** — 21 bitflag capabilities per tool (10 core like `file_read`/`http_post`/`shell_exec` + 11 hardware/embedded like `gpio`/`i2c`/`mqtt`)
4. **Runtime limits** — epoch-interruption CPU budget, pooling-allocator memory cap, shell-injection regex

### Multi-Agent Orchestration

Snaga can delegate work to specialized worker agents running in parallel:

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

Three-layer memory architecture for cross-session context persistence:

- **Working Memory** — short-term task context (in-memory)
- **Session Memory** — current conversation with auto-save (SQLite)
- **Long-term Memory** — persistent knowledge with semantic search (SQLite + embeddings)

Automatic consolidation moves important facts from working → session → long-term memory based on importance scores.

### Semantic Code Search

Built-in codebase indexing with embeddings:
- File content chunking with overlap
- TF-IDF or remote API embedding generation
- Vector similarity search
- Incremental index updates with file watching
- SQLite persistence

### Voice Coding

Speech-to-text via Whisper API or local whisper.cpp, text-to-speech via macOS `say` or Linux `espeak`. Push-to-talk mode with voice command recognition.

### Linting & Auto-Verification

Automatic code quality checks after edits:
- **Rust:** `cargo clippy`
- **Python:** `ruff`
- **JavaScript/TypeScript:** `eslint`
- **Go:** `golangci-lint`
- **Java:** `checkstyle`
- **Kotlin:** `ktlint`
- **Ruby:** `rubocop`
- **PHP:** `phpcs`
- **C/C++:** `clang-tidy`
- **Lua:** `luacheck`
- **SQL:** `sqlfluff`
- **YAML:** `yamllint`
- **Shell:** `shellcheck`

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

Plan mode allows only read-only tools (`read_file`, `grep`, `glob`, `git_status`, `web_search`, etc.) and `mcp_*` tools whose verb is read-like (`search_`/`read_`/`get_`/`list_`/…). Write tools (`edit_file`, `write_file`, `shell`, etc.) are blocked. This lets the agent safely explore and plan without risk of unintended changes.

### Auto-Checkpoints

Before every destructive tool call (any tool whose `is_destructive()` is true — `edit_file`, `write_file`, `shell`, …), Snaga automatically creates a git stash checkpoint. Up to 20 checkpoints per session are retained.

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
snaga-tools        ~25 native kernel tools (slim kernel; domain tools → SPECs)
snaga-wasm         WASM Component Model runtime (wasmtime + WIT contracts)
snaga-llm          LLM client layer (Stels, Ollama Cloud, OpenAI, Copilot, Together, LM Studio)
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

### Native Kernel (~25)

The slim kernel keeps only the tools an agent needs on every run. Heavier
domain tools (docker, database, LSP, test_runner, package, service,
scheduler, …) were removed in the v0.9.9 cleanup and return as installable
SPECs — see below.

| Category | Tools |
|----------|-------|
| **Files** | `read_file`, `write_file`, `edit_file`, `list_dir`, `glob`, `grep`, `diff_review`, `undo` |
| **Git (read-only)** | `git_status`, `git_diff`, `git_log` |
| **Shell + bg procs** | `shell` (risk-classified policy, injection detection), `bg_list`/`bg_logs`/`bg_wait`/`bg_kill` (detached processes, merged stdout+stderr log) |
| **Web** | `http_request`, `scrape`, `web_search`, `read_pdf` |
| **Media / AI** | `vision` (OCR, screenshots, charts), `voice_synthesize`, `voice_transcribe`, `image_generate` (UARP-backed) |
| **Multi-agent** | `delegate` (delegated worker agents), `task_manage` (task board) |
| **Monitors** | `monitor` (recurring monitors — `create`/`list`/`status`/`pause`/`resume`/`cancel`; command or prompt mode) |
| **Browser** | `browser` (Chromium automation via CDP — requires `--features browser`) |

### SPEC Registry (14 tools)

The community flywheel — the agent itself can discover, install, use,
publish, and share SPECs (signed tool packages) without a restart:

| Group | Tools |
|-------|-------|
| **Read** | `spec_search`, `spec_info`, `spec_list`, `spec_validate`, `spec_update` |
| **Author** | `spec_init`, `spec_build` |
| **Mutate** (confirm) | `spec_install`, `spec_uninstall`, `spec_rollback`, `spec_publish`, `spec_yank`, `spec_unyank`, `spec_share` |

Installed SPECs register their WASM tools into the live `ToolRegistry`
via `RealWasmToolFactory` — no restart needed. Mutating `spec_*` tools
require operator confirmation.

### WASM Tools & Runtime

The agent compiles Rust to `wasm32-wasip2` and registers the tool in the
same session via `create_tool`. Community tools arrive through the SPEC
registry (`spec_install`) and register the same way. Every WASM tool runs
in the 4-layer sandbox (see above) with no ambient authority — every host
call goes through a checked, capability-gated import.

| Tool | Description |
|------|-------------|
| `create_tool` | Generate a Rust scaffold, compile to `wasm32-wasip2`, validate the component, and register the tool at runtime |

Created/installed tools live in `.snaga/tools/`:
```
.snaga/tools/
├── crypto_price.wasm          # Compiled WASM component
├── crypto_price.rs            # Rust source (preserved)
└── crypto_price.policy.toml   # Security policy (capabilities, limits)
```

AOT-precompiled `.cwasm` caches live in `.snaga/cache/wasm/`.

### Host Capabilities for WASM Tools (21)

WASM tools have no ambient authority. All access goes through capability-gated host imports. 21 capabilities total — 10 core, 11 hardware/embedded:

**Core (10)**

| Capability | Function | Notes |
|------------|----------|-------|
| `file_read` | `read_file(path, offset, limit)` | Absolute paths and symlinks; 10MB max |
| `file_write` | write paths | Mutating file ops |
| `http_get` | `http_get(url, headers)` | SSRF-guarded (scheme + private-host + IMDS), re-validated on every 3xx redirect |
| `http_post` | `http_post(url, body, …)` | Same SSRF guard + redirect re-validation |
| `kv_store` | `kv_get/set/delete(key)` | Per-tool key-value store |
| `env_read` | `get_env(name)` | Secret denylist + configurable allowlist (empty = deny all) |
| `shell_exec` | `shell_exec(cmd, args)` | 15-command allowlist + injection-substring filter on argv |
| `logging` | `log(level, message)` | Always available |
| `telemetry` | metrics emit | Optional |
| `log_read` | read log lines | Optional |

**Hardware / embedded (11)** — declared and gated; host backends return `not_implemented` until a platform-cfg impl lands:

`gpio`, `i2c`, `spi`, `serial`, `system_info`, `process`, `gps`, `mavlink`, `pwm`, `camera`, `mqtt`

The HTTP capabilities carry an SSRF guard that re-runs on every redirect hop (so an external endpoint can't 302 a tool to `169.254.169.254`); overrides via `SNAGA_WASM_ALLOW_PRIVATE_NETWORK=1` / `SNAGA_WASM_ALLOW_METADATA=1`.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/mode plan` | Switch to read-only mode (blocks write/execute tools) |
| `/mode act` | Switch to full execution mode (default) |
| `/rewind` | Undo last action by restoring auto-checkpoint |
| `/plan new <name>` | Create a plan branch with worktree |
| `/plan branch` | Show current plan branch info |
| `/plan diff` | Show changes in the plan branch |
| `/plan apply` | Merge plan branch into main |
| `/plan discard` | Discard the plan branch and worktree |
| `/plan list` | List all plan branches |
| `/skills` | List available skills |
| `/skills activate <name>` | Activate a skill |
| `/skills deactivate` | Deactivate current skill |
| `/skills install <git-url>` | Install a skill from a git repository |
| `/load` | Resume a saved session checkpoint |

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

## LLM Providers

| Provider | Default Model | Local | API |
|----------|--------------|-------|-----|
| **Stels** (default) | GLM-5.1 | No | UARP gateway |
| **Ollama Cloud** | User-configured | No | OpenAI-compatible |
| **Together** | GLM-5.1 | No | OpenAI-compatible |
| **LM Studio** | User-configured | Yes | OpenAI-compatible |

All providers support streaming, tool calling, and automatic fallback.

## Configuration

Snaga uses `snaga.toml` in the project root:

```toml
[llm]
provider = "stels"
model = ""                    # resolved from API
max_tokens = 4096

[models]                       # Role-based model routing
# planner = "..."
# coder = "..."

[tools]
parallel_execution = true
max_parallel_tools = 4
shell_timeout_secs = 120

[plugins]                      # MCP server configurations (legacy)
# [[plugins.mcp_servers]]
# name = "..."
# command = "..."

[[mcp.servers]]                # MCP servers (auto-connected on startup)
name = "github"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }

[[mcp.servers]]
name = "postgres"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"]

[agent]                        # Agent overrides
# model = "..."
# temperature = 0.7
# max_rounds = 50

[hooks]                        # Lifecycle hooks
before_tool_call = "echo 'calling {tool_name}'"
after_tool_call = "echo '{tool_name} done in {duration_ms}ms'"
on_error = "notify-send 'Snaga error'"
on_turn_complete = "echo 'turn done'"

[cli]                          # CLI display options
# theme = "dark"
# show_thinking = false

[security]
max_file_size = 10485760      # 10MB
shell_whitelist_mode = "whitelist_only"
audit_logging = true

[context]
auto_inject = true            # auto-inject relevant files into context

[permissions]                  # Per-tool permission policies
# [permissions.shell]
# allow = ["git", "cargo"]

[observability]
log_level = "info"
debug_mode = false

[wasm]                         # WASM runtime configuration
# epoch_budget = 3000
# max_memory_bytes = 268435456
# max_http_requests = 100
```

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
- **Source files:** 172
- **Binary size:** ~18MB
- **Memory usage:** ~30MB
- **Startup time:** <100ms
- **Dependencies:** Zero runtime (no Node.js, Python, or Electron)

## License MIT
