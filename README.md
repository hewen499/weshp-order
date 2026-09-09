# weshp-order — One-shot Ordering Skill for the Weshp Cross-border Store

A skill for [Claude Code](https://claude.com/claude-code): once installed, just talk to the AI in the conversation and it will walk you through the full flow of **product search → cart → ordering → payment → payment status check**.

The skill consists of two parts:

| Component | Description |
|---|---|
| `SKILL.md` | Skill instructions that guide the AI to call the CLI tool following a standardized flow |
| `bin/` | The weshp-cli command-line tool (multi-platform binaries, bundled with the skill) |

> Building your own agent (not Claude Code)? See [AGENTS.md](AGENTS.md) — the canonical agent-facing guide for driving weshp-cli directly.

## Prerequisites

- Claude Code installed (CLI or IDE plugin)
- macOS (Apple Silicon / Intel), Linux x86_64, or Windows (via Git Bash — see the Windows section below)

## Install

### Option 1: One-liner install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/hewen499/weshp-order/main/install.sh -o /tmp/weshp-install.sh
bash /tmp/weshp-install.sh
```

> To install from a fork or mirror, specify the repository URL: `WESHP_REPO_URL=<git-url> bash /tmp/weshp-install.sh`

### Option 2: Install from a cloned repository

If you have already cloned the repository, simply run the script inside it:

```bash
bash install.sh
```

The script will:

1. Detect your platform (`Darwin arm64` / `Darwin x86_64` / `Linux x86_64` / Windows Git Bash) and enable only the matching binary;
2. Install the skill into `~/.claude/skills/weshp-order/`;
3. On macOS, automatically remove the Gatekeeper quarantine attribute (`com.apple.quarantine`) from the downloaded files;
4. Register the skill for [Codex CLI](https://developers.openai.com/codex) as well: it uses the same open skills standard and reads user-level skills from `~/.agents/skills`, so the script links `~/.agents/skills/weshp-order` to the Claude install (falls back to a copy on systems without symlinks);
5. Verify the installation by running `--help`.

## Update

Simply re-run the install script (an overwriting update). **Your profile files are never overwritten**:

| File | Contents |
|---|---|
| `~/.claude/skills/weshp-order/profile.json` | Shipping & payment preferences when no anonymous cart ID is used |
| `~/.claude/skills/weshp-order/profiles/<anonymous-id>.json` | Preferences saved per anonymous cart ID |

## Uninstall

```bash
rm -rf ~/.claude/skills/weshp-order
```

If you no longer need your personal profile, back it up before deleting (see the table above).

## Usage

After installing, **restart your Claude Code session**, then simply talk in natural language, for example:

- "Find me the product called xx"
- "Pay order xxx with PayPal"
- "Check the payment status of order xxx"

You can also invoke the skill explicitly with `/weshp-order`.

### Using with Codex CLI

[Codex CLI](https://developers.openai.com/codex) follows the same [open agent skills standard](https://agentskills.io), so the skill installed by this script works there too — no extra steps. In Codex, mention it with `$weshp-order` or via `/skills`; Codex also picks it up automatically when your request matches the skill description.

> If you installed before this was supported, re-run the install script once to create the `~/.agents/skills` link.

## Security Notice

- By default, weshp-cli connects to the **Weshp production environment** (`https://weshv.com/store`) — orders and payments there are **real and charged**. For evaluation only, ask the AI to switch to the test environment (e.g. say "use the test environment" / 测试环境), which is passed via `--env test` (gateway `https://test.weshv.com/store`). Direct gateway address overrides are no longer supported.
- The AI will show you the order summary and confirm with you item by item before placing the order or paying.
- Do not share your shipping or payment details with untrusted session environments; profile files are stored locally on your machine only.

## Windows

### With Git Bash (recommended)

Git Bash ships with [Git for Windows](https://gitforwindows.org). In a Git Bash terminal, run the same one-liner as macOS/Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/hewen499/weshp-order/main/install.sh -o /tmp/weshp-install.sh
bash /tmp/weshp-install.sh
```

The script detects Windows (Git Bash) automatically, installs the skill to `%USERPROFILE%\.claude\skills\weshp-order`, and verifies the binary.

### Without Git Bash (manual install)

1. Clone the repository: `git clone --depth 1 https://github.com/hewen499/weshp-order.git`
2. Copy the repository contents (`SKILL.md`, `README.md`, `bin/`) to `%USERPROFILE%\.claude\skills\weshp-order`
3. Restart your Claude Code session (the Windows binary `bin/weshp-cli-windows-amd64.exe` does not need chmod)
