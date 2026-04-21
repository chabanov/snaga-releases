<div align="center">

# Snaga

**Self-Extending AI Coding Agent**

[![Rust](https://img.shields.io/badge/Rust-2024-orange?logo=rust)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.8.0-green.svg)](https://github.com/chabanov/snaga/releases)

[Installation](#installation) · [Getting Started](#getting-started) · [Architecture](#architecture) · [Tools](#tools) · [Slash Commands](#slash-commands) · [Skills](#skills) · [Security](SECURITY.md) · [Changelog](CHANGELOG.md)

</div>

---

Snaga is an AI coding agent built in Rust that can **create its own tools at runtime**. It compiles Rust code to WebAssembly, registers it instantly, and runs it in a capability-based sandbox — no redeployment, no restarts.

The agent operates with 40+ native tools and unlimited WASM tools created at runtime, multi-agent orchestration, semantic code search, enhanced memory, and a distributed bridge mode for clustering machines. It runs as a single 18MB binary with <100ms startup and ~30MB memory footprint.

## Install
```
# One-line installer (auto-detects platform)
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
3. **Capability-based access** — bitflags per tool (`file_read`, `http_get`, `kv_store`, `logging`, `shell_exec`)
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

Plan mode allows only read-only tools (`read_file`, `grep`, `glob`, `git_status`, `code_search`, `web_search`, etc.) and `mcp_*` tools. Write tools (`edit_file`, `write_file`, `patch`, `shell`, `git_commit`, etc.) are blocked. This lets the agent safely explore and plan without risk of unintended changes.

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

### Native (40+)

| Category | Tools |
|----------|-------|
| **Files** | `read_file`, `write_file`, `edit_file`, `list_dir`, `glob`, `grep`, `diff`, `diff_review`, `patch`, `undo` |
| **Git** | `git_status`, `git_diff`, `git_log`, `git_add`, `git_commit`, `git_commit_message`, `git_branch`, `git_checkout`, `git_reset`, `git_pr`, `git_worktree` |
| **Shell** | `shell` (with security: blocked patterns, injection detection, bg process tracking) |
| **Docker** | `docker` (list, run, stop, start, rm, logs, exec, inspect, images) |
| **Database** | `database` (SQLite, PostgreSQL, MySQL — parameterized queries) |
| **System** | `service`, `package`, `scheduler` |
| **Web** | `http_request`, `scrape`, `web_search` |
| **AI** | `vision` (OCR, screenshots, charts), `code_search` (semantic), `delegate` (multi-agent), `svg_draw` |
| **Project** | `task_manage`, `project_memory`, `background_task`, `context_gather` |
| **Code** | `test_runner`, `linter_check`, `self_rebuild`, `skill_manage` |
| **Browser** | `browser` (Chromium automation via CDP — requires `--features browser`) |

### WASM Runtime Tools

System tools migrated to WASM for sandboxed execution, plus user-created tools:

| Tool | Description |
|------|-------------|
| `sys_process` | Process management (list, kill, info, find, tree) |
| `sys_network` | Network management (interfaces, ports, connections, DNS, ping, routes) |
| `sys_disk` | Disk management (usage, list, info) |
| `sys_user` | User/group management (whoami, users, groups, user_info, group_members) |
| `sys_env` | Environment variables (get, set, unset, list, expand) |
| `sys_logs` | System logs (system, app, search, kernel) |
| `wifi_scan` | WiFi network scanning (macOS) |
| `crypto_price` | Cryptocurrency prices (Coinbase API) |

### WASM Management

| Tool | Description |
|------|-------------|
| `create_tool` | Create a new WASM tool from Rust code |
| `remove_tool` | Remove a WASM tool (files + live registry) |
| `list_wasm_tools` | List installed WASM tools with capabilities |
| `find_tool` | Search available WASM tools by keyword |
| `activate_tool` | Load and activate a WASM tool |
| `deactivate_tool` | Hide a WASM tool (stays on disk) |

Created tools are stored in `.snaga/tools/`:
```
.snaga/tools/
├── crypto_price.wasm          # Compiled WASM component
├── crypto_price.rs            # Rust source (preserved)
└── crypto_price.policy.toml   # Security policy (capabilities, limits)
```

### Host Capabilities for WASM Tools

WASM tools have no ambient authority. All access goes through capability-gated host imports:

| Capability | Function | Details |
|------------|----------|---------|
| `file_read` | `read_file(path, offset, limit)` | Absolute paths and symlinks allowed; 10MB max file size |
| `http_get` | `http_get(url, headers)` | Up to 100 requests per execution; redirects limited to 10 |
| `http_post` | `http_post(url, body, content_type, headers)` | Same limits as http_get |
| `kv_store` | `kv_get/set/delete(key)` | 1000 entries, 1MB per value |
| `logging` | `log(level, message)` | Always available |
| `env_read` | `get_env(name)` | Any environment variable accessible when capability is granted |
| `shell_exec` | `shell_exec(cmd, args)` | Blocked patterns, timeout, output limits |

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
