# Model Plan 方法与来源

[English](METHODOLOGY.md) · 网站版本：https://modelplan.ai/methodology

本文说明 Model Plan 怎么给模型打分、怎么估算成本和耗时、怎么选 ★ 推荐档、哪些模型能上场，以及用了哪些数据源。本仓库里的客户端只展示这些公开发布的结果，不会自己计算排名。

## 一句话版

| | 含义 |
| --- | --- |
| **能力分** | 把各家评测换成同一把尺子，再加权平均：50 是原点，每 10 分约一个标准差。缺的评测不按 0 分算。 |
| **成本** | 完成同一个参考编程任务要花多少 API 美元。跨模型比美元，同一模型的档位之间比倍率。 |
| **耗时** | 真实任务的运行时间，按来源优先级取，再除以参考时间；出字速度不算任务时间。带 ≈ 的是估算。 |
| **★ 推荐档** | 在同一模型的档位里，权衡网站显示的能力、美元成本和耗时，选「各种偏好下都不会太亏」的那一档；它是最值档，不是最高档。只测过一档的就是那一档；评测没标档位的按最高档推定。 |

## 能力指数

每个评测先按该来源冻结的均值与标准差换成标准分，再按来源预算加权合成：

```
z_s = (x_s − μ_s) / σ_s
S   = 50 + 10 · Σ w_s r_s z_s / Σ w_s r_s
```

- `x_s`：当前配置在来源 `s` 上的原始得分
- `μ_s`、`σ_s`：来源 `s` 冻结的均值与标准差
- `w_s`：来源预算权重（见下表）
- `r_s`：观测可靠度，常规观测为 1

没有合格观测的来源不进入求和，缺失的证据不按零分算。分数可以低于 0 或高于 100，它不是百分制，也不是能力倍率。首版权重是明确声明的工程选择，尚未证明对任务最优。

## 参考开销

各来源的费用先合成无量纲的开销指数 `E`，再乘同一个冻结的参考费用，得到等值美元：

```
C_USD   = E · C_ref,USD
C_ref,s = exp(Σ_j v_j · ln C_s,j)
E       = exp(Σ w_s r_s · ln(C_s / C_ref,s) / Σ w_s r_s)
```

- 参考任务采用 AA Coding Agent v1.5 的编程评测组合，冻结于 2026-09-30，参考费用为 $4.4635。
- 等值美元是按 API 公开价格做的投影，不是你的账单，也不是 Coding 套餐的扣额。
- 档位之间的费用倍率只用两档共有的来源计算。
- 未知费用保持未知。

## 任务耗时

```
T_index = T_s,e / T_ref,s
```

运行时间按来源优先级选取：AA Coding Agent 墙钟时间 → Terminal-Bench → 合格的 Bug Hunt 运行时间。解码耗时、首 token 时间和 token/s 不能当作任务时间。估算值会标出来，不用于模型之间的比较；在同一模型内只作为不确定区间进入推荐。

## 推荐档（★）

推荐用网站显示的数字：能力 `A`、每个参考任务的美元成本 `C`、同一模型内的任务耗时 `T`。在一组由站长记录的选择约束的非负参数 `a`、`b`、`t` 里，选「最坏情况下后悔最小」的档位：

```
U       = A − a·C − b·log2(C / C_ref) − t·log2(T)     C_ref = 每个任务 $1
Q_guard = max(0.8·Q_max, Q_min + 0.1·(Q_max − Q_min))  按原生 AA 分 Q 计算
```

- 低于 `Q_guard` 的档位不参与推荐。门槛按原生 AA 智能指数计算：它是有界的分数，"最高分的 80%"有意义；能力指数是区间刻度，比例没有意义。
- 耗时只按同一模型各档之间的倍数计入。缺失的耗时取该模型的已知范围，估算值取 p10–p90 区间；评判某一档时按慢的一端算。
- 约束来自站长的选择：GPT-5.6 Sol 上的三条（High 优于 Max、Medium 优于 High、Medium 优于 Low；当时没看耗时，只约束费用），以及 Luna XHigh 优于 Max、Haiku 5.5 XHigh 优于 High（含耗时）。记录在 producer 的 `balanced-coding-v5` 校准里，见 ADR 0045。

- **单一配置：** 只测过一档的模型，推荐就是那一档，不声称做过取舍。
- **推定最高档：** 评测只发布了一组没标档位的配置时，按最高档推定，显示为「★ Max（推定）」；有思考开关的显示「思考开」。一旦有核准的档位映射，就用映射替换推定。
- 厂商默认档只作参照，显示在 ★ 旁边；各模型的推荐档不代表能力相同。

### 常见问题

- **★ 是最高档吗？** 不是，按设计如此。★ 是同一模型各档里最值的一档；最高档的能力、成本和耗时单独列出，网站也能把所有模型切到最高档比较。
- **为什么和厂商默认档不一样？** 厂商默认是产品设置，还考虑响应速度、限流和定位；把各家默认放在一起，没有一个统一的取舍能同时解释它们，所以只作参照，不作为输入。
- **为什么便宜模型推荐更高档？** 按边际收益：便宜模型升一档只多几美分，贵模型升一档要多一美元以上。
- **能力分为什么会是负数或超过 100？** 它是冻结刻度（50 分是 2026 年 9 月前沿配置的平均水平，每 10 分约一个标准差），不是百分制。
- **已知局限：** 能力混合了通用与编码评测；成本按官方 API 价格计算一个参考任务（Claude、Codex 的订阅额度也随 API 价格变化）；不少任务耗时是单次运行或估算。★ 是校准过的产品规则，不是任务成功保证。

## 哪些模型上场

- **默认舰队：** OpenAI、Anthropic、智谱三家经核准的旗舰与日常型号，各取最新一代，最多 10 台。访客可以自己改。
- **模型池：** 每个核准的系列只占一个席位。被新一代替换的模型先进入 14 天「对比中」，再退场。每家厂商最多 5 个席位。
- **热度入选：** 靠热度入选的模型还要过质量线：有独立的编程评测，或 AA 最好排名进入前 60 名（留在池中需前 80 名）。

## 来源权重

| 来源 | 能力 | 成本 | 耗时覆盖 |
| --- | --- | --- | --- |
| AA Intelligence | 30% | 20% | 0% |
| AA Coding Agent | 20% | 30% | 60% |
| LiveBench Coding | 10% | 0% | 0% |
| LiveBench Agentic | 10% | 0% | 0% |
| LiveBench 任务费用 | 0% | 10% | 0% |
| CursorBench | 10% | 15% | 0% |
| Terminal-Bench | 10% | 15% | 25% |
| SWE-bench | 4% | 3% | 0% |
| Aider | 2% | 2% | 0% |
| LiveCodeBench | 2% | 0% | 0% |
| Bug Hunt | 2% | 5% | 15% |

耗时权重只用于计算完整度；耗时数值按来源优先级选取，不按权重混合。

## 数据源与致谢

Model Plan 建立在许多公开项目之上，感谢它们的作者和维护者。

- **评测：**
  - [Artificial Analysis](https://artificialanalysis.ai/)（AA Intelligence、AA Coding Agent）
  - [LiveBench](https://livebench.ai/)
  - [CursorBench](https://cursor.com/cursorbench)
  - [Terminal-Bench](https://www.tbench.ai/)
  - [Bug Hunt](https://github.com/phuryn/bug-hunt-bench)
  - [SWE-bench](https://www.swebench.com/)
  - [Aider](https://aider.chat/docs/leaderboards/)
  - [LiveCodeBench](https://livecodebench.github.io/)
- **价格、套餐与模型目录：**
  - [Real API Pricing](https://github.com/Fei2411/real-api-pricing)（MIT）
  - [models.dev](https://github.com/anomalyco/models.dev)
  - [OpenRouter](https://openrouter.ai/)
  - 各厂商官方的价格、套餐和模型文档
- **新闻与额度重置：**
  - [AIhot](https://aihot.news/)
  - [DidReset](https://didreset.com/)
  - [SemiAnalysis](https://newsletter.semianalysis.com/) 公开研究
- **设计素材：**
  - [Simple Icons](https://github.com/simple-icons/simple-icons)（CC0）
  - [Poly Haven](https://polyhaven.com/)（CC0）
  - [three.js](https://threejs.org/)（MIT）

每个公开发布的数值都保留原始来源和核对时间；第三方估算和新闻线索未经核对不会改写套餐条款。厂商名称和标识归各自所有，只用于标识厂商。

发现数字不对？欢迎[提 issue](https://github.com/modelplan/modelplan/issues/new)，并附上来源链接。
