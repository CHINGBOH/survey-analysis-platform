# SPSS 全功能统计方法与图表调研

## 一、概览

### 1.1 产品版本与定位

IBM SPSS Statistics 是全球最广泛使用的统计分析软件之一，当前主流版本为 **29.0**（2022 年发布）和 **30.0**（2023 年发布），最新版本已升至 **v32**（2025年）。本调研以 v29/30 为基准，兼顾 v32 新增功能。

SPSS Statistics 的核心用户群体为社会科学、心理学、教育学、医学、市场研究领域，特别适合 **大规模问卷数据分析**。

### 1.2 模块划分

SPSS Statistics 采用 **Base + Add-on 模块** 授权模式：

| 模块名称 | 英文名 | 主要功能 |
|---------|--------|---------|
| 基础版 | Base | 描述统计、均值比较、相关、基础回归、非参数检验、频率、探索等 |
| 高级统计 | Advanced Statistics | GLM、混合模型、GZLM、GEE、生存分析 |
| 回归 | Regression | 逻辑回归、有序回归、Probit、非线性回归、二阶段最小二乘 |
| 类别数据 | Categories | 对应分析、最优化标度(CATPCA/PRINCALS/OVERALS/CATREG) |
| 预测 | Forecasting | 时间序列、ARIMA、专家建模器、季节分解 |
| 决策树 | Decision Trees | CHAID、CRT、QUEST 决策树 |
| 缺失值分析 | Missing Values | MVA、多重填补 |
| 复杂样本 | Complex Samples | 分层/整群抽样调查数据分析 |
| 自定义表格 | Custom Tables | CTABLES 过程 |
| 直接营销 | Direct Marketing | RFM、聚类分析客户细分 |
| 联合分析 | Conjoint | 联合分析实验设计与估计 |
| Bootstrap | Bootstrapping | Bootstrap 置信区间与显著性检验 |
| 数据准备 | Data Preparation | 自动数据准备、验证规则 |
| 神经网络 | Neural Networks | 多层感知器(MLP)、径向基函数(RBF) |
| 精确检验 | Exact Tests | Fisher 精确检验、小样本精确推断 |
| Amos | Amos | 结构方程模型(SEM)（独立产品） |
| 贝叶斯统计 | Bayesian Statistics | v26+ 内置贝叶斯推断（Base 内） |
| 元分析 | Meta Analysis | v29+ 新增 |
| 效应量 | Effect Sizes | v29+ 新增 |
| 功效分析 | Power Analysis | v27+ 新增 |
| 质量控制 | Quality Control | 控制图、Pareto 图 |
| 空间时序建模 | Spatial and Temporal Modeling | 空间关联规则、时空预测 |

---

## 二、统计分析方法（Analyze 菜单全覆盖）

### 2.1 Reports（报告）

**所属模块：** Base

#### 2.1.1 Codebook（代码簿）

| 项目 | 内容 |
|------|------|
| **中文名** | 代码簿 |
| **适用变量** | 所有类型（名义/有序/连续/字符串） |
| **核心输出** | 变量名、标签、测量水平、缺失值定义、值标签、频率/统计摘要 |
| **关键假设** | 无（描述性） |
| **R 等价** | `codebook()`（`memisc` 包）；`describe()`（`Hmisc`） |
| **Python 等价** | `df.describe()`；`pandas_profiling.ProfileReport()` |
| **问卷场景** | 项目开始前核查变量元数据完整性 |

#### 2.1.2 OLAP Cubes（OLAP 立方体）

| 项目 | 内容 |
|------|------|
| **中文名** | OLAP 立方体 |
| **适用变量** | 汇总变量（连续）× 分类变量（名义/有序） |
| **核心输出** | 分组均值、总和、标准差、计数等多维汇总统计 |
| **R 等价** | `aggregate()`；`dplyr::group_by() + summarise()` |
| **Python 等价** | `df.groupby().agg()`；`pd.pivot_table()` |
| **问卷场景** | 多维度（地区×年龄×性别）的满意度均值汇总 |

#### 2.1.3 Case Summaries（个案摘要）

| 项目 | 内容 |
|------|------|
| **中文名** | 个案摘要 |
| **适用变量** | 所有类型 |
| **核心输出** | 按分组变量列出各个案变量值，附统计摘要 |
| **R 等价** | `head()`；`dplyr::slice()` |
| **Python 等价** | `df.head()`；`df.to_string()` |

#### 2.1.4 Report Summaries in Rows（行式摘要报告）

| 项目 | 内容 |
|------|------|
| **中文名** | 行式摘要报告 |
| **核心输出** | 分组行形式显示统计摘要（计数、均值、总和、百分比） |
| **R 等价** | `knitr::kable()` + `dplyr` |

#### 2.1.5 Report Summaries in Columns（列式摘要报告）

| 项目 | 内容 |
|------|------|
| **中文名** | 列式摘要报告 |
| **核心输出** | 分组列形式显示统计摘要 |

---

### 2.2 Descriptive Statistics（描述性统计）

**所属模块：** Base

#### 2.2.1 Frequencies（频率）

| 项目 | 内容 |
|------|------|
| **中文名** | 频率 |
| **适用变量** | 名义、有序、连续 |
| **核心输出** | 频率表（频数/百分比/有效百分比/累积百分比）、均值、中位数、众数、标准差、偏度、峰度、分位数；可输出直方图、条形图 |
| **关键假设** | 无 |
| **R 等价** | `table()`；`freq()`（`summarytools`）；`describe()`（`psych`） |
| **Python 等价** | `df.value_counts(normalize=True)`；`scipy.stats.describe()` |
| **问卷场景** | 李克特量表各选项频率分布、人口学变量分布 |

#### 2.2.2 Descriptives（描述统计）

| 项目 | 内容 |
|------|------|
| **中文名** | 描述统计 |
| **适用变量** | 连续（等距/比率） |
| **核心输出** | N、均值、最小值、最大值、极差、标准差、方差、偏度（及其标准误）、峰度（及其标准误）、Z 分数（可保存） |
| **R 等价** | `describe()`（`psych`）；`summary()` |
| **Python 等价** | `df.describe()`；`scipy.stats.describe()` |
| **问卷场景** | 对各量表总分/维度分进行正态性初步判断 |

#### 2.2.3 Explore（探索）

| 项目 | 内容 |
|------|------|
| **中文名** | 探索 |
| **适用变量** | 连续；可按分组变量 |
| **核心输出** | 描述统计（含 5% 截尾均值、中位数、方差、标准差、IQR、偏度、峰度）、茎叶图、箱线图、正态性检验（Kolmogorov-Smirnov 含 Lilliefors 校正、Shapiro-Wilk）、Q-Q 图、方差齐性检验（Levene、Brown-Forsythe） |
| **关键假设** | 用于检验分析前提 |
| **R 等价** | `shapiro.test()`；`ks.test()`；`leveneTest()`（`car`）；`boxplot()` |
| **Python 等价** | `scipy.stats.shapiro()`；`scipy.stats.normaltest()`；`scipy.stats.levene()` |
| **问卷场景** | t 检验/ANOVA 前提检验：正态性与方差齐性 |

#### 2.2.4 Crosstabs（交叉表）

| 项目 | 内容 |
|------|------|
| **中文名** | 交叉表 |
| **适用变量** | 名义、有序 |
| **核心输出** | 双向/三向交叉频率表；卡方检验（Pearson、似然比、线性-线性关联）；关联度量（Phi、V、C、Lambda、Tau-b/c、Gamma、Somers' d、Eta）；风险比、比值比（2×2 表） |
| **关键假设** | 独立观测；期望频数 ≥5（通常要求 80% 单元格） |
| **R 等价** | `chisq.test()`；`CrossTable()`（`gmodels`）；`assocstats()`（`vcd`） |
| **Python 等价** | `scipy.stats.chi2_contingency()`；`statsmodels.stats.contingency_tables` |
| **问卷场景** | 性别×满意度等级的关联分析；人口学交叉分析 |

#### 2.2.5 TURF Analysis（TURF 分析）

| 项目 | 内容 |
|------|------|
| **中文名** | TURF（Total Unduplicated Reach and Frequency）分析 |
| **适用变量** | 二分变量（多重响应） |
| **核心输出** | 在给定产品/渠道组合数量限制下，最大化覆盖人群的最优组合 |
| **R 等价** | `turf()`（`turfR`）；自定义 |
| **问卷场景** | 市场研究：哪几款产品组合能覆盖最多消费者 |

#### 2.2.6 Ratio Statistics（比例统计）

| 项目 | 内容 |
|------|------|
| **中文名** | 比例统计 |
| **适用变量** | 两个连续变量（分子/分母） |
| **核心输出** | 比例中位数、平均绝对误差（MAD）、变异系数（COV）、价格相关差异（PRD）、均值比值、中位数比值 |
| **问卷场景** | 房产估价/税收评估研究中 |

#### 2.2.7 P-P Plots（概率-概率图）

| 项目 | 内容 |
|------|------|
| **中文名** | P-P 图 |
| **适用变量** | 连续 |
| **核心输出** | 将实际累积概率对比理论分布（正态/均匀/泊松等）的累积概率绘图 |
| **R 等价** | `plot()`（基础 `ppoints()`）；`ggplot2` 自定义 |
| **Python 等价** | `statsmodels.graphics.gofplots.ProbPlot()` |

#### 2.2.8 Q-Q Plots（分位数-分位数图）

| 项目 | 内容 |
|------|------|
| **中文名** | Q-Q 图 |
| **适用变量** | 连续 |
| **核心输出** | 实际分位数对比理论分位数（通常为正态分布）；附回归线 |
| **R 等价** | `qqnorm()`；`qqline()`；`ggplot2::stat_qq()` + `stat_qq_line()` |
| **Python 等价** | `scipy.stats.probplot()`；`statsmodels.graphics.gofplots.qqplot()` |

---

### 2.3 Bayesian Statistics（贝叶斯统计）

**所属模块：** Base（v26+）  
**参考文档：** https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-bayesian-statistics

贝叶斯统计基于贝叶斯定理，利用先验分布 + 数据似然函数 → 后验分布进行推断，输出包括 **贝叶斯因子（Bayes Factor, BF₁₀）**、后验均值、可信区间（Credible Interval）。

#### 2.3.1 Bayesian One Sample T Test（贝叶斯单样本 t 检验）

| 项目 | 内容 |
|------|------|
| **适用变量** | 连续 |
| **核心输出** | BF₁₀、后验分布、后验均值、95% 可信区间 |
| **先验** | Jeffreys-Zellner-Siow (JZS) Cauchy 先验 |
| **R 等价** | `ttestBF()`（`BayesFactor`）；`bayes_t_test()`（`BayesianFirstAid`） |
| **Python 等价** | `pymc`；`pingouin.bayesfactor_ttest()` |

#### 2.3.2 Bayesian Independent Samples T Test（贝叶斯独立样本 t 检验）

| 项目 | 内容 |
|------|------|
| **核心输出** | BF₁₀、各组后验均值与效应量 δ 的后验分布 |
| **R 等价** | `ttestBF(formula=…, data=…)`（`BayesFactor`） |

#### 2.3.3 Bayesian Paired Samples T Test（贝叶斯配对样本 t 检验）

| 项目 | 内容 |
|------|------|
| **核心输出** | BF₁₀、差值后验分布 |
| **R 等价** | `ttestBF(x, y, paired=TRUE)`（`BayesFactor`） |

#### 2.3.4 Bayesian One-Way ANOVA

| 项目 | 内容 |
|------|------|
| **核心输出** | BF₁₀（完整模型 vs 零模型）、各因子贡献的 BF |
| **R 等价** | `anovaBF()`（`BayesFactor`） |

#### 2.3.5 Bayesian Pearson Correlation（贝叶斯 Pearson 相关）

| 项目 | 内容 |
|------|------|
| **核心输出** | BF₁₀、ρ 的后验分布（Beta 先验） |
| **R 等价** | `correlationBF()`（`BayesFactor`） |

#### 2.3.6 Bayesian Linear Regression（贝叶斯线性回归）

| 项目 | 内容 |
|------|------|
| **核心输出** | 模型 BF、各预测变量的后验包含概率、后验系数分布 |
| **R 等价** | `regressionBF()`（`BayesFactor`）；`BAS::bas.lm()` |

#### 2.3.7 Bayesian One Sample Binomial Test（贝叶斯单样本二项检验）

| 项目 | 内容 |
|------|------|
| **核心输出** | BF₁₀、θ 后验分布（Beta 先验） |
| **R 等价** | `proportionBF()`（`BayesFactor`） |

#### 2.3.8 Bayesian Related Samples Poisson Rate Ratio（贝叶斯相关样本泊松率比）

#### 2.3.9 Bayesian Log-linear Models（贝叶斯对数线性模型）

#### 2.3.10 Bayesian Nonparametric Tests（贝叶斯非参数检验）*待确认 v30 具体子项*

---

### 2.4 Tables（表格）

**所属模块：** Custom Tables

#### 2.4.1 Custom Tables（自定义表格）

| 项目 | 内容 |
|------|------|
| **中文名** | 自定义表格 |
| **适用变量** | 所有类型 |
| **核心输出** | 专业级交叉分析表；行/列嵌套；汇总统计（均值、中位数、计数、百分比、标准差等）；显著性检验标注（列比例/列均值检验）；总计/小计 |
| **R 等价** | `gt` + `dplyr`；`flextable`；`gtsummary` |
| **Python 等价** | `pandas.crosstab()`；`great_tables` |
| **问卷场景** | 市场研究横幅表（Banner Table）；学术论文中的描述统计汇总表 |

#### 2.4.2 Multiple Response Sets（多重响应集）

| 项目 | 内容 |
|------|------|
| **中文名** | 多重响应集 |
| **适用变量** | 多选题（多重二分/多重类别） |
| **核心输出** | 多重响应频率表、多重响应交叉表 |
| **R 等价** | `MultipleResponse` 相关函数；`survey` 包 |
| **问卷场景** | 多选题（"您使用过以下哪些品牌？"）的频率统计 |

---

### 2.5 Compare Means and Proportions（均值与比例比较）

**所属模块：** Base

#### 2.5.1 Means（均值）

| 项目 | 内容 |
|------|------|
| **中文名** | 均值 |
| **适用变量** | 连续因变量 × 分类自变量 |
| **核心输出** | 按分组的均值、标准差、计数；可选 ANOVA、线性相关措施（Eta）、R² |

#### 2.5.2 One-Sample T Test（单样本 t 检验）

| 项目 | 内容 |
|------|------|
| **中文名** | 单样本 t 检验 |
| **适用变量** | 连续 |
| **核心输出** | t 统计量、df、双尾 p 值、均值差、95% CI（差值）、Cohen's d（v29+） |
| **关键假设** | 总体近似正态（大样本可放宽）；独立观测 |
| **R 等价** | `t.test(x, mu=…)` |
| **Python 等价** | `scipy.stats.ttest_1samp()` |
| **问卷场景** | 检验某态度量表均分是否显著不同于中性值 3 |

#### 2.5.3 Independent-Samples T Test（独立样本 t 检验）

| 项目 | 内容 |
|------|------|
| **中文名** | 独立样本 t 检验 |
| **适用变量** | 连续因变量；二分组变量 |
| **核心输出** | Levene 方差齐性检验；等方差/不等方差 t 值、df、p 值；均值差及 95% CI；Cohen's d；效应量 |
| **关键假设** | 两组独立；各组内正态；方差齐性（或 Welch 校正） |
| **R 等价** | `t.test(formula, var.equal=TRUE/FALSE)` |
| **Python 等价** | `scipy.stats.ttest_ind()`；`pingouin.ttest()` |
| **问卷场景** | 比较男女在满意度量表上的差异 |

> **Summary Independent-Samples T Test**（v29+）：输入组摘要统计数据（而非原始数据）进行检验。

#### 2.5.4 Paired-Samples T Test（配对样本 t 检验）

| 项目 | 内容 |
|------|------|
| **中文名** | 配对样本 t 检验 |
| **适用变量** | 两个连续变量（前后测/配对数据） |
| **核心输出** | 差值描述统计、t 值、df、p 值、差值 95% CI；Cohen's d |
| **关键假设** | 差值正态；观测对内独立 |
| **R 等价** | `t.test(x, y, paired=TRUE)` |
| **Python 等价** | `scipy.stats.ttest_rel()` |
| **问卷场景** | 干预前后满意度对比 |

#### 2.5.5 One-Way ANOVA（单因素方差分析）

| 项目 | 内容 |
|------|------|
| **中文名** | 单因素方差分析 |
| **适用变量** | 连续因变量；多分类自变量（≥2组） |
| **核心输出** | F 值、df、p 值；事后检验（Tukey HSD、Scheffe、Bonferroni、LSD、Duncan、Games-Howell、Tamhane's T2、Dunnett 等）；均值图；Levene 检验；Welch、Brown-Forsythe 统计量（不等方差） |
| **关键假设** | 各组独立正态；方差齐性（或使用 Welch） |
| **R 等价** | `aov()`；`oneway.test()`；`TukeyHSD()`；`emmeans()` |
| **Python 等价** | `scipy.stats.f_oneway()`；`statsmodels.formula.api.ols()` + `anova_lm()` |
| **问卷场景** | 比较三个及以上城市用户满意度差异 |

#### 2.5.6 One-Sample Proportions（单样本比例检验）

| 项目 | 内容 |
|------|------|
| **适用变量** | 二分变量 |
| **核心输出** | z 检验（正态近似）/ 精确二项检验；比例 95% CI（Wald、Clopper-Pearson 精确） |
| **R 等价** | `prop.test()`；`binom.test()` |
| **Python 等价** | `scipy.stats.binom_test()`；`statsmodels.stats.proportion.proportions_ztest()` |

#### 2.5.7 Independent-Samples Proportions（独立样本比例检验）

| 项目 | 内容 |
|------|------|
| **核心输出** | z 检验；比例差值 CI；相对风险、OR（可选） |
| **R 等价** | `prop.test()`；`riskratio()`（`epitools`） |

#### 2.5.8 Paired-Samples Proportions（配对样本比例检验）

| 项目 | 内容 |
|------|------|
| **核心输出** | McNemar 检验；二项精确检验 |
| **R 等价** | `mcnemar.test()` |
| **Python 等价** | `statsmodels.stats.contingency_tables.mcnemar()` |

---

### 2.6 General Linear Model（一般线性模型）

**所属模块：** Advanced Statistics

#### 2.6.1 Univariate GLM（单变量 GLM）

| 项目 | 内容 |
|------|------|
| **中文名** | 单变量一般线性模型（UNIANOVA） |
| **适用变量** | 一个连续因变量；固定/随机因子；协变量（ANCOVA） |
| **核心输出** | III 型 SS、F、p、η²、ω²；简单效应；简单斜率；Profile 图；事后检验；估计边际均值（EMMs）；对比；同质子集 |
| **关键假设** | 残差正态；方差齐性；独立观测 |
| **R 等价** | `lm()`；`aov()`；`Anova()`（`car`）；`emmeans()` |
| **Python 等价** | `statsmodels.formula.api.ols()` + `anova_lm()` |
| **问卷场景** | 控制人口学变量后检验培训对工作满意度的影响（ANCOVA） |

#### 2.6.2 Multivariate GLM（多变量 GLM，MANOVA）

| 项目 | 内容 |
|------|------|
| **中文名** | 多变量一般线性模型（MANOVA） |
| **适用变量** | 多个连续因变量 |
| **核心输出** | Pillai's Trace、Wilks' Lambda、Hotelling's Trace、Roy's Largest Root；单变量 F 检验（含 Bonferroni 校正）；判别分析 |
| **关键假设** | 多元正态；Box's M 协方差矩阵齐性 |
| **R 等价** | `manova()`；`car::Manova()` |
| **Python 等价** | `statsmodels.multivariate.manova.MANOVA()` |

#### 2.6.3 Repeated Measures（重复测量）

| 项目 | 内容 |
|------|------|
| **中文名** | 重复测量方差分析 |
| **适用变量** | 同一被试的多次测量（时间/条件） |
| **核心输出** | Mauchly 球形性检验；Greenhouse-Geisser/Huynh-Feldt/Lower-bound 校正；被试内/被试间效应检验；多元检验；Profile 图 |
| **关键假设** | 球形性（或使用校正）；多元正态 |
| **R 等价** | `aov()` + `Error()`；`ez::ezANOVA()`；`afex::aov_ez()` |
| **Python 等价** | `pingouin.rm_anova()`；`statsmodels` 混合模型 |
| **问卷场景** | 4次时间点追踪量表均分的变化趋势 |

#### 2.6.4 Variance Components（方差成分）

| 项目 | 内容 |
|------|------|
| **中文名** | 方差成分分析 |
| **核心输出** | 随机效应方差成分（MINQUE、ANOVA法、ML、REML） |
| **R 等价** | `VarCorr()`（`lme4`）；`VCA()` |

---

### 2.7 Generalized Linear Models（广义线性模型）

**所属模块：** Advanced Statistics

#### 2.7.1 GZLM（广义线性模型）

| 项目 | 内容 |
|------|------|
| **支持分布族** | 正态、二项（Logit/Probit/CLogLog/Log链接）、泊松（Log链接）、负二项、Gamma、逆高斯、Tweedie、有序多项 |
| **核心输出** | 参数估计（Wald 检验）、95% CI、指数化系数（OR/RR）、Omnibus 检验（似然比）、拟合优度（Pearson/Deviance）、AIC/BIC、预测值 |
| **R 等价** | `glm()`；`MASS::glm.nb()`；`ordinal::clm()` |
| **Python 等价** | `statsmodels.formula.api.glm()` |

#### 2.7.2 GEE（广义估计方程）

| 项目 | 内容 |
|------|------|
| **中文名** | 广义估计方程（Generalized Estimating Equations） |
| **适用场景** | 纵向/重复测量数据；聚类数据（学校/医院） |
| **核心输出** | 总体平均效应（Population-averaged）参数估计；Robust 协方差矩阵；QIC 模型选择标准；相关结构（独立/交换/AR1/非结构化） |
| **R 等价** | `gee()`（`gee`）；`geeglm()`（`geepack`） |
| **Python 等价** | `statsmodels.genmod.generalized_estimating_equations.GEE()` |
| **问卷场景** | 同一班级多名学生（聚类效应）的满意度多分类因变量建模 |

---

### 2.8 Mixed Models（混合模型）

**所属模块：** Advanced Statistics

#### 2.8.1 Linear Mixed Models（线性混合模型）

| 项目 | 内容 |
|------|------|
| **中文名** | 线性混合模型（LMM/HLM） |
| **适用场景** | 嵌套结构（学生-班级-学校）；重复测量；缺失数据（REML） |
| **核心输出** | 固定效应（F 检验、t 检验）、随机效应方差成分（VarCorr）、协方差结构（UN/CS/AR1/Toeplitz 等）、-2LL、AIC、BIC |
| **R 等价** | `lmer()`（`lme4`）；`lme()`（`nlme`）；`nlme::lme()` |
| **Python 等价** | `statsmodels.regression.mixed_linear_model.MixedLM()` |
| **问卷场景** | 多层次问卷：学生嵌套于班级嵌套于学校的满意度分析 |

#### 2.8.2 Generalized Linear Mixed Models（广义线性混合模型）

| 项目 | 内容 |
|------|------|
| **适用场景** | 嵌套/纵向的非正态因变量（二分、计数、有序） |
| **R 等价** | `glmer()`（`lme4`）；`glmmTMB()` |
| **Python 等价** | `statsmodels` GLMM（有限支持）；`pymer4` |

---

### 2.9 Correlate（相关）

**所属模块：** Base

#### 2.9.1 Bivariate Correlations（双变量相关）

| 项目 | 内容 |
|------|------|
| **中文名** | 双变量相关 |
| **输出统计** | Pearson r（连续-连续）；Spearman ρ（有序/非正态）；Kendall τ-b（有序）；p 值；N；95% CI（Bootstrap 可选） |
| **R 等价** | `cor()`；`cor.test()`；`rcorr()`（`Hmisc`） |
| **Python 等价** | `scipy.stats.pearsonr()`；`scipy.stats.spearmanr()`；`scipy.stats.kendalltau()` |
| **问卷场景** | 量表间相关矩阵；探索性变量关系 |

#### 2.9.2 Partial Correlations（偏相关）

| 项目 | 内容 |
|------|------|
| **中文名** | 偏相关 |
| **输出** | 控制协变量后的偏相关系数、显著性 |
| **R 等价** | `pcor()`（`ppcor`）；`pcor.test()` |
| **Python 等价** | `pingouin.partial_corr()` |

#### 2.9.3 Distances（距离）

| 项目 | 内容 |
|------|------|
| **中文名** | 距离 |
| **输出** | 个案间/变量间相似性或差异性矩阵（Euclidean、Manhattan、Minkowski、Cosine、Jaccard、Dice 等） |
| **R 等价** | `dist()`；`proxy::dist()` |
| **Python 等价** | `scipy.spatial.distance.cdist()` |
| **问卷场景** | 聚类分析前的距离矩阵计算 |

#### 2.9.4 Canonical Correlation（典型相关）

| 项目 | 内容 |
|------|------|
| **中文名** | 典型相关分析 |
| **适用变量** | 两组连续变量集 |
| **输出** | 典型相关系数（Rc）、Wilks' Lambda、典型函数系数、结构相关 |
| **注意** | SPSS Base 通过宏 CANCORR 实现（Syntax only） |
| **R 等价** | `cancor()`；`CCA::cc()` |
| **Python 等价** | `sklearn.cross_decomposition.CCA()` |

---

### 2.10 Regression（回归）

**所属模块：** Base + Regression（高级模块）

#### 2.10.1 Automatic Linear Modeling（自动线性建模）

| 项目 | 内容 |
|------|------|
| **中文名** | 自动线性建模 |
| **核心输出** | 自动特征工程（BOX-COX 变换、分类变量编码）、变量重要性排序、最优模型选择 |
| **R 等价** | `caret` autoML；`mlr3` |
| **Python 等价** | `sklearn.pipeline`；`auto-sklearn` |

#### 2.10.2 Linear Regression（线性回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 线性回归 |
| **方法** | Enter、Stepwise、Forward、Backward、Remove |
| **核心输出** | R²、调整 R²、F 检验、SE of Estimate；系数 B、SE、β、t、p；共线性诊断（VIF、容差、条件指标）；残差图（散点图、直方图、P-P图）；DW 统计量；DFBETA、DFFITS、Cook's D、杠杆值 |
| **关键假设** | 线性、独立、等方差（同方差性）、残差正态、无完全共线性 |
| **R 等价** | `lm()`；`summary()`；`vif()`（`car`） |
| **Python 等价** | `statsmodels.formula.api.ols()`；`sklearn.linear_model.LinearRegression()` |
| **问卷场景** | 预测整体满意度（因变量）由各维度评分（自变量）解释的方差 |

#### 2.10.3 Curve Estimation（曲线估计）

| 项目 | 内容 |
|------|------|
| **中文名** | 曲线估计 |
| **模型** | 线性、对数、倒数、二次、三次、幂函数、复合、S形、逻辑、增长、指数 |
| **R 等价** | `nls()`；`lm()` 加多项式项 |

#### 2.10.4 Partial Least Squares（偏最小二乘回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 偏最小二乘回归（PLS） |
| **适用场景** | 预测变量多且共线性严重（如光谱数据、心理量表） |
| **核心输出** | PLS 因子数、X/Y 因子得分、内积关联、R²X、R²Y |
| **R 等价** | `plsr()`（`pls`）；`caret` + `pls` |
| **Python 等价** | `sklearn.cross_decomposition.PLSRegression()` |

#### 2.10.5 Binary Logistic Regression（二元逻辑回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 二元逻辑回归 |
| **因变量** | 二分类（0/1） |
| **核心输出** | -2LL、Cox-Snell R²、Nagelkerke R²；Hosmer-Lemeshow 检验；系数 B、SE、Wald χ²、p、Exp(B)（OR）及 95% CI；分类表（灵敏度/特异度）；ROC 曲线（可选） |
| **关键假设** | 独立观测；线性（逻辑尺度）；无完全分离 |
| **R 等价** | `glm(family=binomial)`；`lrm()`（`rms`） |
| **Python 等价** | `statsmodels.formula.api.logit()`；`sklearn.linear_model.LogisticRegression()` |
| **问卷场景** | 预测客户是否流失（二分因变量）由多个态度变量预测 |

#### 2.10.6 Multinomial Logistic Regression（多项逻辑回归）

| 项目 | 内容 |
|------|------|
| **因变量** | 名义多分类（≥3类） |
| **核心输出** | 以参考类别为基准的 OR、SE、p；Wald 检验；似然比检验；分类表 |
| **R 等价** | `multinom()`（`nnet`）；`mlogit()` |
| **Python 等价** | `sklearn.linear_model.LogisticRegression(multi_class='multinomial')`；`statsmodels.discrete.discrete_model.MNLogit()` |

#### 2.10.7 Ordinal Regression（有序回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 有序回归（PLUM） |
| **因变量** | 有序多分类 |
| **链接函数** | Logit、Probit、CLogLog、NegLog-Log、Cauchit |
| **核心输出** | 阈值参数、位置参数、平行线检验（PH 假设检验） |
| **R 等价** | `polr()`（`MASS`）；`clm()`（`ordinal`） |
| **Python 等价** | `statsmodels.miscmodels.ordinal_model.OrderedModel()` |
| **问卷场景** | 李克特5级量表作为因变量的有序回归 |

#### 2.10.8 Probit Analysis（Probit 分析）

| 项目 | 内容 |
|------|------|
| **中文名** | Probit 分析 |
| **适用场景** | 剂量-反应研究；LD50/EC50 估计 |
| **R 等价** | `glm(family=binomial(link='probit'))`；`dose.p()`（`MASS`） |

#### 2.10.9 Nonlinear Regression（非线性回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 非线性回归 |
| **方法** | 高斯-牛顿法、Levenberg-Marquardt 法 |
| **R 等价** | `nls()`；`nlsLM()`（`minpack.lm`） |
| **Python 等价** | `scipy.optimize.curve_fit()` |

#### 2.10.10 Weight Estimation（加权估计）

| 项目 | 内容 |
|------|------|
| **适用场景** | 加权最小二乘（WLS）；异方差修正 |
| **R 等价** | `lm(weights=…)` |

#### 2.10.11 Two-Stage Least Squares（二阶段最小二乘）

| 项目 | 内容 |
|------|------|
| **中文名** | 二阶段最小二乘（2SLS/IV 估计） |
| **适用场景** | 内生性问题；工具变量回归 |
| **R 等价** | `ivreg()`（`AER`/`ivreg`） |
| **Python 等价** | `linearmodels.iv.model.IV2SLS()` |

#### 2.10.12 4-PL / 5-PL Quantile Regression（四/五参数逻辑 & 分位数回归）*待确认 v29 具体实现*

#### 2.10.13 Optimal Scaling — CATREG（类别回归）

| 项目 | 内容 |
|------|------|
| **中文名** | 最优标度回归（CATREG） |
| **适用变量** | 名义/有序/数值协变量混合 |
| **核心输出** | 最优标度（变换）后的回归系数、R²、重要性（β） |
| **R 等价** | `catreg()`（`aspect` 包，有限）；手动虚拟编码 + `lm()` |

---

### 2.11 Loglinear（对数线性模型）

**所属模块：** Advanced Statistics

#### 2.11.1 General Loglinear Analysis（一般对数线性分析）

| 项目 | 内容 |
|------|------|
| **适用变量** | 多个类别变量（三向及以上交叉表） |
| **核心输出** | 各主效应及交互效应的参数估计、z/χ²检验；拟合优度（Pearson χ²、Deviance）；期望频数 |
| **R 等价** | `loglin()`；`loglm()`（`MASS`）；`glm(family=poisson)` |

#### 2.11.2 Logit Loglinear Analysis（Logit 对数线性分析）

| 项目 | 内容 |
|------|------|
| **适用场景** | 类别因变量 + 多个类别预测变量 |
| **R 等价** | `glm(family=binomial)` + 交互项 |

#### 2.11.3 Model Selection Loglinear Analysis（模型选择对数线性分析）

| 项目 | 内容 |
|------|------|
| **功能** | 自动前向/后向逐步选择最优对数线性模型 |
| **核心输出** | Backward elimination 过程、部分关联表 |

---

### 2.12 Neural Networks（神经网络）

**所属模块：** Neural Networks

#### 2.12.1 Multilayer Perceptron（多层感知器，MLP）

| 项目 | 内容 |
|------|------|
| **中文名** | 多层感知器 |
| **适用场景** | 回归/多分类；连续/类别因变量 |
| **结构** | 1或2个隐含层；激活函数（Sigmoid/Hyperbolic Tangent/Identity/Softmax） |
| **核心输出** | 模型摘要（误差函数值）、预测准确率/误差；变量重要性归一化；分类/预测结果保存 |
| **R 等价** | `nnet::nnet()`；`neuralnet::neuralnet()` |
| **Python 等价** | `sklearn.neural_network.MLPClassifier/MLPRegressor()` |

#### 2.12.2 Radial Basis Function（径向基函数，RBF）

| 项目 | 内容 |
|------|------|
| **结构** | 隐含层使用 RBF 核函数（Softmax 激活） |
| **R 等价** | `kernlab::rbfdot()` |
| **Python 等价** | `sklearn.svm.SVC(kernel='rbf')`（近似）；专用 RBF 网络实现 |

---

### 2.13 Classify（分类）

**所属模块：** Base + Decision Trees（树方法）

#### 2.13.1 TwoStep Cluster（两步聚类）

| 项目 | 内容 |
|------|------|
| **中文名** | 两步聚类 |
| **适用变量** | 混合变量（连续 + 类别） |
| **核心输出** | 自动确定最优簇数（BIC/AIC）；簇质量轮廓（Silhouette）；簇大小图；各变量在各簇中的分布 |
| **R 等价** | `mclust::Mclust()`；`cluster::pam()` |
| **Python 等价** | `sklearn.mixture.GaussianMixture()` |
| **问卷场景** | 消费者细分（混合人口学和态度变量） |

#### 2.13.2 K-Means Cluster（K均值聚类）

| 项目 | 内容 |
|------|------|
| **适用变量** | 连续 |
| **核心输出** | 指定 K 个簇的簇中心、ANOVA 表、距离、迭代过程 |
| **R 等价** | `kmeans()`；`factoextra::fviz_cluster()` |
| **Python 等价** | `sklearn.cluster.KMeans()` |

#### 2.13.3 Hierarchical Cluster（系统聚类）

| 项目 | 内容 |
|------|------|
| **连接方法** | Ward's、Complete、Average (UPGMA)、Single、Centroid、Median、McQuitty |
| **核心输出** | 树状图（Dendrogram）；冰柱图；聚合系数表 |
| **R 等价** | `hclust()`；`factoextra::fviz_dend()` |
| **Python 等价** | `scipy.cluster.hierarchy.linkage()`；`sklearn.cluster.AgglomerativeClustering()` |

#### 2.13.4 Cluster Silhouettes（簇轮廓分析）

| 项目 | 内容 |
|------|------|
| **功能** | 评估聚类质量；每个观测点的轮廓系数（s(i) = -1 到 1） |
| **R 等价** | `cluster::silhouette()`；`factoextra::fviz_silhouette()` |

#### 2.13.5 Decision Tree（决策树）

**所属模块：** Decision Trees

| 算法 | 全称 | 特征 |
|------|------|------|
| **CHAID** | Chi-squared Automatic Interaction Detection | 多叉树；卡方/F检验分裂；类别/连续因变量 |
| **Exhaustive CHAID** | 穷举 CHAID | 对所有可能合并进行检验后再分裂 |
| **CRT** | Classification and Regression Trees | 二叉树；Gini/Twoing（分类）/最小方差（回归） |
| **QUEST** | Quick, Unbiased, Efficient Statistical Tree | 二叉树；对自变量数量无偏；快速 |

**核心输出：** 树图形（节点含统计信息）、分类准确率/误差、变量重要性、增益/索引/升降曲线、替代分裂、风险估计、混淆矩阵。

| R 等价 | `rpart()`（CRT）；`party::ctree()`；`chaid()`（`CHAID`） |
|--------|------|
| Python 等价 | `sklearn.tree.DecisionTreeClassifier/Regressor()` |

#### 2.13.6 Discriminant Analysis（判别分析）

| 项目 | 内容 |
|------|------|
| **中文名** | 判别分析（线性/逐步判别） |
| **核心输出** | 判别函数系数（标准化/非标准化）、特征值、典型相关、Wilks' Lambda、组分类函数系数、混淆矩阵、留一法分类 |
| **R 等价** | `lda()`（`MASS`）；`qda()` |
| **Python 等价** | `sklearn.discriminant_analysis.LinearDiscriminantAnalysis()` |

#### 2.13.7 Nearest Neighbor（最近邻分类）

| 项目 | 内容 |
|------|------|
| **中文名** | K 最近邻（KNN） |
| **核心输出** | 分类精度；最优 K 选择（交叉验证）；误差图 |
| **R 等价** | `class::knn()`；`caret` + `knn` |
| **Python 等价** | `sklearn.neighbors.KNeighborsClassifier()` |

#### 2.13.8 ROC Curve（ROC 曲线）

| 项目 | 内容 |
|------|------|
| **核心输出** | ROC 曲线图；AUC（C统计量）及其95% CI；坐标点列表（敏感度/1-特异度） |
| **R 等价** | `pROC::roc()`；`ROCR::performance()` |
| **Python 等价** | `sklearn.metrics.roc_curve()`；`sklearn.metrics.roc_auc_score()` |

#### 2.13.9 ROC Analysis（ROC 分析，v29+）

| 项目 | 内容 |
|------|------|
| **新增功能** | 多条 ROC 曲线比较；DeLong 检验（曲线比较）；最优截点确定（Youden指数）；部分AUC |
| **R 等价** | `pROC::roc.test(method='delong')` |

---

### 2.14 Dimension Reduction（降维）

**所属模块：** Base（FA）；Categories（最优标度方法）

#### 2.14.1 Factor Analysis（因子分析）

| 项目 | 内容 |
|------|------|
| **中文名** | 因子分析（EFA） |
| **提取方法** | 主成分（PCA）、主轴因子（PAF）、最小残差（Minres）、广义最小二乘（GLS）、极大似然（ML）、Alpha、Image |
| **旋转方法** | 正交：Varimax、Equamax、Quartimax、Parsimax；斜交：Oblimin、Promax |
| **核心输出** | 碎石图（Scree Plot）、特征值 >1 准则（Kaiser）、因子负荷矩阵、公因子方差（Communality）、旋转后负荷、因子得分（回归/Bartlett/Anderson-Rubin）；KMO 抽样充足度；Bartlett 球形检验 |
| **R 等价** | `fa()`（`psych`）；`factanal()`；`principal()`（`psych`） |
| **Python 等价** | `sklearn.decomposition.PCA()`；`factor_analyzer.FactorAnalyzer()` |
| **问卷场景** | 量表结构探索与验证；心理测量学研究 |

#### 2.14.2 Correspondence Analysis（对应分析）

| 项目 | 内容 |
|------|------|
| **中文名** | 对应分析（CA） |
| **适用变量** | 两个名义变量（列联表） |
| **核心输出** | 行/列坐标、惯量（Inertia）分解、双标图（Biplot） |
| **R 等价** | `ca()`（`ca`）；`corresp()`（`MASS`）；`factoextra::fviz_ca()` |
| **Python 等价** | `prince.CA()` |
| **问卷场景** | 品牌属性关联图；品牌感知定位图 |

#### 2.14.3 Optimal Scaling（最优标度）

| 方法 | 全称 | 说明 |
|------|------|------|
| **PRINCALS** | Principal Components Analysis by Alternating Least Squares | 名义/有序变量的主成分分析 |
| **OVERALS** | OVERALl Canonical correlation Analysis by Alternating LS | 多组变量的典型相关 |
| **CATPCA** | CATegorical Principal Components Analysis | 混合变量 PCA（等价 PRINCALS 改进版） |

**R 等价：** `aspect()`（`aspect`）；`PCAmixdata::PCAmix()` （Python：`prince.MCA()`）

---

### 2.15 Scale（量表）

**所属模块：** Base + Categories

#### 2.15.1 Reliability Analysis（信度分析）

| 项目 | 内容 |
|------|------|
| **中文名** | 信度分析 |
| **信度方法** | Cronbach's α（Alpha）；Split-half（Guttman、Spearman-Brown）；Parallel、Strict Parallel 模型；Guttman λ₁–λ₆；McDonald's ω*（v29+）；ICC（组内相关系数，适用于评分者间信度） |
| **核心输出** | Alpha 值；若删除该项后的 Alpha；项-总相关（CITC）；项间相关矩阵；方差分量 |
| **关键假设** | 本质 τ 等价（Alpha 要求）；连续或等间距有序数据 |
| **R 等价** | `alpha()`（`psych`）；`omega()`（`psych`）；`ICC()`（`psych`） |
| **Python 等价** | `pingouin.cronbach_alpha()`；`pingouin.intraclass_corr()` |
| **问卷场景** | 量表开发：检验多道题目测同一构念的内部一致性 |

#### 2.15.2 Multidimensional Scaling（多维标度）

| 方法 | 说明 |
|------|------|
| **PROXSCAL** | 近端标度；支持多源不对称矩阵；加权欧氏距离（INDSCAL）；三路数据 |
| **ALSCAL** | 交替最小二乘标度；支持不相似矩阵；多重矩阵（三路）；Kruskal Stress 准则 |

**核心输出：** n 维坐标、Stress 值、R²；知觉图（Perceptual Map）

**R 等价：** `cmdscale()`（经典MDS）；`smacof::mds()`（SMACOF）；`MASS::isoMDS()`

**Python 等价：** `sklearn.manifold.MDS()`；`scipy.spatial.distance` + `sklearn`

**问卷场景：** 消费者对品牌相似性判断的感知图 |

---

### 2.16 Nonparametric Tests（非参数检验）

**所属模块：** Base

#### 新版对话框（v18+）

| 过程 | 说明 |
|------|------|
| **One Sample** | 自动选择：K-S 检验（均匀/正态/泊松分布）；二项检验；游程检验 |
| **Independent Samples** | 自动选择：Mann-Whitney U；K-W 检验；Jonckheere-Terpstra；Moses 极差检验 |
| **Related Samples** | 自动选择：Wilcoxon 有符号秩；Friedman；Kendall's W；McNemar-Bowker；Cochran's Q |

#### 传统（Legacy）对话框（向后兼容）

| 过程 | 英文名 | 统计量 | 变量要求 |
|------|--------|--------|---------|
| 卡方检验 | Chi-Square | χ²、df、p | 名义（单变量频率分布） |
| 二项检验 | Binomial | z/精确 p | 二分变量 |
| 游程检验 | Runs | z、p | 连续/二分 |
| 单样本K-S检验 | 1-Sample K-S | D、p | 连续（与理论分布比较） |
| 两独立样本 | 2 Independent Samples | Mann-Whitney U、Wilcoxon W、z、p | 连续；二分组 |
| K 独立样本 | K Independent Samples | K-W H 统计量；Median 检验 | 连续；多分组 |
| 两相关样本 | 2 Related Samples | Wilcoxon Z；Sign 检验；McNemar χ² | 配对变量 |
| K 相关样本 | K Related Samples | Friedman χ²；Kendall's W；Cochran Q | 多个配对变量 |

**R 等价总表：**
- `wilcox.test()`、`kruskal.test()`、`friedman.test()`
- `binom.test()`、`ks.test()`、`runs.test()`（`randtests`）
- `chisq.test()`、`fisher.test()`

**Python 等价：** `scipy.stats` 中对应函数（`mannwhitneyu`、`kruskal`、`friedmanchisquare`、`wilcoxon`等）

---

### 2.17 Forecasting（预测/时间序列分析）

**所属模块：** Forecasting

#### 2.17.1 Create Models（创建时间序列模型）

| 方法 | 说明 |
|------|------|
| **Expert Modeler（专家建模器）** | 自动识别最优 ARIMA 或指数平滑模型；支持事件/干预变量 |
| **Exponential Smoothing（指数平滑）** | 简单（SES）、Holt 双参数、Holt-Winters 三参数（加法/乘法季节）、阻尼趋势 |
| **ARIMA** | 自定义 p、d、q（季节及非季节）；自动检测季节性；支持 Box-Cox 变换；外源变量（X）→ ARIMAX |

**核心输出：** 模型参数估计、Ljung-Box Q 统计量（残差白噪声检验）、正规化 BIC、R²、MAPE、MAE、RMSE；预测值 + 置信区间；模型图

#### 2.17.2 Apply Models（应用已保存模型）

将已保存的模型参数应用于新数据或更新数据。

#### 2.17.3 Sequence Charts（时序图）

时间序列折线图，支持参考线、分类面板。

#### 2.17.4 Autocorrelations（自相关图）

ACF（自相关函数）、PACF（偏自相关函数）图，用于 ARIMA 模型定阶。

**R 等价：** `acf()`；`pacf()`；`forecast::Acf()`

#### 2.17.5 Cross-Correlations（互相关图）

两个序列的互相关函数（CCF），识别滞后关系。

#### 2.17.6 Spectral Analysis（谱分析）

周期图（Periodogram）、谱密度估计；识别时间序列中的周期成分。

**R 等价：** `spec.pgram()`；`spectrum()`

#### 2.17.7 Seasonal Decomposition（季节分解，X-11 / STL）

加法或乘法模型分解为趋势、季节、残差三成分（Census I 与 Census II）。

**R 等价：** `decompose()`；`stl()`；`seasonal::seas()`（X-13ARIMA-SEATS）

---

### 2.18 Survival Analysis（生存分析）

**所属模块：** Advanced Statistics

#### 2.18.1 Life Tables（生命表）

| 项目 | 内容 |
|------|------|
| **中文名** | 生命表（精算方法） |
| **核心输出** | 区间生存率、累积生存率、风险率（Hazard Rate）、密度函数、生存曲线、组间比较（Wilcoxon/Log-rank/Tarone-Ware） |

#### 2.18.2 Kaplan-Meier（K-M 生存分析）

| 项目 | 内容 |
|------|------|
| **核心输出** | K-M 生存曲线；中位生存时间；组间比较（Log-rank、Breslow、Tarone-Ware 检验）；均值及其 SE |
| **R 等价** | `survfit()`（`survival`）；`ggsurvplot()`（`survminer`） |
| **Python 等价** | `lifelines.KaplanMeierFitter()` |

#### 2.18.3 Cox Regression（Cox 比例风险回归）

| 项目 | 内容 |
|------|------|
| **核心输出** | 风险比（HR）及 95% CI；Wald 检验；似然比检验；Score（Log-rank）检验；-2LL；基线累积危险函数；残差（Martingale/Deviance/Schoenfeld）；分层 Cox |
| **关键假设** | 比例风险（PH）假设（Schoenfeld 残差检验） |
| **R 等价** | `coxph()`（`survival`）；`cox.zph()` |
| **Python 等价** | `lifelines.CoxPHFitter()` |

#### 2.18.4 Cox Regression with Time-Dependent Covariates（含时变协变量的 Cox 回归）

时间相关自变量（随时间变化的协变量，如治疗状态改变）。

---

### 2.19 Multiple Response（多重响应）

**所属模块：** Base

| 过程 | 说明 |
|------|------|
| **Define Sets（定义集）** | 将多选题变量组定义为二分集或类别集 |
| **Frequencies（频率）** | 多重响应频率表 |
| **Crosstabs（交叉表）** | 多重响应与其他变量的交叉表 |

---

### 2.20 Missing Value Analysis（缺失值分析）

**所属模块：** Missing Values

| 过程 | 方法 | 说明 |
|------|------|------|
| **描述统计** | 单变量缺失模式 | 缺失数量、百分比；正态分布、t 检验（有/无缺失差异） |
| **Listwise/Pairwise** | 完全案例/可用对 | - |
| **EM 算法** | 期望最大化 | 多元正态假设下估计均值和协方差矩阵 |
| **回归填补** | 多元回归 | 逐步回归预测缺失值 |
| **随机残差** | 回归 + 随机扰动 | - |

**R 等价：** `mice()`（`mice`）；`Amelia::amelia()`；`norm::em.norm()`

**Python 等价：** `sklearn.impute.SimpleImputer()`；`fancyimpute`；`missingno`

---

### 2.21 Multiple Imputation（多重填补）

**所属模块：** Missing Values

| 过程 | 说明 |
|------|------|
| **Analyze Patterns（分析缺失模式）** | 缺失值模式可视化；变量缺失百分比；单调性检验 |
| **Impute Missing Data Values（创建多重填补数据集）** | 使用 MCMC（Fully Conditional Specification, FCS/链式方程）或 Monotone 方法生成 m 份完整数据集 |

**合并规则：** Rubin's Rules（PROC MIANALYZE 逻辑）

**R 等价：** `mice()`（`mice`）；`mi()`（`mi`）

**Python 等价：** `sklearn.impute.IterativeImputer()`；`fancyimpute.IterativeImputer()`

---

### 2.22 Complex Samples（复杂样本）

**所属模块：** Complex Samples

用于分析来自概率抽样调查（分层、整群、多阶段设计）的数据，提供设计效应（DEFF）校正推断。

| 过程 | 说明 |
|------|------|
| **Plan（设计计划）** | 定义抽样设计（分层变量、PSU、权重、有限总体校正） |
| **Frequencies** | 设计加权频率和比例 |
| **Descriptives** | 设计加权均值、总量、比率 |
| **Crosstabs** | 设计加权交叉表 |
| **Ratios** | 比率估计 |
| **GLM** | 设计加权线性回归 |
| **Logistic Regression** | 设计加权逻辑回归 |
| **Ordinal Regression** | 设计加权有序回归 |
| **Cox Regression** | 设计加权生存分析 |
| **GZLM** | 设计加权广义线性模型 |

**R 等价：** `survey` 包（`svyglm()`、`svyfreq()`、`svytable()`、`svymean()`）

**Python 等价：** `samplics`；`survey` 包 Python 端口

---

### 2.23 Simulation（模拟）

| 项目 | 内容 |
|------|------|
| **功能** | Monte Carlo 模拟；指定输入变量分布（正态、均匀、二项、泊松、三角等）；观察输出结果的分布与稳健性 |
| **R 等价** | `mc2d`；`EnvStats`；手动 `replicate()` |
| **Python 等价** | `numpy.random`；`scipy.stats` 各分布 `.rvs()` |

---

### 2.24 Quality Control（质量控制）

**所属模块：** Base

| 过程 | 说明 |
|------|------|
| **Control Charts — X-bar R** | 均值-极差控制图（适合小批量） |
| **X-bar S** | 均值-标准差控制图（适合大批量） |
| **Individuals MR（I-MR）** | 个值-移动极差控制图 |
| **p 图** | 不合格率控制图 |
| **np 图** | 不合格数控制图 |
| **c 图** | 缺陷数控制图 |
| **u 图** | 单位缺陷率控制图 |
| **Pareto Charts（帕累托图）** | 计数/频率排序条形图+累积折线；识别主要原因（80/20 法则） |

**R 等价：** `qcc()`（`qcc`）；`ggQC()`；`SixSigma`

**Python 等价：** `pyqcc`；`matplotlib` 自定义

---

### 2.25 Spatial and Temporal Modeling（空间与时序建模）*待确认*

| 过程 | 说明 |
|------|------|
| **Spatial Association Rules** | 基于地理位置的关联规则挖掘 |
| **Spatio-Temporal Prediction** | 时空数据预测模型 |
| **Geospatial Modeling Wizard** | 地理空间建模向导（需 SPSS Modeler 或扩展集成） |

---

### 2.26 Direct Marketing（直效营销）

**所属模块：** Direct Marketing

| 过程 | 说明 |
|------|------|
| **RFM Analysis（最近/频率/金额分析）** | 对现有客户基于 RFM 得分分组；识别最优高价值客户 |
| **Cluster Prospects** | 对潜在客户使用两步聚类分群；识别最佳目标群 |
| **Prospect Profiles** | 用响应客户特征为潜在客户建立响应概率模型 |
| **Postal Code Response Rates** | 邮政区划响应率分析；将地理区域从高到低排名 |
| **Control Package Test** | 控制包装与测试包装的对照分析（A/B 测试） |

---

### 2.27 Meta Analysis（元分析，v29 新增）

**所属模块：** Meta Analysis

| 过程 | 效应量输入 | 说明 |
|------|-----------|------|
| **Continuous Outcomes（连续结局）** | 均值差（MD/SMD：Cohen's d、Hedges' g）；相关系数（Fisher's z 变换） | 固定效应（逆方差权重）；随机效应（DerSimonian-Laird、REML、ML）；I²、Q 检验；森林图；漏斗图 |
| **Binary Outcomes（二分结局）** | 比值比（OR）、相对风险（RR）、风险差（RD） | 同上；Mantel-Haenszel 方法 |

**核心输出：** 汇总效应量（95% CI）、异质性检验（Cochran's Q、I²、τ²）、森林图（Forest Plot）、漏斗图（Funnel Plot）、Egger's 检验（发表偏倚）

**R 等价：** `meta()`（`meta`）；`rma()`（`metafor`）；`escalc()`（`metafor`）

**Python 等价：** `pymare`；`metanalysis`

---

### 2.28 Power Analysis（功效分析，v27+ 新增）

**所属模块：** Power Analysis

| 检验类型 | 说明 |
|---------|------|
| 单样本 t 检验功效 | 给定 α、δ、σ → 计算 n 或功效 |
| 独立样本 t 检验功效 | 两组；等/不等样本量 |
| 配对样本 t 检验功效 | - |
| 单因素 ANOVA 功效 | F 检验；给定 η² 和 k 组 |
| 单样本比例检验功效 | - |
| 独立样本比例检验功效 | - |
| Pearson 相关功效 | - |
| 线性回归（R²增量）功效 | - |
| 卡方拟合优度功效 | - |
| 卡方独立性检验功效 | - |

**核心输出：** 样本量建议、功效曲线图、敏感度分析

**R 等价：** `pwr` 包（`pwr.t.test()`、`pwr.f2.test()`、`pwr.chisq.test()` 等）；`G*Power`（外部工具）

**Python 等价：** `statsmodels.stats.power`（`TTestIndPower()`、`FTestAnovaPower()` 等）

---

### 2.29 Effect Sizes（效应量，v29 新增）

| 过程 | 效应量统计量 |
|------|------------|
| **Independent Samples** | Cohen's d、Glass's Δ、Hedges' g；OR；相关 r |
| **Paired Samples** | Cohen's d（均值差/标准差）；r |
| **One Sample** | Cohen's d（vs 总体均值） |

**核心输出：** 效应量点估计 + Bootstrap 95% CI

**R 等价：** `effectsize` 包（`cohens_d()`、`hedges_g()`、`eta_squared()`）；`psych::cohen.d()`

**Python 等价：** `pingouin.compute_effsize()`；`scipy.stats` 手动计算

---

## 三、图表类型（Graphs 菜单全覆盖）

SPSS 提供两种图形界面：**Chart Builder（图表构建器）** 和 **Legacy Dialogs（传统对话框）**，以及底层 **GPL（Graphics Production Language）** 语法。

### 3.1 Bar Charts（条形图）

| 图表类型 | 英文名 | 数据要求 | ggplot2 等价 | Plotly/ECharts 等价 |
|---------|--------|---------|-------------|---------------------|
| 简单条形图 | Simple Bar | 1 类别变量（频率/均值） | `geom_bar(stat='count')` / `geom_col()` | `plotly: go.Bar()`；ECharts: `bar` |
| 聚类条形图 | Clustered Bar | 2 类别变量 | `geom_bar(position='dodge')` | `plotly` 分组 bar；ECharts `series` 多组 |
| 堆叠条形图 | Stacked Bar | 2 类别变量 | `geom_bar(position='stack')` | ECharts stacked bar |
| 百分比堆叠条形图 | 100% Stacked Bar | 2 类别变量 | `geom_bar(position='fill')` | - |
| 三维条形图 | 3-D Bar | 2 类别变量 | `ggplot2` 无原生3D；`rayshader` | `plotly: go.Bar3d()` |
| 误差条形图 | Error Bar | 连续 + 分类 | `geom_bar() + geom_errorbar()` | - |

### 3.2 Line Charts（折线图）

| 图表类型 | 数据要求 | ggplot2 等价 |
|---------|---------|-------------|
| 简单折线图 Simple Line | 1 连续/类别变量（时序或类别X轴） | `geom_line()` |
| 多线折线图 Multiple Lines | 1 连续 + 1 分类（分组变量） | `geom_line(aes(color=group))` |
| Drop-line | 类别X轴，垂直线连接到点 | `geom_segment() + geom_point()` |
| 3-D Line | - | `rayshader` / `plotly` |

### 3.3 Area Charts（面积图）

| 图表类型 | ggplot2 等价 |
|---------|-------------|
| 简单面积图 Simple Area | `geom_area()` |
| 堆叠面积图 Stacked Area | `geom_area(position='stack')` |

### 3.4 Pie / Polar Charts（饼图/极坐标图）

| 图表类型 | ggplot2 等价 | 说明 |
|---------|-------------|------|
| 饼图 Pie Chart | `geom_bar() + coord_polar("y")` | 名义变量比例 |
| 极坐标图 Polar Chart | `coord_polar()` | - |

### 3.5 High-Low Charts（高低图）

| 图表类型 | 说明 | ggplot2 等价 |
|---------|------|-------------|
| High-Low-Close | 金融K线图简化版（高/低/收） | `geom_linerange() + geom_point()` |
| Range Bar（范围条形图） | 条形跨越最小到最大值 | `geom_linerange()` / `geom_crossbar()` |
| Difference Area（差异面积图） | 两折线间填充面积 | `geom_ribbon()` |

### 3.6 Boxplots（箱线图）

| 图表类型 | ggplot2 等价 | Plotly/ECharts |
|---------|-------------|----------------|
| 简单箱线图 Simple Boxplot | `geom_boxplot()` | `go.Box()` / ECharts `boxplot` |
| 聚类箱线图 Clustered Boxplot | `geom_boxplot(aes(fill=group))` | - |
| 1-D 箱线图 | `geom_boxplot()` 单组 | - |
| Violin Plot（小提琴图，v30+）* | `geom_violin()` | - |

### 3.7 Dual Axes Charts（双轴图）

| 说明 | ggplot2 等价 |
|------|-------------|
| 两个Y轴（不同量纲），通常折线+条形组合 | `sec_axis()`（`ggplot2` v3.3+）；`cowplot` |

### 3.8 Scatter / Dot Plots（散点图）

| 图表类型 | 数据要求 | ggplot2 等价 |
|---------|---------|-------------|
| 简单散点图 Simple Scatter | 2 连续变量 | `geom_point()` |
| 分组散点图 Grouped Scatter | 2 连续 + 1 分类 | `geom_point(aes(color=group))` |
| 简单3D散点图 3-D Scatter | 3 连续变量 | `plotly: scatter_3d()`；`rgl` |
| 散点矩阵 Scatter Matrix | ≥2 连续变量 | `GGally::ggpairs()` |
| Drop-line 散点图 | 散点附垂直/水平线 | `geom_point() + geom_segment()` |
| 点图 Dot Plot | 1 连续 + 分组 | `geom_dotplot()`；`ggbeeswarm::geom_beeswarm()` |
| 气泡图 Bubble Chart | 2 连续 + 1 大小变量 | `geom_point(aes(size=…))` |

### 3.9 Histograms（直方图）

| 图表类型 | ggplot2 等价 |
|---------|-------------|
| 简单直方图 Simple | `geom_histogram()` |
| 堆叠直方图 Stacked | `geom_histogram(aes(fill=group), position='stack')` |
| 频率多边形 Frequency Polygon | `geom_freqpoly()` |
| 人口金字塔 Population Pyramid | `geom_bar()` + 双向X轴翻转 |

### 3.10 Error Bars（误差棒图）

独立的均值 ± CI / SD / SE 图，也可叠加到其他图上。

`geom_pointrange()` / `geom_errorbar()` / `geom_errorbarh()`

### 3.11 Pareto Charts（帕累托图）

条形图（降序）+ 累积折线，双Y轴。`ggplot2` + `sec_axis()`；`qcc::pareto.chart()`；ECharts 自定义。

### 3.12 Control Charts（控制图）

| 图表类型 | ggplot2 等价 |
|---------|-------------|
| X-bar R（均值-极差） | `qcc(type='xbar')` + `R-chart` |
| X-bar S（均值-标准差） | `qcc(type='xbar.one')` |
| I-MR（个值-移动极差） | `qcc(type='I')` |
| p 图 | `qcc(type='p')` |
| np 图 | `qcc(type='np')` |
| c 图 | `qcc(type='c')` |
| u 图 | `qcc(type='u')` |

### 3.13 P-P / Q-Q Plots

见 2.2.7 / 2.2.8 节。

**ggplot2：** `stat_qq() + stat_qq_line()`；**Plotly：** `go.Figure()` 手动

### 3.14 Sequence Charts（时序图）

时间序列折线图；支持时间轴参考线、季节标记。`ggplot2::geom_line()` + `scale_x_date()`

### 3.15 Autocorrelation / Cross-Correlation Plots

ACF/PACF 图（棒状图形式）；`forecast::Acf()`；`ggplot2` 自定义 `geom_segment()`

### 3.16 ROC Curves（ROC 曲线）

见 2.13.8 / 2.13.9 节。`pROC::ggroc()`；`plotly` + `sklearn.metrics.roc_curve()`

### 3.17 Forest Plots（森林图）

元分析模块输出（v29+）。

**R 等价：** `forest()`（`meta`/`metafor`）；`forestplot::forestplot()`；`ggplot2` 自定义 `geom_point() + geom_errorbarh()`

**Python：** `pymare.viz.forest_plot()`

### 3.18 Tree Diagram（决策树图）

决策树模块输出（节点、分支、纯度信息）。`rpart.plot::rpart.plot()`；`sklearn.tree.plot_tree()`；`dtreeviz`

### 3.19 Profile Plots（轮廓图）

GLM / 重复测量中估计边际均值的折线图（交互效应可视化）。`emmeans::emmip()`；`ggplot2::geom_line()` + 误差棒

### 3.20 Effect Size Plots（效应量图，v29+）

效应量估计值 + Bootstrap 95% CI 的点图/棒图形式。`effectsize::plot_effectsize()`；自定义 `geom_point() + geom_errorbarh()`

### 3.21 Heat Map（热图，v30+ Chart Builder 新增）*

| 说明 | ggplot2 等价 |
|------|-------------|
| 行列交叉值的颜色编码矩阵 | `geom_tile(aes(fill=value))` + `scale_fill_gradient2()` |
| **ECharts：** `heatmap`；**Plotly：** `go.Heatmap()` | - |

---

## 四、数据管理与转换（Transform / Data 菜单）

### 4.1 Transform 菜单

| 功能 | 说明 | R 等价 | Python 等价 |
|------|------|--------|------------|
| **Compute Variable（计算变量）** | 使用算术/函数表达式创建新变量（支持 200+ 内置函数） | `mutate()`（`dplyr`） | `df['newvar'] = expr` |
| **Count Values within Cases（个案内计数）** | 在指定变量中计算满足条件的个数 | `rowSums()`；`apply()` | `df.apply(lambda x: …, axis=1)` |
| **Shift Values（移位）** | 时间序列滞后/超前变量 | `lag()`/`lead()`（`dplyr`） | `df.shift()` |
| **Recode into Same Variable（重新编码到原变量）** | 修改值范围或映射关系 | `dplyr::recode()` | `df.replace()` |
| **Recode into Different Variable（重新编码到新变量）** | 同上，保留原变量 | `dplyr::case_when()` | `np.where()` |
| **Automatic Recode（自动重新编码）** | 将字符串/类别变量转为连续整数 | `as.numeric(factor(x))` | `pd.factorize()` |
| **Visual Binning（可视化分箱）** | 将连续变量转为有序类别（等宽/等频/自定义） | `cut()`；`santoku::chop_equally()` | `pd.cut()`；`pd.qcut()` |
| **Optimal Binning（最优分箱）** | 基于统计最优化准则自动分箱 | `smbinning()`（`smbinning`） | `optbinning.OptimalBinning()` |
| **Date and Time Wizard（日期时间向导）** | 创建/转换日期时间变量 | `lubridate` 包 | `pd.to_datetime()` |
| **Create Time Series（创建时间序列）** | 生成差分、滞后、移动均值等时序变量 | `diff()`；`zoo::rollapply()` | `df.diff()`；`pd.rolling()` |
| **Replace Missing Values（替换缺失值）** | 序列均值/线性插值/相邻值等 | `zoo::na.locf()`；`approx()` | `df.fillna(method='ffill')` |
| **Random Number Generators（随机数生成）** | 设置种子；选择生成器算法（Mersenne Twister等） | `set.seed()` | `numpy.random.seed()` |

### 4.2 Data 菜单

| 功能 | 说明 | R 等价 | Python 等价 |
|------|------|--------|------------|
| **Define Variable Properties（定义变量属性）** | 批量设置测量级别、值标签、缺失值 | `labelled` 包 | `pd.Categorical()` |
| **Set Measurement Level（设置测量级别）** | 名义/有序/连续/字符串 | `factor()`；`ordered()` | `df.astype('category')` |
| **Define Multiple Response Sets（定义多重响应集）** | 见 2.19 节 | - | - |
| **Copy Data Properties（复制数据属性）** | 从模板数据集复制变量属性 | `haven::read_sav()` 元数据 | `pyreadstat` |
| **Split File（拆分文件）** | 按分组变量对所有后续分析分组输出 | `group_by()` + `nest()` | `df.groupby()` |
| **Select Cases（选择个案）** | 按条件过滤子集 | `dplyr::filter()` | `df.query()` / `df[cond]` |
| **Weight Cases（加权个案）** | 使用频率变量或调查权重 | `weighted.mean()`；`survey` 包 | `df.sample(weights=…)` |
| **Aggregate（聚合）** | 将多个个案聚合为组汇总统计数据集 | `dplyr::summarise()` | `df.groupby().agg()` |
| **Restructure（重构）** | 宽格式↔长格式转换（SPSS Wizard） | `tidyr::pivot_wider/longer()` | `pd.melt()`；`pd.pivot()` |
| **Merge Files（合并文件）** | Add Variables（横向合并）/ Add Cases（纵向合并） | `merge()`/`rbind()` | `pd.merge()`；`pd.concat()` |
| **Sort Cases（排序个案）** | 按变量升序/降序排列 | `dplyr::arrange()` | `df.sort_values()` |
| **Sort Variables（排序变量）** | 按名称/类型等属性排序变量列 | `select()` 重排 | `df.reindex()` |
| **Transpose（转置）** | 行↔列转换 | `t()`；`pivot_longer() + pivot_wider()` | `df.T` |
| **OMS（Output Management System）** | 将输出路由到 XML/HTML/Excel/SPSS格式 | `sink()`；`stargazer` | `pandas` 导出 |

---

## 五、参考文献与官方文档

### 5.1 官方 IBM 文档

| 文档 | URL |
|------|-----|
| SPSS Statistics 29 文档首页 | https://www.ibm.com/docs/en/spss-statistics/29.0.0 |
| SPSS Statistics 30 文档首页 | https://www.ibm.com/docs/en/spss-statistics/30.0.0 |
| SPSS Statistics Base 手册 (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-spss-statistics-base |
| SPSS Advanced Statistics (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-advanced-statistics |
| SPSS Regression (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-regression |
| SPSS Categories (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-categories |
| SPSS Forecasting (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-forecasting |
| SPSS Decision Trees (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-decision-trees |
| SPSS Missing Values (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-missing-values |
| SPSS Complex Samples (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-complex-samples |
| SPSS Custom Tables (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-custom-tables |
| SPSS Direct Marketing (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-direct-marketing |
| SPSS Neural Networks (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-neural-networks |
| SPSS Exact Tests (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-exact-tests |
| SPSS Bootstrapping (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-bootstrapping |
| SPSS Power Analysis (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-power-analysis |
| SPSS Meta Analysis (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-meta-analysis |
| SPSS Effect Sizes (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-effect-size |
| SPSS Bayesian Statistics (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-bayesian-statistics |
| IBM SPSS Statistics Algorithms PDF (29) | https://www.ibm.com/docs/en/spss-statistics/29.0.0?topic=statistics-algorithms |
| IBM SPSS Statistics 产品特性页 | https://www.ibm.com/products/spss-statistics/features |
| IBM SPSS Statistics v32 新功能 | https://www.ibm.com/products/spss-statistics/whats-new |

### 5.2 相关 R 包

| 包名 | 功能对应 |
|------|---------|
| `psych` | 描述统计、因子分析、信度分析 |
| `lme4` / `nlme` | 混合模型 |
| `survival` + `survminer` | 生存分析 |
| `car` | ANOVA 类型III、Levene检验、VIF |
| `BayesFactor` | 贝叶斯推断 |
| `meta` / `metafor` | 元分析 |
| `pwr` | 功效分析 |
| `effectsize` | 效应量 |
| `survey` | 复杂样本调查 |
| `mice` | 多重填补 |
| `qcc` | 质量控制图 |
| `forecast` | 时间序列 ARIMA/指数平滑 |
| `ggplot2` + `GGally` | 全部图形 |
| `pROC` | ROC 曲线 |
| `rpart` / `party` | 决策树 |
| `ordinal` | 有序回归 |
| `emmeans` | 估计边际均值 |
| `vcd` | 类别数据可视化与检验 |

### 5.3 相关 Python 库

| 库 | 功能对应 |
|----|---------|
| `scipy.stats` | 基础统计检验 |
| `statsmodels` | GLM、混合模型、时间序列 |
| `sklearn` | 机器学习、聚类、降维、神经网络 |
| `pingouin` | 描述统计、检验、效应量 |
| `lifelines` | 生存分析 |
| `pymc` / `pymc3` | 贝叶斯推断 |
| `metafor`（Python绑定） / `pymare` | 元分析 |
| `pandas` + `numpy` | 数据管理 |
| `matplotlib` / `plotly` / `seaborn` | 图形 |
| `factor_analyzer` | 因子分析 |
| `mice`（Python）/ `sklearn.impute` | 多重填补 |

---

## 附录：SPSS 版本关键新增功能对照

| 版本 | 关键新增 |
|------|---------|
| v26 (2019) | 贝叶斯统计（15个贝叶斯过程）内置 Base |
| v27 (2020) | 功效分析（Power Analysis）模块；比例检验过程 |
| v28 (2021) | ROC Analysis 增强；Effect Sizes 过程 |
| v29 (2022) | Meta Analysis 模块；Summary Independent T Test；ROC Analysis（DeLong检验）；Enhanced Missing Value Analysis |
| v30 (2023) | 信度分析新增 McDonald's ω；CTABLES 增强；图表构建器新增 Heatmap |
| v32 (2025) | AI 辅助解释；网络分析（Network Analysis）；部分相关增强；*待确认最新特性* |

---

> **说明：** 本文档以 SPSS Statistics v29/v30 为基准。部分 v32 新增功能标注"*"。所有官方 URL 以 IBM Documentation 为来源（IBM Documentation 采用 JavaScript SPA 架构，内容通过 API 动态加载，URL 结构已按官方格式列出）。R 与 Python 等价函数为最广泛使用的开源等价实现，可用于问卷分析平台 (survey-analysis-platform) 的等价功能开发参考。