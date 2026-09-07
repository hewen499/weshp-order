# weshp-order — One-shot Ordering Skill for the Weshp Cross-border Store

A skill for [Claude Code](https://claude.com/claude-code): once installed, just talk to the AI in the conversation and it will walk you through the full flow of **product search → cart → ordering → payment → payment status check**.

The skill consists of two parts:

| Component | Description |
|---|---|
| `SKILL.md` | Skill instructions that guide the AI to call the CLI tool following a standardized flow |
| `bin/` | The weshp-cli command-line tool (multi-platform binaries, bundled with the skill) |

## Prerequisites

- Claude Code installed (CLI or IDE plugin)
- macOS (Apple Silicon / Intel) or Linux x86_64; for Windows see "Manual Install on Windows" at the end

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

1. Detect your platform (`Darwin arm64` / `Darwin x86_64` / `Linux x86_64`) and enable only the matching binary;
2. Install the skill into `~/.claude/skills/weshp-order/`;
3. On macOS, automatically remove the Gatekeeper quarantine attribute (`com.apple.quarantine`) from the downloaded files;
4. Verify the installation by running `--help`.

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

## Security Notice

- This skill talks to **real production trade APIs**: ordering creates a real order, and payment results in a real charge. The AI will show you the order summary and confirm with you item by item before placing the order or paying.
- weshp-cli ships with a default gateway address built in; to connect to a different environment, tell the AI the gateway address in the conversation (passed via `--gateway`).
- Do not share your shipping or payment details with untrusted session environments; profile files are stored locally on your machine only.

## Manual Install on Windows

1. Clone the repository: `git clone --depth 1 https://github.com/hewen499/weshp-order.git`
2. Copy the whole `skills/weshp-order` directory to `%USERPROFILE%\.claude\skills\weshp-order`
3. Restart your Claude Code session (the Windows binary `bin/weshp-cli-windows-amd64.exe` does not need chmod)
