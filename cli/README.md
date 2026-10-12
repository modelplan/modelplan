# modelplan — Go thin client

This is a read-only, anonymous, single static binary with no GUI. It reads the verified public publication, keeps the shared local cache (see [`../README.md`](../README.md)) and prints the hangar views in a terminal. The Claude Code mods call it, and the desktop menu-bar app will be built on it later.

```sh
cd cli
go test -race ./...
go build -o dist/modelplan ./cmd/modelplan

./dist/modelplan sync                 # verify and cache the current publication
./dist/modelplan lineup               # WHICH ENGINE for Anthropic and OpenAI
./dist/modelplan lineup --dev openai --json
./dist/modelplan effort opus          # ladder relative to ★ recommended
echo '{"model":{"id":"claude-opus-5-5"}}' | ./dist/modelplan statusline
./dist/modelplan statusline --harness codex --model gpt-6-astra --no-color
./dist/modelplan doctor
```

Example output (publication `23cd7308…`, release 0.18.9):

```text
WHICH ENGINE 选哪台 · Anthropic · 各模型都在 ★推荐档 · 成本以 Haiku 5.5 为 ×1
  Haiku 5.5 → Sonnet 5.5      能力 +8.3  成本 ×3.1
  Sonnet 5.5 → Opus 5.5       能力 +8.5  成本 ×1.9
  跳过：Fable 5.1、Opus 5（又贵又不更强）

  Opus 5.5           ★Med     能力  55.4 ████████████  成本 ×6.0   ▰▰▰▰▱  最强 最划算
  Fable 5.1          ★Med     能力  52.9 ███████████▌  成本 ×12    ▰▰▰▰▰  不如 Opus 5.5
  Sonnet 5.5         ★High    能力  46.9 ██████████▏   成本 ×3.1   ▰▰▰▱▱
  Opus 5             ★Med     能力  46.5 ██████████▏   成本 ×11    ▰▰▰▰▰  ≈ Sonnet 5.5 但更贵
  Haiku 5.5          ★XHigh   能力  38.6 ████████▍     成本 ×1.0   ▰▱▱▱▱  最省

▲ Opus 5 ★Med │ 能力 46.5 │ 成本 ×11 vs Haiku 5.5 │ ≈ Sonnet 5.5 但更贵
```

## Layout

| Package | Role |
| --- | --- |
| `cmd/modelplan` | Commands, flags, exit codes: 0 ok, 1 error, 2 usage, 3 no verified data, 75 another sync running. |
| `internal/publication` | Read protocol: pointer + ETag → manifest → component, each sha256-verified. The last good publication is kept on any failure. |
| `internal/store` | Shared cache: atomic writes, `sync.lock`, pruning. |
| `internal/digest` | **The only place that maps publication fields.** It decodes the published `client.data` fields only; missing client returns an explicit error. |
| `internal/lineup` | Published lineup DTOs; the old reference algorithm is test-only and pinned to the shared golden fixture. |
| `internal/render` | Terminal visual language: ANSI 256 amber/gold, zh/en, honours `NO_COLOR`. |
| `internal/detach` | Background sync for the status line. |

Only the standard library is used. The module requires Go ≥ 1.24.

Statusline defaults to `--harness claude-code`. For Codex, pass `--harness codex` and its exact native model ID. IDs are resolved only through the publication's reviewed, harness-specific mappings; display names and family names are not fallback identities. `未核对型号` / `id not reviewed` means this incoming ID is not reviewed for that harness, even if the model itself is in the catalogue. Sync once after a mapping update; the statusline remains cache-only.
