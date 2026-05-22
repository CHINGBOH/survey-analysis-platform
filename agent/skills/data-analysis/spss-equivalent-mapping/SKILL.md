---
name: spss-equivalent-mapping
description: 把本平台的 13 个分析模块 + 40+ 子过程精确对应到 SPSS 菜单路径（Analyze > Descriptive Statistics > Frequencies 等）。用户用 SPSS 术语提问时（"做个 K-Means"、"跑 Tukey HSD"、"SPSS 的卡方检验在哪"），用本表反查决定调哪个 module + 在 interpret 时该展示哪些指标。
when_to_use:
  - 用户用 SPSS 菜单路径名称提问
  - 用户问 "SPSS 里 X 怎么做 / 在哪里 / 对应你的什么"
  - 用户从 SPSS 输出截图迁移分析
  - 在 set_analysis_plan 时需要把用户描述翻译成具体 module 名
---

# SPSS Equivalent Mapping

## 总览

| 本平台 module | SPSS 主菜单路径 | 何时用 |
|---|---|---|
| `descriptives` | Analyze → Descriptive Statistics → Frequencies / Descriptives / Explore | 频次、均值、标准差、偏度峰度 |
| `crosstabs` | Analyze → Descriptive Statistics → Crosstabs | 列联表 + 卡方 + Cramér's V |
| `ttest` | Analyze → Compare Means → Independent/Paired/One-Sample T Test | 两组均值差 |
| `anova` | Analyze → General Linear Model → Univariate (或 Compare Means → One-Way ANOVA) | 三组及以上均值差 + 事后检验 |
| `correlation` | Analyze → Correlate → Bivariate (Pearson/Spearman) | 双变量相关矩阵 |
| `reliability` | Analyze → Scale → Reliability Analysis | Cronbach's α + ICC + 分半 |
| `factor_analysis` | Analyze → Dimension Reduction → Factor | EFA / PCA + KMO + Bartlett |
| `regression` | Analyze → Regression → Linear / Binary Logistic / Ordinal | 线性/逻辑/有序回归 |
| `mediation` | Process Macro (Hayes) — Model 4 | 中介效应 + Bootstrap |
| `moderation` | Process Macro (Hayes) — Model 1 / 2 / 3 | 调节效应 + 简单斜率 |
| `cluster` | Analyze → Classify → K-Means Cluster / Hierarchical Cluster / TwoStep | 聚类分析 |
| `power_bootstrap` | (SPSS 无直接菜单; G*Power + Bootstrap 选项) | 功效分析 + Bootstrap CI |
| `survey_specific` | (SPSS 无直接菜单; 自定义/syntax) | Likert/NPS/缺失模式/开放题 |

## 细分子过程对照

### descriptives — 描述统计

| 子过程 | SPSS 路径 | 本平台输出字段(`descriptives_*.rds`) |
|---|---|---|
| 频次表 | Frequencies | `$frequencies` |
| 集中趋势(M/Mdn/Mode) | Descriptives / Frequencies | `$summary$mean / $median / $mode` |
| 离散程度(SD/Var/Range) | Descriptives | `$summary$sd / $var / $range` |
| 偏度峰度 | Descriptives → Statistics | `$summary$skew / $kurt` |
| 分位数 / 四分位 | Frequencies → Statistics → Quartiles | `$summary$q25 / $q75` |
| 探索性(Explore) | Explore | `$boxplot_data`(箱线图源) |

### crosstabs — 列联表

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| 列联表 | Crosstabs | `$table` |
| 卡方独立性 | Crosstabs → Statistics → Chi-square | `$tests$chi_sq` |
| Fisher 精确(2x2) | Crosstabs → Statistics → Fisher's | `$tests$fisher` |
| 效应量 Cramér's V / Phi | Crosstabs → Statistics → Phi and Cramér's V | `$effects$cramers_v` |
| 残差(标准化/调整) | Crosstabs → Cells → Residuals | `$residuals` |

### ttest — t 检验

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| 独立样本 t | Independent-Samples T Test | `$independent` |
| 配对样本 t | Paired-Samples T Test | `$paired` |
| 单样本 t | One-Sample T Test | `$one_sample` |
| Levene 方差齐性 | (内嵌于 Independent t) | `$independent$levene` |
| 效应量 Cohen's d | (SPSS 26+ Estimate effect size 选项) | `$independent$cohens_d` |

### anova — 方差分析

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| 单因素 ANOVA | One-Way ANOVA | `$oneway` |
| 多因素 ANOVA | Univariate (GLM) | `$factorial` |
| 重复测量 | GLM → Repeated Measures | `$repeated_measures` |
| Tukey HSD 事后 | Post Hoc → Tukey | `$posthoc$tukey` |
| Bonferroni 事后 | Post Hoc → Bonferroni | `$posthoc$bonferroni` |
| Games-Howell(不齐方差) | Post Hoc → Games-Howell | `$posthoc$games_howell` |
| 效应量 η² / ω² | Estimate effect size | `$effects$eta_sq / omega_sq` |

### correlation — 相关

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| Pearson | Correlate → Bivariate → Pearson | `$pearson` |
| Spearman | Correlate → Bivariate → Spearman | `$spearman` |
| Kendall's τ | Correlate → Bivariate → Kendall | `$kendall` |
| 偏相关 | Correlate → Partial | `$partial` |

### reliability — 信度

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| Cronbach's α | Reliability → Alpha | `$alpha` |
| McDonald's ω | (R-only; SPSS 28+ Omega) | `$omega` |
| 删项后 α | Reliability → Statistics → Scale if item deleted | `$item_stats$alpha_if_deleted` |
| 分半信度 | Reliability → Split-half | `$split_half` |
| 类内相关 ICC | Reliability → Intraclass | `$icc` |

### factor_analysis — 因子分析

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| KMO 测度 | Factor → Descriptives → KMO and Bartlett | `$kmo` |
| Bartlett 球形检验 | 同上 | `$bartlett` |
| 主成分 PCA | Factor → Extraction → Principal Components | `$pca` |
| 主轴 PAF | Factor → Extraction → Principal Axis | `$paf` |
| Varimax 正交旋转 | Factor → Rotation → Varimax | `$loadings_rotated` |
| Promax 斜交旋转 | Factor → Rotation → Promax | `$loadings_promax` |
| 碎石图 | Factor → Extraction → Scree plot | `$scree_data` |
| 因子得分 | Factor → Scores → Save as variables | `$scores` |

### regression — 回归

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| 多元线性回归 | Regression → Linear | `$linear` |
| 二元 logistic | Regression → Binary Logistic | `$logistic` |
| 有序 logistic | Regression → Ordinal | `$ordinal` |
| 共线性诊断 VIF | Regression → Statistics → Collinearity | `$linear$vif` |
| 残差诊断 | Regression → Plots / Save | `$linear$residuals` |
| Durbin-Watson | Regression → Statistics → Durbin-Watson | `$linear$durbin_watson` |
| 标准化 β | (内嵌输出) | `$linear$beta` |

### mediation / moderation — Process Macro 对应

| 模型 | Process Model # | 本平台 module |
|---|---|---|
| 简单中介(X→M→Y) | Model 4 | `mediation`,默认 5000 boot |
| 简单调节(X*W→Y) | Model 1 | `moderation` |
| 调节中介 | Model 7 / 14 | `mediation`(扩展) |
| 双调节 | Model 2 / 3 | `moderation`(扩展) |
| 串联中介 | Model 6 | (待实现) |

### cluster — 聚类

| 子过程 | SPSS 路径 | 输出 |
|---|---|---|
| K-Means | Classify → K-Means Cluster | `$kmeans` |
| 系统(层次) | Classify → Hierarchical | `$hierarchical` |
| 两步法 | Classify → TwoStep Cluster | `$twostep` |
| 树状图 | Hierarchical → Plots → Dendrogram | `$hierarchical$dendrogram_data` |
| 轮廓系数 | (R-only) | `$silhouette` |

### survey_specific — 问卷专用(SPSS 无直接菜单)

| 子过程 | SPSS 中怎么做 | 本平台 |
|---|---|---|
| Likert 累积分布 | 自己写 syntax 或 COMPUTE | `survey_specific_*.rds$likert_dist` |
| 顶箱/底箱(Top-2/Bottom-2 Box) | RECODE + Frequencies | `$top_bottom_box` |
| NPS(净推荐值) | RECODE 0-6/7-8/9-10 + COMPUTE | `$nps` |
| 缺失值模式 | Missing Value Analysis(附加模块) | `$missing_patterns` |
| 开放题词频 | (SPSS Text Analytics 单独付费) | `$open_text_keywords` |

## 用户提问的反查模板

用户问: **"SPSS 的 Tukey HSD 在你这怎么做?"**

```text
1. 在 ANOVA → 事后检验。
2. 在本平台用: run_analysis_module(module="anova")
3. 完成后看 anova_<survey>.rds$posthoc$tukey
4. 或直接 interpret_results("anova") 自动提取并解读
```

用户问: **"我在 SPSS 跑了个 K-Means 出 3 类,你能做吗?"**

```text
1. 对应 module: cluster
2. set_analysis_plan(modules=["cluster"], ...)
3. run_analysis_module("cluster") — 默认会尝试 K=2..6,挑最优(轮廓系数)
4. 想强制 K=3 → 当前要改 03-analyze/an-cluster.R 里 k_range 参数
5. 看 cluster_<survey>.rds$kmeans$centers / $cluster_sizes
```

## 反模式

| # | 反模式 | 正确做法 |
|---|---|---|
| 1 | 用户说"卡方",直接跑 `crosstabs` | 先问是 2x2 还是更大?是独立性还是拟合优度? |
| 2 | 用户说"回归",默认跑线性 | 先看因变量类型:连续→linear,二分类→logistic |
| 3 | 用户说"做个 PCA",跑 factor_analysis 走 PCA | 先确认目的:降维(PCA)还是构念测量(EFA/PAF)? |
| 4 | SPSS 显著但本平台不显著 → 怀疑 R 错了 | 先检查样本筛选、缺失处理、检验类型是否完全一致(t 检验默认 Welch 还是 Student?) |
| 5 | 复制 SPSS 表头当作 R 字段名 | 用本 skill 的"输出字段"列查 RDS 路径 |

## 相关

- 配套 skill: `writing-r-code`(写实际的 R 代码实现这些方法)
- 配套 skill: `survey-statistical-audit`(数字回流 SPSS 风格表格前必须核验)
- 配套工具: `set_analysis_plan`、`run_analysis_module`、`get_results`、`interpret_results`
