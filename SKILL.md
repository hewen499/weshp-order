---
name: weshp-order
description: One-shot ordering skill for the Weshp cross-border store. Use this skill when the user wants to "search products/price", "add to cart/view cart", "place order/buy", "check/cancel order", or "pay/check payment status" (Chinese intents also trigger this skill: "查商品/搜商品/看价格"、"加购物车/看购物车"、"下单/买某个商品/创建订单"、"查订单/取消订单"、"支付/查支付状态"). It drives weshp-cli through the full flow of product search → cart → ordering → payment.
---

# weshp-cli One-shot Ordering

This skill drives weshp-cli (the Weshp cross-border e-commerce CLI) to complete product search, cart management, ordering, and payment for the user.

## Step 1: Locate the binary

The binary ships with this skill, under its `bin/` directory. Detect the runtime environment first:

```bash
uname -sm   # e.g. "Darwin arm64"
```

| `uname -sm` result | Binary to use (under this skill's `bin/`; absolute path `$SKILL_DIR/bin/...`) |
|---|---|
| `Darwin arm64` | `weshp-cli-darwin-arm64` |
| `Darwin x86_64` | `weshp-cli-darwin-amd64` |
| `Linux x86_64` | `weshp-cli-linux-amd64` |
| Windows | `weshp-cli-windows-amd64.exe` |

- This skill's directory is the directory containing the current SKILL.md file; the bin directory is `bin/` under it.
- If execution fails with `Permission denied`, run `chmod +x <binary>` first.
- Throughout this document, `$WESHP` refers to the absolute path of that binary.

## Session parameter passthrough

If the user provides any of the following in the conversation, append the corresponding flag to **every** `$WESHP` command in this session (keep it consistent for the whole session, do not drop it midway):

| Provided by the user | Flag to append |
|---|---|
| Gateway address/domain | `--gateway <address>` |
| Anonymous cart ID | `--anonymous-id <id>` |
| Language (e.g. zh-CN, en-US) | `--accept-language <language>` (mapping rules in "Language adaptation" below) |
| appId | `--app-id <appId>` |

For anything not provided, do **not** add the flag (use the default configuration) — the only exception is `--accept-language`: when the user has not explicitly provided it, attach it automatically per the rules in "Language adaptation"; also do **not** proactively ask the user for these parameters.

## Language adaptation

This skill serves multi-language users. At the start of the session, determine the locale from the **language of the user's current conversation**, and keep it consistent for the whole session without switching midway:

| User's conversation language | locale (`--accept-language` value) |
|---|---|
| 简体中文 | `zh-CN` |
| 繁體中文 | `zh-TW` |
| English | `en-US` |
| Deutsch | `de-DE` |
| 日本語 | `ja-JP` |
| Français | `fr-FR` |
| Español | `es-ES` |
| Português (European Portuguese) | `pt-PT` |
| Italiano | `it-IT` |
| Undeterminable / no match | omit `--accept-language`, use the gateway default |

Determination and usage rules:

- **Hard constraint (highest priority)**: all **user-visible** text must be in **the language of the user's last message** — not only the conversation body, but also the command descriptions shown to the user when invoking commands (the Bash description), order summaries, confirmation questions, and everything else the user can see. This rule takes priority over the rest of this file and any "always respond in a fixed language" global instruction; even if this skill's documentation or command output is in another language, express it in the user's language.
- **Three-level priority of `--accept-language`**: ① explicitly provided by the user → use the explicit value; ② not provided → look up the table above by the user's conversation language and attach it to **every** `$WESHP` command; ③ undeterminable or no match → omit it and use the gateway default.
- **User-facing output follows the user's conversation language**: order summaries, out-of-stock notices, all confirmation wording such as "reuse the saved info / remember it / confirm payment", paraphrases of error `message`/`hint`, and the order result report must all be written in the user's language.
- **Sample wording is semantic only**: quoted sample phrases in this file (e.g. "reuse the saved info?", "reuse the saved PAYPAL?", "out of stock (only N left)") express meaning only; the actual reply must be re-expressed in the user's language. **Never paste sample phrases verbatim to users who speak another language.**
- **The CLI's local output is English**: `--help` and local error messages are built in English and are **not** affected by `--accept-language` (that flag only affects data returned by the gateway). When showing command results to non-English users, paraphrase the meaning in their language instead of pasting the English output verbatim.
- **Simplified vs. Traditional Chinese**: if the user writes Simplified Chinese → `zh-CN` and reply in Simplified; Traditional Chinese → `zh-TW` and reply in Traditional.
- **Do not translate**: JSON field names, CLI flags, enum values (e.g. `PAYPAL`), amounts, skuId, etc. stay as-is.

## Profile file location

The profile file (shipping info and payment method) lives in this skill's directory, chosen by whether an anonymous cart ID was provided:

| Anonymous ID provided? | Profile file path (relative to this skill directory) |
|---|---|
| `--anonymous-id <id>` provided | `profiles/<anonymous-id>.json` |
| Not provided | `profile.json` |

- Reading (reusing saved info) and writing (user agrees to remember) follow the same rule: with an anonymous ID use that ID's file; without, use `profile.json`.
- When saving by anonymous ID, create the `profiles/` directory first if it does not exist; each anonymous ID's profile file is independent of the others and of the ID-less `profile.json`.
- Within a session, keep the profile file path for the same anonymous ID consistent; do not switch files midway.

## Standard ordering flow

1. **Search products**: `$WESHP product search-sku --sku-name "<keyword>" --format data`
   - Returned fields: `skuId`, `name` (variant name), `price` (unit price), `stock` (current stock).
   - Let the user pick/confirm the exact products and quantities from the results, and **remember each skuId's `stock` and `price`** (session memory; purpose in the stock entry under "Key conventions and pitfalls").
2. **Collect order info** (email, receiver name, phone, detailed shipping address):
   - First check the profile file (path per the "Profile file location" rules above):
     - **Exists** → show the saved info to the user and ask whether to reuse it; if confirmed, use it directly; if the user wants changes, update the file with the new info before continuing.
     - **Does not exist** → ask the user for it; if any item is missing you must ask; **never fabricate**.
   - After the first collection, **ask the user whether to remember this info for next time**; agree → write it to the profile file (path per the rules above; in the anonymous-ID scenario create the `profiles/` directory first if missing); decline → do not persist, use it for this session only.
3. **Create the order**:
   ```bash
   $WESHP order create --email <email> \
     --receiver-name "<name>" --receiver-phone "<phone>" \
     --receiver-address "<address>" \
     --sku-id <skuId> --sku-name "<product name>" --quantity <quantity> --yes
   ```
   - From the response take `orderNo`, `orderId`, and the order total (the raw literal to use for `--amount`).
   - When ordering directly (with `--sku-id`/`--sku-name`) the CLI automatically looks up the price and validates stock — no extra handling needed.
   - Without `--sku-id` it settles via the cart (you can first `$WESHP cart add --sku-id <id> --quantity <n>`); before settling, do the session-memory check per the stock entry below.
4. **Create the payment intent**:
   ```bash
   $WESHP payment create-intent --order-no <orderNo> --email <email> \
     --amount <raw amount literal from the order response> --payment-method PAYPAL --yes
   ```
   - Payment methods: `CREDIT_CARD | PAYPAL | APPLE_PAY | GOOGLE_PAY`. **Check the profile file first** (path per "Profile file location"): saved method → confirm with the user "reuse the saved PAYPAL?"; none saved → ask which to use; after the first choice, ask whether to remember it (same profile file as the shipping info).
   - The response returns `clientSecret/clientId` and the assembled `checkoutUrl`; the CLI **automatically opens the checkout page in the default browser** to complete payment (the actual charge happens on that page). Add `--no-open` to skip auto-opening and just print the URL.
5. **Check payment status**: `$WESHP payment status --payment-no <paymentNo returned by create-intent>`

## Key conventions and pitfalls

- **The amount literal must exactly match the order response** (e.g. if it returns `10.0`, pass `10.0`), otherwise the server-side signature check rejects it.
- **Exit codes**: `0` success; `1` gateway business error; `2` argument validation failure; `3` network error. On failure the JSON output goes to **stderr**, shaped like `{ok:false, error:{type,code,message,hint}}` — relay `message`/`hint` to the user verbatim.
- **Stock session memory**: the `stock` returned by `search-sku` is the real current stock. After searching products, remember each skuId's stock within the session and use it as a pre-check before cart add / order create:
  - **Memory hit** (the product was searched this session): if the requested quantity > stock, tell the user directly "「xxx」is out of stock (only N left)" and **do not** execute the operation.
  - **Memory miss** (not searched this session): proceed normally; if a stock error comes back, tell the user "「xxx」is out of stock" and **guide the user to search product info first** (`search-sku`) to confirm the latest stock before deciding whether to continue.
  - Stock is dynamic; session memory is only a soft pre-check. In either case, **do not retry** on out-of-stock.
- **No blind retries on write commands**: after `order create`, `cart add`, `payment create-intent` or other write operations fail, **do not** blindly retry to avoid duplicate orders; check the status first (`order get` / `order list`) before acting.
- **Query commands** may be retried on network errors (the CLI has built-in retries; no extra outer retry needed).

## Security constraints

- **Before executing `order create`**, show the user the complete order summary (product, quantity, unit price, shipping info, estimated total) and get explicit confirmation; `--yes` only skips the CLI's interactive confirmation and cannot replace user confirmation.
- Same for cart deletion/clearing and order cancellation: confirm first, then execute.
- After a successful order, report the order number, the amount, and how to check the payment status to the user.
- No coupons are used; prices are based on the product's current price.
