# Model Plan methodology

[中文](METHODOLOGY.zh-CN.md) · Live version: https://modelplan.ai/methodology

How Model Plan scores models, estimates cost and time, picks the ★ recommended effort and chooses which models appear, plus the sources it uses. The clients in this repository only display these published results; they never compute their own rankings.

## In short

| | What it means |
| --- | --- |
| **Ability** | Each benchmark is put on one scale and averaged by weight. 50 is the origin and 10 points is about one standard deviation. Missing benchmarks never count as zero. |
| **Cost** | API dollars to finish the same reference coding task. Across models we compare dollars; between one model's efforts, ratios. |
| **Time** | Real task runtime by source priority, divided by a reference time. Token speed is not task time. ≈ marks an estimate. |
| **★ Effort** | Among one model's efforts, AA ability is weighed against dollar cost. The pick is the effort with the smallest worst-case regret across a range of plausible preferences. With one measured effort, that effort is the pick. An unlabelled configuration is assumed to be the top setting. |

## Ability index

Each benchmark score is standardised on that source's frozen mean and spread, then combined by source budget:

```
z_s = (x_s − μ_s) / σ_s
S   = 50 + 10 · Σ w_s r_s z_s / Σ w_s r_s
```

- `x_s`: raw score of this configuration on source `s`
- `μ_s`, `σ_s`: frozen mean and standard deviation of source `s`
- `w_s`: source budget weight (table below)
- `r_s`: observation reliability, 1 for a regular run

Sources without an admitted observation are left out of both sums, so missing evidence is never scored as zero. Scores can fall below 0 or above 100; they are not percentages or capability multiples. The initial weights are declared engineering choices, not proven task-optimal.

## Reference expense

Source-normalised costs form a unitless index `E`. Multiplying by one frozen API task-cost reference gives equivalent dollars:

```
C_USD   = E · C_ref,USD
C_ref,s = exp(Σ_j v_j · ln C_s,j)
E       = exp(Σ w_s r_s · ln(C_s / C_ref,s) / Σ w_s r_s)
```

- The reference task is AA Coding Agent v1.5's coding benchmark mix, frozen on 2026-09-30 at $4.4635.
- Equivalent dollars are a projection from public API prices. They are not a bill or a Coding Plan deduction.
- Effort-to-effort cost ratios use only sources both efforts share.
- Unknown costs stay unknown.

## Task time

```
T_index = T_s,e / T_ref,s
```

Runtime is taken by source priority: AA Coding Agent wall time, then Terminal-Bench, then eligible Bug Hunt runtime. Decode time, time-to-first-token and tokens/s never stand in for task time. Estimates are marked and never affect the recommendation.

## Recommended effort (★)

The pick uses native AA ability `Q` and the matching USD task cost `C`. It chooses the effort with the smallest worst-case regret across nonnegative cost weights `a`, `b`, constrained by historical preferences:

```
U       = Q − a·C − b·log2(C / C_ref)          C_ref = $1 per AA task
Q_guard = max(0.8·Q_max, Q_min + 0.1·(Q_max − Q_min))
```

Efforts below `Q_guard` are not picked.

- **Single configuration.** When only one effort was measured, that effort is the pick, with no trade-off claimed.
- **Assumed top.** When a benchmark publishes one configuration without an effort label, it is assumed to be the top setting and shown as `★ Max (est.)`, or `On` for thinking toggles. A reviewed mapping replaces the assumption as soon as one exists.
- Time does not enter the pick. Vendor defaults are references only. Picks do not imply equal ability across models.

## Which models appear

- **Default fleet.** The latest reviewed flagship and everyday lines from OpenAI, Anthropic and Zhipu, up to ten. Visitors can change their own fleet.
- **Model pool.** One seat per reviewed series. A replaced generation spends 14 days as "comparing" before it leaves. Each maker has at most five seats.
- **Popularity routes.** Models that enter on popularity must also pass a quality floor: independent coding evidence, or a best AA rank within 60 to enter (80 to stay).

## Source weights

| Source | Ability | Cost | Time coverage |
| --- | --- | --- | --- |
| AA Intelligence | 30% | 20% | 0% |
| AA Coding Agent | 20% | 30% | 60% |
| LiveBench Coding | 10% | 0% | 0% |
| LiveBench Agentic | 10% | 0% | 0% |
| LiveBench task cost | 0% | 10% | 0% |
| CursorBench | 10% | 15% | 0% |
| Terminal-Bench | 10% | 15% | 25% |
| SWE-bench | 4% | 3% | 0% |
| Aider | 2% | 2% | 0% |
| LiveCodeBench | 2% | 0% | 0% |
| Bug Hunt | 2% | 5% | 15% |

Time weights measure coverage only; time values follow source priority, not a weighted blend.

## Sources and thanks

Model Plan stands on many public projects; thank you to their authors and maintainers.

- **Benchmarks:**
  - [Artificial Analysis](https://artificialanalysis.ai/) (AA Intelligence, AA Coding Agent)
  - [LiveBench](https://livebench.ai/)
  - [CursorBench](https://cursor.com/cursorbench)
  - [Terminal-Bench](https://www.tbench.ai/)
  - [Bug Hunt](https://github.com/phuryn/bug-hunt-bench)
  - [SWE-bench](https://www.swebench.com/)
  - [Aider](https://aider.chat/docs/leaderboards/)
  - [LiveCodeBench](https://livecodebench.github.io/)
- **Prices, plans and catalogue:**
  - [Real API Pricing](https://github.com/Fei2411/real-api-pricing) (MIT)
  - [models.dev](https://github.com/anomalyco/models.dev)
  - [OpenRouter](https://openrouter.ai/)
  - each vendor's official pricing, plan and model documentation
- **News and resets:**
  - [AIhot](https://aihot.news/)
  - [DidReset](https://didreset.com/)
  - [SemiAnalysis](https://newsletter.semianalysis.com/) public studies
- **Design assets:**
  - [Simple Icons](https://github.com/simple-icons/simple-icons) (CC0)
  - [Poly Haven](https://polyhaven.com/) (CC0)
  - [three.js](https://threejs.org/) (MIT)

Every published value keeps its original source and check time. Third-party estimates and news leads never rewrite plan terms without review. Vendor names and marks belong to their owners and only identify vendors.

Found a wrong number? Please [open an issue](https://github.com/modelplan/modelplan/issues/new) with a link to the source.
