# Survey Analysis Platform

问卷调查数据分析平台 — 弱耦合、模块化、可编排的统计分析流水线。

## 设计哲学

```
源头数据 → 探索(What?) → 清洗(Encode) → 分析(SPSS-style) → 整合 → 报告
   │            │              │               │              │         │
   Excel      Jupyter          R              R×N           RDS       Quarto
              (Python)      (lib/)       (02-analyze/)    (03-)     (04-)
```

每一步独立运行，中间产物通过 RDS 文件传递。任意模块可替换、可跳过、可并行。

## 目录结构

```
survey-analysis-platform/
├── README.md                     # 本文件
├── Makefile                      # 管道编排（make all 跑全流程）
├── .hermes/config.yaml           # Hermes Agent 项目配置
│
├── data/raw/                     # 原始数据（Excel/CSV）
│   ├── 问卷数据_完整版_209条.xlsx
│   └── 问卷数据_精简版_206条.xlsx
├── data/cleaned/                 # 清洗后数据（RDS）
│
├── 00-explore/                   # 数据探索
│   └── explore.ipynb             # Jupyter: 数据结构、变量分布、缺失值
│
├── 01-clean/                     # 数据清洗与编码
│   ├── clean_survey1.R           # 调查一：文本→数值编码
│   └── clean_survey2.R           # 调查二：文本→数值编码
│
├── 02-analyze/                   # 统计分析模块（每个独立、可单独运行）
│   ├── descriptives.R            # 频率分布 + 描述统计 + 正态性检验
│   ├── crosstabs.R               # 交叉表 + χ² + Cramer's V + Gamma
│   ├── ttest.R                   # t检验 + Mann-Whitney + Wilcoxon
│   ├── anova.R                   # ANOVA + η²/ω² + Tukey + MANOVA + Kruskal
│   ├── correlation.R             # Pearson + Spearman + Kendall + 偏相关
│   ├── reliability.R             # Cronbach α + 分半 + ω + ICC + 项统计
│   ├── factor_analysis.R         # KMO + Bartlett + PCA + Varimax + 因子得分
│   ├── regression.R              # 线性回归 + Logistic + ROC + 曲线估计
│   ├── mediation.R               # Baron&Kenny + Sobel + Bootstrap
│   ├── moderation.R              # 交互项 + 简单斜率
│   ├── cluster.R                 # K-Means + 判别分析
│   └── power_bootstrap.R         # Bootstrap CI + Power Analysis + MCA
│
├── 03-integrate/                 # 结果整合
│   └── compile.R                 # 收集所有 output/results/*.rds → 统一数据结构
│
├── 04-report/                    # 报告生成
│   ├── report.qmd                # Quarto 模板（按报价清单组织）
│   ├── _quarto.yml               # Quarto 配置
│   └── render.sh                 # 渲染脚本
│
├── lib/                          # 共享 R 函数库
│   ├── encode.R                  # 通用编码函数（两调查共用）
│   ├── spss_tables.R             # SPSS 风格表格生成器
│   └── utils.R                   # 工具函数
│
└── output/
    ├── results/                  # 分析结果（RDS）
    └── reports/                  # 生成的 HTML 报告
```

## 模块接口规范

每个 `02-analyze/` 模块遵循统一接口：

```r
# 输入: 命令行参数或默认路径
#   1. data/cleaned/survey1.rds
#   2. data/cleaned/survey2.rds
# 输出: output/results/<module_name>_s1.rds + _s2.rds

# 输出格式: list(
#   tables = list(...),    # kable-ready 数据框
#   stats  = list(...),    # 标量统计值
#   notes  = character()   # 解释说明
# )
```

## 快速开始

### 0. 配置环境变量(只配置一次)

```bash
cp .env.example .env       # 若已存在 .env 跳过
# 编辑 .env,填入:
#   DEEPSEEK_API_KEY=sk-...
#   LANGFUSE_SECRET_KEY=sk-lf-... (可选)
#   LANGFUSE_PUBLIC_KEY=pk-lf-... (可选)
```

`.env` 已被 `.gitignore` 排除,不会提交。`app/main.py` 启动时通过
`python-dotenv` 自动加载,**无需每次 `export`**。

### 1. 启动 Streamlit 应用(推荐)

```bash
streamlit run app/main.py --server.port 8501
# 浏览器打开 http://localhost:8501
```

界面 5 个 tab:
- **💬 分析助手** — 自然语言驱动 Agent,自动编排清洗→分析→报告
- **📁 数据** — SQLite 数据库浏览,分页 + 列筛选
- **📊 分析模块** — 13 个模块卡片,一键运行
- **🖼️ 图表画廊** — 缩略图/单图/幻灯片/Plotly 交互预览
- **📄 报告中心** — HTML/Word/PDF/图片包 生成与下载

### 2. 命令行管道(无 LLM)

```bash
# 1. 探索数据
make explore          # 打开 Jupyter

# 2. 清洗数据
make clean            # 运行 01-clean/*.R

# 3. 全量分析
make analyze          # 运行所有 02-analyze/*.R(可并行)

# 4. 整合结果
make integrate        # 编译所有结果

# 5. 生成报告
make report           # quarto render → HTML

# 一键全流程
make all

# 单独跑某个模块
make descriptives     # 只跑描述统计
make mediation        # 只跑中介分析

# LSP 语法检查(不运行)
make lint
```

### 3. Agent 工具一览(19 个)

| 类别 | 工具 |
|---|---|
| 数据 | `load_dataset`, `inspect_schema`, `set_analysis_plan`, `preview_data` |
| 清洗 | `run_clean`（消费券 schema 专用）, `run_generic_ingest`（任意 .xlsx → raw_data） |
| 分析 | `run_analysis_module`, `run_selected_analysis`, `get_results`, `interpret_results` |
| 图表 | `render_charts` |
| 整合 | `run_compile`, `run_report` |
| 报告 | `list_report_templates`, `generate_word`, `generate_pdf`, `export_charts_bundle` |
| 状态 | `check_pipeline_status`, `read_log`, `get_variable_catalog` |
| 编排 | `dispatch_subagent` |

#### 数据上传 / 入库说明

UI 上传 .xlsx/.csv 文件后保存到 `data/raw/`，**Agent 必须用以下之一显式入库**（默认 cleaner 路径是硬编码的，不传 source_file 会读旧文件）：

```text
# 消费券问卷（字段与默认 schema 一致）
run_clean(target="survey1", source_file="data/raw/<filename>.xlsx")
  → 完整 13 个 R 统计模块可用

# 其他主题问卷（字段不匹配消费券 schema）
run_generic_ingest(survey_id="custom_xxx", source_file="data/raw/<filename>.xlsx")
  → 仅 preview_data / 自定义 SQL 可用；R 模块不可用
```

两种路径都会**先删除目标 `data/db/<id>.db` 再重建**，不会重复追加。

## 技术栈

| 层 | 工具 | 用途 |
|----|------|------|
| 探索 | Jupyter + Python (pandas) | 数据结构探查、变量映射 |
| 清洗 | R (tidyverse/readxl) | 文本→数值编码、多选题拆分 |
| 分析 | R (psych/car/effsize/lavaan/pROC) | SPSS 等价统计分析 |
| 编排 | GNU Make + Hermes Agent | 管道调度、错误处理 |
| 校验 | R LSP (languageserver) | 语法检查、诊断 |
| 报告 | Quarto + knitr/kable | HTML 报告生成 |

## Hermes Agent 集成

平台设计为 Hermes Agent 可编排的流水线。`.hermes/config.yaml` 配置项目上下文。

```bash
# Hermes 驱动分析
hermes "跑调查一全量分析"
# Agent 自动: make clean → make analyze → make report
```

## 扩展

添加新分析模块：

```bash
cp 02-analyze/_template.R 02-analyze/my_new_test.R
# 编辑模块 → make lint → make my_new_test → make integrate → make report
```

添加新调查数据：

```bash
cp data/raw/新问卷.xlsx data/raw/
cp 01-clean/clean_survey1.R 01-clean/clean_survey3.R
# 编辑编码脚本 → make clean → make analyze
```
