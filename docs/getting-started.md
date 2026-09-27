# Getting Started with OpenAgent

This guide walks you through installing OpenAgent, configuring your first LLM provider, spawning an agent, and chatting with it.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Spawn Your First Agent](#spawn-your-first-agent)
- [Chat with an Agent](#chat-with-an-agent)
- [Start the Daemon](#start-the-daemon)
- [Using the WebChat UI](#using-the-webchat-ui)
- [Next Steps](#next-steps)

---

## Installation

### Option 1: Desktop App (Windows / macOS / Linux)

Download the installer for your platform from the [latest release](https://github.com/RightNow-AI/openagent/releases/latest):

| Platform | File |
|---|---|
| Windows | `.msi` installer |
| macOS | `.dmg` disk image |
| Linux | `.AppImage` or `.deb` |

The desktop app includes the full OpenAgent system with a native window, system tray, auto-updates, and OS notifications. Updates are installed automatically in the background.

### Option 2: Shell Installer (Linux / macOS)

```bash
curl -sSf https://openagent.sh | sh
```

This downloads the latest CLI binary and installs it to `~/.openagent/bin/`.

### Option 3: PowerShell Installer (Windows)

```powershell
irm https://openagent.sh/install.ps1 | iex
```

Downloads the latest CLI binary, verifies its SHA256 checksum, and adds it to your user PATH.

### Option 4: Cargo Install (Any Platform)

Requires Rust 1.75+:

```bash
cargo install --git https://github.com/RightNow-AI/openagent openagent-cli
```

Or build from source:

```bash
git clone https://github.com/RightNow-AI/openagent.git
cd openagent
cargo install --path crates/openagent-cli
```

### Option 5: Docker

```bash
docker pull ghcr.io/RightNow-AI/openagent:latest

docker run -d \
  --name openagent \
  -p 4200:4200 \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -v openagent-data:/data \
  ghcr.io/RightNow-AI/openagent:latest
```

Or use Docker Compose:

```bash
git clone https://github.com/RightNow-AI/openagent.git
cd openagent
# Set your API keys in environment or .env file
docker compose up -d
```

**Reaching host services from the container.** If you run a local LLM
(Ollama, whisper.cpp, vLLM) on the host and want the agent to call it, add
the host-gateway bridge. Required on Linux and colima:

```bash
docker run -d \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_HOST=http://host.docker.internal:11434 \
  -p 4200:4200 \
  ghcr.io/rightnow-ai/openagent:latest
```

For Compose, add `extra_hosts: ["host.docker.internal:host-gateway"]` to the
service. See [Troubleshooting → Connecting to host services from Docker](troubleshooting.md#connecting-to-host-services-from-docker)
and the [curl-equipped overlay image](troubleshooting.md#curl-equipped-reference-image)
if you need in-container `curl` for healthchecks.

### Verify Installation

```bash
openagent --version
```

---

## Configuration

### Initialize

Run the init command to create the `~/.openagent/` directory and a default config file:

```bash
openagent init
```

This creates:

```
~/.openagent/
  config.toml    # Main configuration
  data/          # Database and runtime data
  agents/        # Agent manifests (optional)
```

### Set Up an API Key

OpenAgent needs at least one LLM provider API key. Set it as an environment variable:

```bash
# Anthropic (Claude)
export ANTHROPIC_API_KEY=sk-ant-...

# Or OpenAI
export OPENAI_API_KEY=sk-...

# Or Groq (free tier available)
export GROQ_API_KEY=gsk_...
```

Add the export to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to persist it.

### Edit the Config

The default config uses Anthropic. To change the provider, edit `~/.openagent/config.toml`:

```toml
[default_model]
provider = "groq"                      # anthropic, openai, groq, ollama, etc.
model = "llama-3.3-70b-versatile"      # Model identifier for the provider
api_key_env = "GROQ_API_KEY"           # Env var holding the API key

[memory]
decay_rate = 0.05                      # Memory confidence decay rate

[network]
listen_addr = "127.0.0.1:4200"        # OFP listen address
```

### Verify Your Setup

```bash
openagent doctor
```

This checks that your config exists, API keys are set, and the toolchain is available.

---

## Spawn Your First Agent

### Using a Built-in Template

OpenAgent ships with 30 agent templates. Spawn the hello-world agent:

```bash
openagent agent spawn agents/hello-world/agent.toml
```

Output:

```
Agent spawned successfully!
  ID:   a1b2c3d4-e5f6-...
  Name: hello-world
```

### Using a Custom Manifest

Create your own `my-agent.toml`:

```toml
name = "my-assistant"
version = "0.1.0"
description = "A helpful assistant"
author = "you"
module = "builtin:chat"

[model]
provider = "groq"
model = "llama-3.3-70b-versatile"

[capabilities]
tools = ["file_read", "file_list", "web_fetch"]
memory_read = ["*"]
memory_write = ["self.*"]
```

Then spawn it:

```bash
openagent agent spawn my-agent.toml
```

### List Running Agents

```bash
openagent agent list
```

Output:

```
ID                                     NAME             STATE      PROVIDER     MODEL
-----------------------------------------------------------------------------------------------
a1b2c3d4-e5f6-...                     hello-world      Running    groq         llama-3.3-70b-versatile
```

---

## Chat with an Agent

Start an interactive chat session using the agent ID:

```bash
openagent agent chat a1b2c3d4-e5f6-...
```

Or use the quick chat command (picks the first available agent):

```bash
openagent chat
```

Or specify an agent by name:

```bash
openagent chat hello-world
```

Example session:

```
Chat session started (daemon mode). Type 'exit' or Ctrl+C to quit.

you> Hello! What can you do?

agent> I'm the hello-world agent running on OpenAgent. I can:
- Read files from the filesystem
- List directory contents
- Fetch web pages

Try asking me to read a file or look up something on the web!

  [tokens: 142 in / 87 out | iterations: 1]

you> List the files in the current directory

agent> Here are the files in the current directory:
- Cargo.toml
- Cargo.lock
- README.md
- agents/
- crates/
- docs/
...

you> exit
Chat session ended.
```

---

## Start the Daemon

For persistent agents, multi-user access, and the WebChat UI, start the daemon:

```bash
openagent start
```

Output:

```
Starting OpenAgent daemon...
OpenAgent daemon running on http://127.0.0.1:4200
Press Ctrl+C to stop.
```

The daemon provides:
- **REST API** at `http://127.0.0.1:4200/api/`
- **WebSocket** endpoint at `ws://127.0.0.1:4200/api/agents/{id}/ws`
- **WebChat UI** at `http://127.0.0.1:4200/`
- **OFP networking** on port 4200

### Check Status

```bash
openagent status
```

### Stop the Daemon

Press `Ctrl+C` in the terminal running the daemon, or:

```bash
curl -X POST http://127.0.0.1:4200/api/shutdown
```

---

## Using the WebChat UI

With the daemon running, open your browser to:

```
http://127.0.0.1:4200/
```

The embedded WebChat UI allows you to:
- View all running agents
- Chat with any agent in real-time (via WebSocket)
- See streaming responses as they are generated
- View token usage per message

---

## Next Steps

Now that you have OpenAgent running:

- **Explore agent templates**: Browse the `agents/` directory for 30 pre-built agents (coder, researcher, writer, ops, analyst, security-auditor, and more).
- **Create custom agents**: Write your own `agent.toml` manifests. See the [Architecture guide](architecture.md) for details on capabilities and scheduling.
- **Set up channels**: Connect any of 40 messaging platforms (Telegram, Discord, Slack, WhatsApp, LINE, Mastodon, and 34 more). See [Channel Adapters](channel-adapters.md).
- **Use bundled skills**: 60 expert knowledge skills are pre-installed (GitHub, Docker, Kubernetes, security audit, prompt engineering, etc.). See [Skill Development](skill-development.md).
- **Build custom skills**: Extend agents with Python, WASM, or prompt-only skills. See [Skill Development](skill-development.md).
- **Use the API**: 76 REST/WS/SSE endpoints, including an OpenAI-compatible `/v1/chat/completions`. See [API Reference](api-reference.md).
- **Switch LLM providers**: 20 providers supported (Anthropic, OpenAI, Gemini, Groq, DeepSeek, xAI, Ollama, and more). Per-agent model overrides.
- **Set up workflows**: Chain multiple agents together. Use `openagent workflow create` with a TOML workflow definition.
- **Use MCP**: Connect to external tools via Model Context Protocol. Configure in `config.toml` under `[[mcp_servers]]`.
- **Migrate from OpenClaw**: Run `openagent migrate --from openclaw`. See [MIGRATION.md](../MIGRATION.md).
- **Desktop app**: Run `cargo tauri dev` for a native desktop experience with system tray.
- **Run diagnostics**: `openagent doctor` checks your entire setup.

### Useful Commands Reference

```bash
openagent init                          # Initialize ~/.openagent/
openagent start                         # Start the daemon
openagent status                        # Check daemon status
openagent doctor                        # Run diagnostic checks

openagent agent spawn <manifest.toml>   # Spawn an agent
openagent agent list                    # List all agents
openagent agent chat <id>               # Chat with an agent
openagent agent kill <id>               # Kill an agent

openagent workflow list                 # List workflows
openagent workflow create <file.json>   # Create a workflow
openagent workflow run <id> <input>     # Run a workflow

openagent trigger list                  # List event triggers
openagent trigger create <args>         # Create a trigger
openagent trigger delete <id>           # Delete a trigger

openagent skill install <source>        # Install a skill
openagent skill list                    # List installed skills
openagent skill search <query>          # Search AgentHub
openagent skill create                  # Scaffold a new skill

openagent channel list                  # List channel status
openagent channel setup <channel>       # Interactive setup wizard

openagent config show                   # Show current config
openagent config edit                   # Open config in editor

openagent chat [agent]                  # Quick chat (alias)
openagent migrate --from openclaw       # Migrate from OpenClaw
openagent mcp                           # Start MCP server (stdio)
```
