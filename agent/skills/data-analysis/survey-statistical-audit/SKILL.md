---
name: survey-statistical-audit
description: 4-Pass 协议核验问卷分析报告里每一个数值（p 值、效应量、N、百分比、相关系数、回归系数等），全部从 03-integrate/output/*.rds 反查源头。用于在 generate_word / generate_pdf 之前堵截 LLM 编造或四舍五入飘移。改造自 ClaudeR/reviewer_zero。
when_to_use:
  - 用户索要正式报告（Word/PDF/学术稿）前
  - 主 agent 在 interpret_results 后产出了带具体数字的结论文本
  - 用户问 "数字对不对 / 帮我核验一下"
  - 报告里出现 "p < 0.05"、"r = 0.42"、"N=208" 等具体声明
---

# Survey Statistical Audit — 报告数值反幻觉协议

## Why this skill

LLM 在解读 R 输出时极易"创造性"地调整数字:
- `p = 0.0473` 被复述成 `p < 0.05`(合法但应记录)
- `r = 0.387` 被四舍五入到 `r ≈ 0.40`(违法,改变了精度)
- `N = 208` 在不同段落变成 `N ≈ 200`(违法)
- 完全杜撰的 "F(3, 204) = 5.62" 而 ANOVA 模块根本没跑(灾难)

**核心原则**: 报告文本里出现的**每个数字**,都必须能在 RDS 里找到来源,且与原值**字符级一致**(允许已声明的小数位截断)。

## 何时启动

在以下任一节点之前/之后自动调用:

| 时机 | 触发方式 |
|---|---|
| `generate_word` 之前 | 主 agent 主动调用本协议 |
| `generate_pdf` 之前 | 同上 |
| `interpret_results` 返回后,文本含 ≥3 个具体数字 | 主 agent 跑 Pass 1 提取 |
| 用户问 "数字对吗 / 核验一下" | 主 agent 显式触发 |

## 协议 — 4 个 Pass

```text
Pass 1: 提取  → 从待审文本扫出每一个数字 claim
Pass 2: 定位  → 给每个 claim 指向具体 RDS + 字段
Pass 3: 重算  → 跑 Rscript 把那个数字打印出来对照
Pass 4: 报表  → 输出 PASS / FAIL / NOTE 三类清单
```

### Pass 1: 提取 claim

用正则 + LLM 共同扫文本,识别以下模式:

| 类型 | 模式示例 |
|---|---|
| p 值 | `p = 0.xxx`、`p < 0.05`、`p > 0.10` |
| 检验统计量 | `t(204) = 2.31`、`F(3, 204) = 5.62`、`χ² = 12.4` |
| 效应量 | `Cohen's d = 0.42`、`η² = 0.08`、`r = 0.31` |
| 描述统计 | `M = 3.21`、`SD = 0.84`、`N = 208`、`Median = 4` |
| 频次/百分比 | `占 45.2%`、`156 人 (75%)` |
| 系数 | `β = 0.28`、`OR = 1.43`、`95% CI [0.12, 0.44]` |
| 信度 | `Cronbach's α = 0.87`、`KMO = 0.81` |
| 因子载荷 | `载荷 = 0.65`、`累计方差 67.3%` |

每个 claim 入登记表:

```python
{
  "claim_id": "C001",
  "verbatim": "新型消费券接受度 (M = 3.21, SD = 0.84)",
  "claim_type": "descriptive",
  "values": [{"M": "3.21"}, {"SD": "0.84"}],
  "context_module": "descriptives",  # 推测来源模块
  "context_variable": "new_voucher_acceptance",
}
```

### Pass 2: 定位到 RDS

每个 claim 都必须匹配到 `03-integrate/output/<module>_<survey>.rds`。匹配不到 = **FATAL**(说明数字是凭空编的)。

```r
# 加载对应 RDS
result <- readRDS("03-integrate/output/descriptives_s1.rds")
# 检查字段
str(result, max.level = 2)
# 找到 new_voucher_acceptance 这一行
result$summary[result$summary$variable == "new_voucher_acceptance", ]
```

如果找不到变量/模块:
- 文本说 "Cronbach's α = 0.87" 但 `reliability_s1.rds` 不存在 → **FATAL: 模块未运行**
- 文本说 "因子 1 载荷 0.65" 但 `factor_analysis_s1.rds$loadings` 里 因子 1 最大载荷只到 0.58 → **FATAL: 数字不存在**

### Pass 3: 重算 / 字符比对

```r
# 拿到原值
M_orig <- result$summary[result$summary$variable == "new_voucher_acceptance", "mean"]
# 按声明精度格式化
M_fmt <- sprintf("%.2f", M_orig)
claim_value <- "3.21"

if (M_fmt == claim_value) {
  status <- "PASS"
} else if (abs(M_orig - as.numeric(claim_value)) < 0.005) {
  status <- "NOTE"   # 四舍五入误差,可接受
  note <- sprintf("RDS=%.4f, claim=%s", M_orig, claim_value)
} else {
  status <- "FAIL"
  note <- sprintf("RDS=%.4f, claim=%s, 差 %.4f", M_orig, claim_value, M_orig - as.numeric(claim_value))
}
```

p 值特殊规则:
- 文本 `p < 0.05` & RDS p = 0.038 → **NOTE**(合法但记录,建议改成 `p = .038`)
- 文本 `p < 0.001` & RDS p = 0.0008 → **PASS**(APA 规范允许 `< .001`)
- 文本 `p = 0.05` & RDS p = 0.052 → **FAIL**(误导性,实际不显著)
- 文本 `p < 0.05` & RDS p = 0.061 → **FAIL**(根本不显著却声明显著)

### Pass 4: 输出审计报告

```markdown
## 统计审计报告

**审计范围**: 第 3 节"假设检验",共 17 个数值 claim

| 状态 | 数量 |
|---|---|
| ✅ PASS | 13 |
| ⚠️ NOTE | 3 |
| ❌ FAIL | 1 |

### FAIL (必须修正,不允许发出)

#### C014: "性别在消费券类型选择上有显著差异 (p = 0.03)"
- **来源**: 文本第 4 段
- **真实值**: `crosstabs_s1.rds$tests$gender_voucher_type$p.value = 0.087`
- **问题**: 实际 p = 0.087,非显著。声明显著属误导。
- **建议**: 改为 "性别在消费券类型选择上无显著差异 (χ²(3) = 6.61, p = .087)"

### NOTE (可接受但建议)

#### C003: "α = 0.87"
- **真实值**: 0.8693
- **建议**: 保留两位有效数字时显示 `α = .87`(APA 规范去掉前导 0)

### PASS 列表
(略,13 条全部通过)
```

## 工程化 — 让主 agent 一键审计

主 agent 在 `generate_word` 前应该自动跑一遍。可以通过两种方式:

### 方式 A: 走 dispatch_subagent

```python
audit = dispatch_subagent(
    role="data-analyst",  # 复用 data-analyst 角色 + 本 skill 当 system
    task=f"按 survey-statistical-audit 协议核验以下文本:\n\n{report_draft}",
    context=f"可读取的 RDS 列表: {list_rds_files()}",
)
```

### 方式 B: 新增专用 tool(推荐)

未来在 `app/tools.py` 加 `audit_report_claims(text, surveys)`:

```python
def audit_report_claims(text: str, surveys: list[str], state=None) -> Dict:
    # 1) 正则 + 结构化 LLM 提取 claim
    # 2) Rscript 调一个新脚本 02-analyze/audit_claims.R 跑 Pass 2+3
    # 3) 返回 PASS/NOTE/FAIL 三档清单
    pass
```

## 反模式

| # | 反模式 | 为什么错 |
|---|---|---|
| 1 | "审计通过率 80%,可以发出" | FAIL 是阻断性的,一个都不行 |
| 2 | "数字差一点点没关系" | 差 0.005 以内 = NOTE,以外 = FAIL,不准 negotiation |
| 3 | "我相信 LLM 不会编" | 实测就是会编,尤其是 effect size 和 CI |
| 4 | 跳过 Pass 1,直接眼看核对 | 漏检率高,必须程序化 |
| 5 | 只审 p 值不审其它数字 | 描述统计的 N、M、SD 编造同样误导 |

## 配套工具(待实现 — 优先级 P1)

- `02-analyze/audit_claims.R`: 接收 claim 列表,返回 PASS/NOTE/FAIL
- `app/tools.py:audit_report_claims`: 主 tool 封装
- `app/agent.py` TOOL_DEFS 加入 `audit_report_claims`,系统提示要求 `generate_word/pdf` 前必跑
- 审计报告附在 `03-integrate/output/audit/audit_<run_id>.md`

## 相关

- 改造自: `agent-infra-hub/02-r-quarto/ClaudeR/inst/prompts/reviewer_zero.md` (4-Pass 协议原版)
- 配套 skill: `langfuse`(审计调用本身要被追踪)
- 配套工具: `interpret_results`(用 Pydantic schema 已经强制每条 finding 引用具体数字;本 skill 是第二道防线)
