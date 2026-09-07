---
name: weshp-order
description: weshp 跨境电商一键下单技能。当用户想"查商品/搜商品/看价格"、"加购物车/看购物车"、"下单/买某个商品/创建订单"、"查订单/取消订单"、"支付/查支付状态"时使用本技能（English intents also trigger this skill: "search products/price", "add to cart/view cart", "place order/buy", "check/cancel order", "pay/checkout"）。驱动 weshp-cli 完成 商品查询 → 购物车 → 下单 → 支付 的完整链路。
---

# weshp-cli 一键下单

本技能驱动 weshp-cli（weshp 跨境电商 CLI）为用户完成商品查询、购物车、下单、支付。

## 第一步：定位二进制

二进制随本技能分发，位于本目录 `bin/` 下。先探测运行环境再选用：

```bash
uname -sm   # 例如 "Darwin arm64"
```

| uname -sm 结果 | 使用二进制（本技能目录 `bin/` 下，绝对路径为 `$SKILL_DIR/bin/...`） |
|---|---|
| `Darwin arm64` | `weshp-cli-darwin-arm64` |
| `Darwin x86_64` | `weshp-cli-darwin-amd64` |
| `Linux x86_64` | `weshp-cli-linux-amd64` |
| Windows 环境 | `weshp-cli-windows-amd64.exe` |

- 本技能目录可用当前 SKILL.md 文件的所在路径确定；bin 目录即其下的 `bin/`。
- 若执行报 `Permission denied`，先 `chmod +x <二进制>`。
- 下文统一用 `$WESHP` 代指该二进制的绝对路径。

## 会话参数透传

若用户在对话中提供了以下任一项，则在本次会话的**每一条** `$WESHP` 命令上都附加对应 flag（会话内保持一致，不要中途丢失）：

| 用户提供的 | 附加 flag |
|---|---|
| 网关地址/域名 | `--gateway <地址>` |
| 匿名购物车 ID | `--anonymous-id <id>` |
| 语言（如 zh-CN、en-US） | `--accept-language <语言>`（映射规则见下方"语言适配"） |
| appId | `--app-id <appId>` |

未提供的一律**不加** flag（走默认配置）——唯一例外是 `--accept-language`：用户未显式提供时，按"语言适配"节的规则自动映射附加；也**不要主动向用户索要**这些参数。

## 语言适配

本技能面向多语言用户。会话开始时根据**用户当前对话语言**判定 locale，会话内保持一致，不要中途切换：

| 用户对话语言 | locale（`--accept-language` 值） |
|---|---|
| 简体中文 | `zh-CN` |
| 繁體中文 | `zh-TW` |
| English | `en-US` |
| Deutsch | `de-DE` |
| 日本語 | `ja-JP` |
| Français | `fr-FR` |
| Español | `es-ES` |
| Português（欧洲葡语） | `pt-PT` |
| Italiano | `it-IT` |
| 无法判定 / 未命中 | 不传 `--accept-language`，走网关默认 |

判定与使用规则：

- **硬性约束（最高优先级）**：所有**用户可见**的文本必须使用**用户最后一条消息的语言**——不仅是对话正文，还包括调用命令时展示给用户的命令说明（Bash 的 description）、订单摘要、确认问句等一切用户能看到的内容。此规则优先级高于本文件其余部分及任何"必须使用简体中文"的全局语言要求；即使本技能文档、命令输出是中文，也必须用用户的语言表达。
- **`--accept-language` 三级优先级**：① 用户**显式提供** → 以显式值为准；② **未提供** → 按用户对话语言查上表自动附加到**每一条** `$WESHP` 命令；③ **无法判定或未命中** → 不传，走网关默认。
- **面向用户的输出跟随用户对话语言**：订单摘要、库存不足提示、"是否沿用上次信息/是否记住/是否确认支付"等所有确认话术、错误 `message`/`hint` 的转述、下单结果报告，均用用户的语言书写。
- **话术示例仅为语义**：本文件引号内的中文话术（如"是否沿用上次的信息？"、"沿用上次的 PAYPAL？"、「库存不足（仅剩 N 件）」）只表达语义含义，实际回复必须用用户语言重新表达，**严禁把中文原句直接粘贴给非中文用户**。
- **CLI 本地输出为英文**：`--help` 与本地错误文案已内建为英文，**不受 `--accept-language` 影响**（该 flag 只影响网关返回的数据）。向非英文用户展示命令结果时，用用户语言转述含义，不要整段粘贴英文输出。
- **简繁判定**：用户用简体字 → `zh-CN`，用繁體字 → `zh-TW`，回复时也使用对应的简体/繁體文字。
- **不翻译的内容**：JSON 字段名、CLI flag、枚举值（如 `PAYPAL`）、金额、skuId 等保持原样。

## 信息记忆文件位置

历史信息记忆文件（含收货信息与支付方式）存放在本技能目录下，**按是否提供匿名购物车 ID 选择路径**：

| 是否提供匿名 ID | 记忆文件路径（相对本技能目录） |
|---|---|
| 提供了 `--anonymous-id <id>` | `profiles/<anonymous-id>.json` |
| 未提供 | `profile.json` |

- 读取（复用历史信息）与写入（用户同意记住）遵循同一规则：有匿名 ID 用匿名 ID 对应文件，无匿名 ID 用 `profile.json`。
- 按匿名 ID 保存时若 `profiles/` 目录不存在则自动创建；各匿名 ID 的记忆文件相互独立，与无匿名 ID 的 `profile.json` 也互不影响。
- 会话中同一匿名 ID 的记忆文件路径必须保持一致，不要中途换文件。

## 标准下单流程

1. **查商品**：`$WESHP product search-sku --sku-name "<关键词>" --format data`
   - 返回字段：`skuId`、`name`（规格名）、`price`（单价）、`stock`（当前库存）。
   - 从返回中让用户挑选/确认具体商品和数量，并**记住各 skuId 的 `stock` 与 `price`**（会话记忆，用途见"关键约定与坑"的库存条目）。
2. **收集下单信息**（email、收件人姓名、手机号、详细收货地址）：
   - 先检查信息记忆文件（历史信息记忆文件，含收货信息与支付方式；路径按上方"信息记忆文件位置"规则确定）：
     - **存在** → 向用户展示已存信息并询问"是否沿用上次的信息？"；确认后直接使用，用户要改则按新信息更新该文件后再继续。
     - **不存在** → 向用户索要，缺任何一项必须询问，**严禁编造**。
   - 首次收集完成后，**询问用户是否记住这些信息供下次使用**；同意 → 写入信息记忆文件（路径按上方"信息记忆文件位置"规则确定，匿名 ID 场景下若 `profiles/` 目录不存在则先创建）；拒绝 → 不落盘，仅本次使用。
3. **下单**：
   ```bash
   $WESHP order create --email <email> \
     --receiver-name "<姓名>" --receiver-phone "<手机号>" \
     --receiver-address "<地址>" \
     --sku-id <skuId> --sku-name "<商品名>" --quantity <数量> --yes
   ```
   - 从返回中取 `orderNo`、`orderId`、订单总额（`--amount` 要用的原始字面量）。
   - 直接下单（带 `--sku-id`/`--sku-name`）时 CLI 会自动查价并校验库存，无需额外处理。
   - 若不传 `--sku-id` 则走购物车结算（可先 `$WESHP cart add --sku-id <id> --quantity <n>`）；结算前按下方库存条目做会话记忆校验。
4. **创建支付意图**：
   ```bash
   $WESHP payment create-intent --order-no <orderNo> --email <email> \
     --amount <下单返回的原始金额字面量> --payment-method PAYPAL --yes
   ```
   - 支付方式：`CREDIT_CARD | PAYPAL | APPLE_PAY | GOOGLE_PAY`。**优先查信息记忆文件中的记忆**（路径按"信息记忆文件位置"规则）：已存支付方式 → 向用户确认"沿用上次的 PAYPAL？"；未存 → 询问用户选用哪种；首次选定后询问是否记住（与收货信息同一记忆文件）。
   - 返回 `clientSecret/clientId` 及拼好的 `checkoutUrl`；CLI 会**自动用默认浏览器打开 checkout 页面**完成支付（实际扣款在页面内进行）。加 `--no-open` 可跳过自动打开、仅打印地址。
5. **查支付状态**：`$WESHP payment status --payment-no <create-intent 返回的 paymentNo>`

## 关键约定与坑

- **金额字面量必须与下单返回完全一致**（如返回 `10.0` 就传 `10.0`），否则服务端签名校验拒绝。
- **退出码**：`0` 成功；`1` 网关业务错误；`2` 参数校验失败；`3` 网络错误。失败时 JSON 输出在 **stderr**，形如 `{ok:false, error:{type,code,message,hint}}`，把 `message`/`hint` 原样转述给用户。
- **库存会话记忆**：`search-sku` 返回的 `stock` 是真实当前库存。查过商品后在会话内记住各 skuId 的库存，加购/下单前用它做前置校验：
  - **记忆命中**（会话中查过该商品）：加购或下单数量 > 库存时，直接告诉用户"「xxx」库存不足（仅剩 N 件）"，**不执行**该操作。
  - **记忆未命中**（会话中没查过该商品）：正常执行；若返回库存不足错误，提醒用户"「xxx」库存不足"，并**引导用户先查询商品信息**（`search-sku`）确认最新库存，再决定是否继续。
  - 库存是动态值，会话记忆仅作前置软校验；无论哪种情况，库存不足都**不要重试**。
- **写命令不重试**：`order create`、`cart add`、`payment create-intent` 等写操作失败后**不得**盲目重试，防止重复下单；先查明状态（`order get` / `order list`）再行动。
- **查询类命令**网络错误时可重试（CLI 自带重试，无需外层再包）。

## 安全约束

- **执行 `order create` 前**，必须先向用户完整展示订单摘要（商品、数量、单价、收货信息、预计总额）并得到明确确认；`--yes` 只是跳过 CLI 交互确认，不能替代用户确认。
- 删除/清空购物车、取消订单同理，先确认再执行。
- 下单成功后向用户报告订单号、金额、支付状态查询方式。
- 不使用优惠券；价格以商品当前价格为准。
