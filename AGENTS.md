# Agent Instructions — Weshp Store

This document describes how AI agents can interact with the Weshp cross-border e-commerce store: searching products, managing a cart, placing orders, and completing payment.

The agent-facing interface is **weshp-cli**, a command-line tool bundled in this repository. It is available in two forms:

- As a **Claude Code skill** (recommended): installs the CLI plus a battle-tested instruction set that guides the agent through the full purchase flow with built-in safety confirmations.
- As a **standalone CLI**: any agent that can execute shell commands can drive it directly using this document.

## Getting Started

### Option 1: Install the Claude Code skill (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/hewen499/weshp-order/main/install.sh -o /tmp/weshp-install.sh
bash /tmp/weshp-install.sh
```

Then restart the Claude Code session. The skill provides the agent with the full ordering workflow, multi-language handling, and safety checks on every write operation.

### Option 2: Drive the CLI directly

Download the repository and use the binary for your platform from `bin/`:

| Platform | Binary |
|---|---|
| macOS (Apple Silicon) | `bin/weshp-cli-darwin-arm64` |
| macOS (Intel) | `bin/weshp-cli-darwin-amd64` |
| Linux x86_64 | `bin/weshp-cli-linux-amd64` |
| Windows | `bin/weshp-cli-windows-amd64.exe` |

Run `chmod +x <binary>` if needed, then `<binary> --help` to explore all commands.

## Typical Agent Flow

1. **Search** — find products and confirm price and stock
2. **Collect order info** — email, receiver name, phone, shipping address (ask the user; never fabricate)
3. **Order** — create the order (directly or via the cart)
4. **Pay** — create a payment intent and complete payment on the checkout page
5. **Confirm** — check the payment status

```bash
WESHP=bin/weshp-cli-<platform>   # example path

# 1. Search products
$WESHLP product search-sku --sku-name "lamp" --format data

# 2. (Optional) use the cart
$WESHLP cart add --sku-id 1001 --quantity 1
$WESHLP cart list

# 3. Create an order
$WESHLP order create --email user@example.com \
  --receiver-name "Jane Doe" --receiver-phone "+1234567890" \
  --receiver-address "1 Main Street, Springfield" \
  --sku-id 1001 --sku-name "Desk Lamp" --quantity 1 --yes

# 4. Create a payment intent (opens the checkout page in the browser)
$WESHLP payment create-intent --order-no <orderNo> --email user@example.com \
  --amount <exact amount literal from the order response> --payment-method PAYPAL --yes

# 5. Check payment status
$WESHLP payment status --payment-no <paymentNo>
```

## Command Reference

| Group | Command | Description |
|---|---|---|
| product | `product search-sku` | Search SKU stock (fuzzy match by `--sku-name`, paginated) |
| cart | `cart add` | Add a SKU to the cart |
| cart | `cart list` | View the cart |
| cart | `cart remove` | Remove items from the cart (batch supported) |
| cart | `cart clear` | Clear the cart |
| order | `order create` | Create an order (settles from the cart by default; use `--sku-id` for a direct order) |
| order | `order get` | Get order details by order number |
| order | `order list` | List orders by email (paginated) |
| order | `order cancel` | Cancel an order (only pending-payment orders can be cancelled) |
| payment | `payment create-intent` | Create a payment intent; returns `clientSecret` and opens the checkout page (`--no-open` to skip auto-open) |
| payment | `payment status` | Get payment status by payment number |

### Global Flags

| Flag | Description |
|---|---|
| `--gateway` | Store gateway address (defaults to the built-in test environment) |
| `--anonymous-id` | Anonymous cart ID (enables per-visitor cart persistence) |
| `--accept-language` | `Accept-Language` header for i18n of gateway responses (e.g. `en-US`, `zh-CN`, `ja-JP`) |
| `--app-id` | App ID required by product APIs |
| `--format` | Output format: `json` (default) / `data` / `table` |
| `--timeout` | HTTP timeout in seconds (default 15) |

## Important Rules

- **Payment requires human approval.** Before executing `order create` or `payment create-intent`, show the user the complete order summary (product, quantity, unit price, shipping info, total) and get explicit confirmation. Never complete a purchase without contemporaneous buyer consent.
- **Amount literal must match exactly.** Pass the order total to `payment create-intent --amount` exactly as returned by `order create` (e.g. `10.0` stays `10.0`); otherwise the server-side signature check rejects it.
- **Never retry write commands blindly.** If `order create`, `cart add`, or `payment create-intent` fails, check the current state first (`order get` / `order list`) before acting — blind retries can create duplicate orders.
- **Check stock before ordering.** `product search-sku` returns the real current `stock`; validate the requested quantity against it. On out-of-stock, inform the user and do not retry.
- **Exit codes**: `0` success; `1` gateway business error; `2` argument validation failure; `3` network error. On failure, JSON error output goes to **stderr** as `{ok:false, error:{type,code,message,hint}}`.
- **Query commands are safe to retry** on network errors (the CLI has built-in retries).
- **Payment methods**: `CREDIT_CARD` | `PAYPAL` | `APPLE_PAY` | `GOOGLE_PAY`. The actual charge is completed by the buyer on the hosted checkout page.

## Environment

- By default, weshp-cli connects to the **Weshp test environment** — orders and payments there are for evaluation only.
- To connect to another environment (e.g. production, where charges are real), pass `--gateway <address>` on every command.

## Agent Discovery

This file (`AGENTS.md`) is the canonical agent-facing description of the Weshp store's ordering interface. Raw URL for programmatic retrieval:

```
https://raw.githubusercontent.com/hewen499/weshp-order/main/AGENTS.md
```
