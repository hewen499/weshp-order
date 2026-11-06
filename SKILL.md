---
name: weshp-order
description: 'One-shot ordering skill for the Weshp cross-border store. Use this skill when the user wants to "search products/price", "add to cart/view cart", "place order/buy", "check/cancel order", or "pay/check payment status" (Chinese intents also trigger this skill: "查商品/搜商品/看价格"、"加购物车/看购物车"、"下单/买某个商品/创建订单"、"查订单/取消订单"、"支付/查支付状态"). It drives weshp-cli through the full flow of product search → cart → ordering → payment.'
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
| Environment (e.g. 测试环境/test environment) | `--env test` (use `--env prod` only if the user explicitly says 生产环境/production) |
| Anonymous cart ID | `--anonymous-id <id>` |
| Language (e.g. zh-CN, en-US) | `--accept-language <language>` (mapping rules in "Language adaptation" below) |
| appId | `--app-id <appId>` |

For anything not provided, do **not** add the flag (use the default configuration) — the only exception is `--accept-language`: when the user has not explicitly provided it, attach it automatically per the rules in "Language adaptation"; also do **not** proactively ask the user for these parameters.

## Environment

The CLI selects the environment via `--env` and connects to the **production environment by default**:

| Environment | Gateway | Checkout page (payment intent) |
|---|---|---|
| `prod` (default) | `https://weshv.com/store` | `https://checkout.airwallex.com/#/standalone/checkout` |
| `test` | `https://test.weshv.com/store` | `https://checkout-demo.airwallex.com/#/standalone/checkout` |

- **Production is where real charges happen.** Before running any write command (`order create`, `payment create-intent`, …) in the default (prod) environment, make sure the user is aware the order and payment are real; the "Security constraints" confirmation must state which environment the command will hit.
- Direct gateway address overrides (`--gateway` / `WESHP_GATEWAY`) are no longer supported — switch environments only via `--env`.

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
- **Scope of `--accept-language` on local output**: `--help`/usage text (command descriptions, flag descriptions, template labels) is localized via `--accept-language`; pass `--help` output through verbatim to the user. All list data now arrives as JSON — render it yourself as markdown tables **with headers in the user's conversation language** (see "Table presentation"). Local error messages (e.g. `Error:`, `Cancelled`) remain built-in English — when showing those to non-English users, paraphrase the meaning in their language instead of pasting them verbatim.
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

1. **Search products**: `$WESHP product search-sku --sku-name "<keyword>"`
   - Columns: `skuId`, `name` (variant name), `price` (unit price), `stock` (current stock; `⚠` marks out-of-stock).
   - The table footer shows the total count and current page/size. If `total` exceeds the current page, fetch the remaining pages with `--page-num` (to list all products at once, use `--page-size 100`, the max).
   - Let the user pick/confirm the exact products and quantities from the results, and **remember each skuId's `stock` and `price`** (session memory; purpose in the stock entry under "Key conventions and pitfalls").
2. **Collect order info** (email, receiver name, phone, and structured shipping address):
   - **Structured address fields (backend validates strictly, all required unless noted)**: `receiverCountry` (ISO 3166-1 alpha-2, e.g. `US`/`DE`), `receiverCity`, `receiverZipCode`, `receiverAddress` (**street + house number only**, e.g. `Musterstraße 12` — do NOT pack country/state/city/zip into it), `receiverState` (two-letter code; **required only for US/AU/CA**, optional elsewhere).
   - **Receiver name, two ways**: `--receiver-first-name` + `--receiver-last-name` (preferred; Klarna needs a non-empty lastName) OR `--receiver-name`. When both are given, first+last win and the server signs with the resolved "first last" name.
   - First check the profile file (path per the "Profile file location" rules above):
     - **Exists** → show the saved info to the user and ask whether to reuse it; if confirmed, use it directly; if the user wants changes, update the file with the new info before continuing. **Legacy profiles missing the new structured fields (country/city/zipCode or first/last name) cannot be reused as-is** — ask the user for the missing items and update the file before ordering.
     - **Does not exist** → ask the user for it; if any item is missing you must ask; **never fabricate**.
   - After the first collection, **ask the user whether to remember this info for next time**; agree → write it to the profile file (path per the rules above; in the anonymous-ID scenario create the `profiles/` directory first if missing); decline → do not persist, use it for this session only.
3. **Create the order**:
   ```bash
   $WESHP order create --email <email> \
     --receiver-first-name "<first>" --receiver-last-name "<last>" \
     --receiver-phone "<phone>" \
     --receiver-address "<street + house number>" \
     --receiver-country "<US|DE|...>" --receiver-state "<state or omit>" \
     --receiver-city "<city>" --receiver-zip-code "<zip>" \
     --sku-id <skuId> --sku-name "<product name>" --quantity <quantity> --yes
   ```
   - Name alternative: pass `--receiver-name "<full name>"` instead of the first/last pair (the pair takes precedence when both are given).
   - Omit `--receiver-state` for countries other than US/AU/CA; the CLI locally rejects missing country/city/zip and non-2-letter country codes (exit code 2) before any network call.
   - From the response take `orderNo`, `orderId`, and the order total (the raw literal to use for `--amount`).
   - When ordering directly (with `--sku-id`/`--sku-name`) the CLI automatically looks up the price and validates stock — no extra handling needed.
   - Without `--sku-id` it settles via the cart (you can first `$WESHP cart add --sku-id <id> --quantity <n>`); before settling, do the session-memory check per the stock entry below.
4. **Create the payment intent**:
   ```bash
   $WESHP payment create-intent --order-no <orderNo> --email <email> \
     --amount <raw amount literal from the order response> --payment-method <method> --yes
   ```
   - Payment methods: `CREDIT_CARD | PAYPAL | APPLE_PAY | GOOGLE_PAY`. **Check the profile file first** (path per "Profile file location"): saved method → confirm with the user "reuse the saved PAYPAL?"; none saved → ask which to use; after the first choice, ask whether to remember it (same profile file as the shipping info).
   - The response returns `clientSecret/clientId` and the assembled `checkoutUrl`; the CLI **automatically opens the checkout page in the default browser** to complete payment (the actual charge happens on that page). Add `--no-open` to skip auto-opening and just print the URL.
5. **Check payment status**: `$WESHP payment status --payment-no <paymentNo returned by create-intent>`

## Table presentation (markdown)

The CLI prints **JSON only** (`--format json` envelope, default, or `--format data` for the raw payload); it no longer renders tables. Rendering is the skill's job:

- **Data source**: run the CLI command, then read the JSON (`data` field of the envelope, or the whole output with `--format data`). Never call the removed `--format table` — it now fails with a validation error (exit code 2).
- **Mandatory markdown tables**: whenever tabular data is shown to the user in the conversation (search results, cart contents, order lists, order items), render **every group of records** as a Markdown table — one row per record, no prose dumps of raw JSON. Nested groups (e.g. the items inside an order detail) get their own table.
- **Table rules**:
  - Header row + `| --- |` separator + one row per record, all wrapped in `| cell | cell |` pipes.
  - Pick concise columns per command: search results → `skuId | name | price | stock`; cart → `skuId | name | quantity | price | status`; order list → `orderNo | status | totalAmount | receiverName | createdAt`; order items → `skuId | name | unitPrice | quantity | subtotal`.
  - Numeric/amount columns right-align the separator (`---:`); text columns left-align (`---`).
  - **Column headers MUST be localized** to the user's conversation language using the header map below; **default/unknown language = en-US = use the JSON field names verbatim** (`skuId`, `name`, ...). Data values stay as returned.
  - Header map (field order follows each table's column list above; use the row of the user's language):

    | Language | skuId | name | price | stock | quantity | status | unitPrice | subtotal | orderNo | totalAmount | freight | receiverName | createdAt | items |
    |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
    | en-US (default) | skuId | name | price | stock | quantity | status | unitPrice | subtotal | orderNo | totalAmount | freight | receiverName | createdAt | items |
    | zh-CN | 商品编号 | 商品名称 | 价格 | 库存 | 数量 | 状态 | 单价 | 小计 | 订单号 | 总额 | 运费 | 收货人 | 创建时间 | 商品明细 |
    | zh-TW | 商品編號 | 商品名稱 | 價格 | 庫存 | 數量 | 狀態 | 單價 | 小計 | 訂單編號 | 總額 | 運費 | 收貨人 | 建立時間 | 商品明細 |
    | de-DE | SKU-Nr. | Name | Preis | Bestand | Menge | Status | Einzelpreis | Zwischensumme | Bestellnr. | Gesamtbetrag | Versandkosten | Empfänger | Erstellt am | Artikel |
    | ja-JP | 商品ID | 商品名 | 価格 | 在庫 | 数量 | ステータス | 単価 | 小計 | 注文番号 | 合計金額 | 送料 | 受取人 | 作成日時 | 商品明細 |
    | fr-FR | Réf. produit | Nom | Prix | Stock | Quantité | Statut | Prix unitaire | Sous-total | N° commande | Montant total | Frais de port | Destinataire | Créé le | Articles |
    | es-ES | ID producto | Nombre | Precio | Stock | Cantidad | Estado | Precio unitario | Subtotal | N.º de pedido | Importe total | Envío | Destinatario | Fecha de creación | Artículos |
    | pt-PT | ID do produto | Nome | Preço | Stock | Quantidade | Estado | Preço unitário | Subtotal | N.º do pedido | Valor total | Portes | Destinatário | Data de criação | Artigos |
    | it-IT | ID prodotto | Nome | Prezzo | Giacenza | Quantità | Stato | Prezzo unitario | Subtotale | N. ordine | Totale | Spedizione | Destinatario | Creato il | Articoli |

    Determine the language the same way the CLI does: exact locale tag first (`zh-CN`/`zh-TW`/`en-US`/`de-DE`/`ja-JP`/`fr-FR`/`es-ES`/`pt-PT`/`it-IT`); a `zh-*` variant maps to zh-TW when it carries `tw/hk/mo/Hant`, otherwise zh-CN; other `xx-*` match by primary subtag; anything undeterminable falls back to en-US.
  - Out of stock (stock `0`) → render the stock cell as `⚠ 0`; image URLs and other oversized values are omitted (or replaced with a short label), never truncated mid-URL.
  - Never invent rows: the row count must match the JSON (`list.length` / `items.length` / meta `count`). Totals/pagination (`total`, `count`) go as one plain line **below** the table, not as extra rows.
  - Do NOT write an external rendering script (Python/awk/…) — the table is written directly in the reply text.
- **Order confirmation summary** (before `order create`, required by "Security constraints"): also a Markdown table — `name | quantity | unitPrice | subtotal` rows plus a final bolded estimated-total line below it, followed by the shipping info (email, receiver, phone, structured address) as a short list. Use the `price`/`stock` remembered from the search step for unit price and the stock pre-check.

## Key conventions and pitfalls

- **Amount / signature**: the amount literal must exactly match the order response (e.g. if it returns `10.0`, pass `10.0`), otherwise the server-side signature check rejects it. The sign covers `appId/email/receiverName/receiverPhone/receiverAddress` — when first/last name are given, the resolved "first last" value is what gets signed; the CLI handles this internally.
- **Local receiver validation before any network call**: missing country/city/zip/address/phone/name or a non-2-letter country code fails locally with exit code 2; US/AU/CA orders without `--receiver-state` also fail locally. Do not retry these — supply the missing field instead.
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
