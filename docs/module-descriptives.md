# 描述统计模块 (SPSS 等价)

> 实现位置:`02-analyze/descriptives.R`(入口) + `lib/descriptives.R`(库)
> 对标 SPSS:**Analyze > Descriptive Statistics**(Frequencies / Descriptives / Explore / Crosstabs basic)

---

## 1. 功能清单

| SPSS 子菜单 | 本项目实现 | 输出字段 |
| --- | --- | --- |
| Frequencies | `freq_table()` | 类别、频数、百分比、有效百分比、累计百分比;缺失值单独行 |
| Descriptives | `desc_table()` | N、缺失、均值、标准误、中位数、众数、标准差、方差、极差、最小/最大、Q1/Q3、IQR、变异系数 CV%、偏度+SE、峰度+SE |
| Explore(分层) | `desc_by_group()` | 分组 × 上述全部指标 |
| Crosstabs(基础) | `crosstab_basic()` | 频数表(含 Sum)、行%、列%(χ² 检验在 `crosstabs.R`) |
| 正态性 | `normality_table()` | Shapiro-Wilk p、Kolmogorov-Smirnov p |

---

## 2. 使用方法

### 2.1 命令行直接跑

```bash
Rscript 02-analyze/descriptives.R                  # 默认两个 survey 都跑
Rscript 02-analyze/descriptives.R survey1          # 只跑 survey1
```

### 2.2 通过 Python tool 层(Agent 调用)

```python
from app.tools import run_analysis_module
result = run_analysis_module("descriptives", survey_id="survey1")
# → output/results/descriptives_s1.rds
```

### 2.3 配置驱动(可选)

写一份 `output/results/analysis_plan.json`:

```json
{
  "descriptives": {
    "numeric_vars": ["impact_num", "ai_accept", "meta_accept"],
    "categorical_vars": ["gender", "age_group", "status"],
    "group_by": ["gender", "age_group"],
    "crosstab_pairs": [
      ["gender", "used_voucher"],
      ["age_group", "status"]
    ]
  }
}
```

不配置 → 自动分类:
- 数值变量:所有 `is.numeric` 且有 ≥3 个有效观测的列
- 分类变量:字符/因子 + 低基数数值列(unique 2-10,如 Likert/二分)
- 分组:自动挑前两个 unique 2-6 的分类列
- 交叉表:自动用前两个分类变量

---

## 3. 输出 RDS 结构

```r
result <- readRDS("output/results/descriptives_s1.rds")
str(result, max.level = 1)
# List of 6
#  $ frequencies : List of 22   (named by variable)
#  $ descriptives: data.frame    19 rows × 20 cols
#  $ normality   : data.frame    19 rows × 4 cols
#  $ by_group    : List of 2     (named by group var)
#  $ crosstabs   : List of 1     (named "var1_x_var2")
#  $ meta        : List of 5     (survey_id, n_total, n_numeric, n_categorical, ts)
```

每个 `frequencies[[v]]`,`descriptives`,`by_group[[g]]` 都是干净 data.frame,可直接 `knitr::kable()` 或 `gt::gt()` 进 Quarto 报告。

---

## 4. 已验证

```text
survey1:  208 受访者 → 19 数值变量、22 分类变量、2 分组(gender, gender_bin)
          → output/results/descriptives_s1.rds (含 frequencies/descriptives/
            normality/by_group/crosstabs/meta)
survey2:  205 受访者 → 16 数值、18 分类、2 分组
          → output/results/descriptives_s2.rds
```

通过 `app/tools.py::run_analysis_module("descriptives")` 调用一次成功,
status=`ok`,rds 文件按期生成。

---

## 5. 与历史脚本的兼容

- 旧版逻辑保留在 `02-analyze/descriptives_legacy.R`(硬编码 survey1 的列名)
- `app/tools.py` 的调用接口不变(`run_analysis_module("descriptives", ...)`)
- 旧 RDS 字段 `descriptives`(含 mean/sd/median/skew/kurt)的等价数据在新结构的 `result$descriptives` 中,字段名扩充

---

## 6. 下一步衔接

| 模块 | 衔接方式 |
| --- | --- |
| `chart-basic`(基础图表) | 直接消费 `result$frequencies` → 柱状图/饼图;`result$descriptives` → 箱线图;`result$normality` → QQ 图 |
| `rpt-word` / `rpt-pdf` | Quarto chunk 直接 `kable(result$descriptives)` |
| `an-inferential`(t/ANOVA) | 用 `result$normality` 决定参数 vs 非参数检验 |
| `set_analysis_plan` Agent tool | 写 `analysis_plan.json` 后,后续模块都按 plan 跑 |
