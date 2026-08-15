#!/usr/bin/env Rscript
# 02-analyze/descriptives.R — SPSS 等价描述统计(generic)
#
# 用法:
#   Rscript 02-analyze/descriptives.R                  → 跑 survey1+2,自动选变量
#   Rscript 02-analyze/descriptives.R survey1          → 只跑 survey1
#
# 自动行为(无 plan.json 时):
#   - 数值列 → desc_table + normality
#   - 分类列(unique <= 20) → freq_table
#   - 若发现 gender/age_group/status 等典型分组列 → desc_by_group
#
# 优先读 output/results/analysis_plan.json:
#   {
#     "descriptives": {
#       "numeric_vars": ["impact_num", "ai_accept", ...],
#       "categorical_vars": ["gender", "status", ...],
#       "group_by": ["gender"],
#       "crosstab_pairs": [["gender","status"]]
#     }
#   }
#
# 输出:output/results/descriptives_<sid>.rds 含:
#   $frequencies          named list of freq tables
#   $descriptives         data.frame
#   $normality            data.frame
#   $by_group             named list (per group var) of data.frames
#   $crosstabs            named list of crosstab_basic results
#   $meta                 list(survey_id, n_total, n_numeric, n_categorical, ts)

.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({
  library(DBI); library(RSQLite)
})
source("lib/utils.R")
source("lib/descriptives.R")
module_header("描述统计 (SPSS 等价)")

# ── 1. 读 plan.json(如有) ────────────────────────────────────────
read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) {
    return(list())
  }
  tryCatch(jsonlite::fromJSON(pth)$descriptives, error = function(e) list())
}

# ── 2. 加载一个 survey 的宽表 ─────────────────────────────────────
load_wide <- function(survey_id) {
  db_path <- sprintf("data/db/%s.db", survey_id)
  if (!file.exists(db_path)) {
    message(sprintf("⚠ 数据库不存在: %s,跳过", db_path))
    return(NULL)
  }
  con <- dbConnect(RSQLite::SQLite(), db_path)
  on.exit(dbDisconnect(con))

  resp <- dbGetQuery(con, sprintf("SELECT * FROM respondents WHERE survey='%s'", survey_id))
  if (nrow(resp) == 0) return(NULL)

  # 如果有 responses 长表,pivot 到宽表合并(仅当存在 respondent_id 列时)
  tables <- dbListTables(con)
  if ("responses" %in% tables) {
    cols <- tryCatch(names(dbGetQuery(con, "SELECT * FROM responses LIMIT 1")),
                     error = function(e) character(0))
    join_key <- intersect(c("respondent_id", "id"), cols)[1]
    if (!is.na(join_key) && "variable" %in% cols && "value" %in% cols) {
      long <- dbGetQuery(con, sprintf(
        "SELECT %s AS rid, variable, value FROM responses", join_key))
      if (nrow(long) > 0) {
        long$value <- suppressWarnings(as.numeric(long$value))
        wide <- tryCatch(
          reshape(long, idvar = "rid", timevar = "variable",
                  direction = "wide", v.names = "value"),
          error = function(e) NULL
        )
        if (!is.null(wide)) {
          names(wide) <- sub("^value\\.", "", names(wide))
          # 找 respondents 的主键列
          resp_key <- intersect(c("respondent_id", "id"), names(resp))[1]
          if (!is.na(resp_key)) {
            # 只合并 resp 里没有的列,避免覆盖
            new_cols <- setdiff(names(wide), c("rid", names(resp)))
            if (length(new_cols) > 0) {
              resp <- merge(
                resp, wide[, c("rid", new_cols), drop = FALSE],
                by.x = resp_key, by.y = "rid", all.x = TRUE
              )
            }
          }
        }
      }
    }
  }
  resp
}

# ── 3. 自动变量分类 ──────────────────────────────────────────────
auto_classify_vars <- function(df, plan) {
  # 排除主键/元数据列
  skip <- c("respondent_id", "survey", "id", "rowid", "submit_time", "created_at")
  candidates <- setdiff(names(df), skip)

  numeric_vars <- if (!is.null(plan$numeric_vars) && length(plan$numeric_vars) > 0) {
    intersect(plan$numeric_vars, names(df))
  } else {
    # 所有数值列(含 Likert/二分);至少 3 个有效观测
    Filter(function(v) {
      x <- df[[v]]
      is.numeric(x) && sum(!is.na(x)) >= 3
    }, candidates)
  }

  categorical_vars <- if (!is.null(plan$categorical_vars) && length(plan$categorical_vars) > 0) {
    intersect(plan$categorical_vars, names(df))
  } else {
    # 字符/因子 + 低基数数值(<=10 unique,如 Likert/binary)
    Filter(function(v) {
      x <- df[[v]]
      uniq <- unique(x[!is.na(x)])
      if (length(uniq) < 2 || length(uniq) > 20) return(FALSE)
      is.character(x) || is.factor(x) || length(uniq) <= 10
    }, candidates)
  }

  list(numeric = numeric_vars, categorical = categorical_vars)
}

# ── 4. 主循环 ────────────────────────────────────────────────────
plan <- read_plan()

for (survey_id in target_surveys()) {
  cat(sprintf("\n──── %s ────\n", survey_id))
  df <- load_wide(survey_id)
  if (is.null(df) || nrow(df) == 0) next

  vars <- auto_classify_vars(df, plan)
  cat(sprintf("数值变量(%d): %s\n", length(vars$numeric),
              paste(head(vars$numeric, 10), collapse = ", ")))
  cat(sprintf("分类变量(%d): %s\n", length(vars$categorical),
              paste(head(vars$categorical, 10), collapse = ", ")))

  # 4.1 频率表 ─────────────────────────────────────────────────
  freqs <- list()
  for (v in vars$categorical) {
    freqs[[v]] <- freq_table(df[[v]])
    cat(sprintf("\n[频率] %s\n", v))
    print(utils::head(freqs[[v]], 8))
  }

  # 4.2 数值描述 ───────────────────────────────────────────────
  desc <- desc_table(df, vars$numeric)
  if (nrow(desc) > 0) {
    cat("\n[描述统计]\n")
    print(desc[, c("变量","N","均值","标准差","中位数","最小值","最大值","偏度","峰度")])
  }

  # 4.3 正态性 ─────────────────────────────────────────────────
  norm_t <- normality_table(df, vars$numeric)
  if (nrow(norm_t) > 0) {
    cat("\n[正态性检验]\n")
    print(norm_t)
  }

  # 4.4 分层描述 ───────────────────────────────────────────────
  group_vars <- if (!is.null(plan$group_by) && length(plan$group_by) > 0) {
    intersect(plan$group_by, names(df))
  } else {
    # 自动挑 unique 数 2-6 的分类列
    Filter(function(v) {
      u <- length(unique(df[[v]][!is.na(df[[v]])]))
      u >= 2 && u <= 6
    }, vars$categorical)[1:min(2, length(vars$categorical))]
  }
  group_vars <- group_vars[!is.na(group_vars)]

  by_group <- list()
  for (g in group_vars) {
    by_group[[g]] <- desc_by_group(df, vars$numeric, g)
    cat(sprintf("\n[分层描述 by %s] (前10行)\n", g))
    print(utils::head(by_group[[g]][, c("分组","变量","N","均值","标准差","中位数")], 10))
  }

  # 4.5 交叉表 ─────────────────────────────────────────────────
  crosstabs <- list()
  pairs <- plan$crosstab_pairs
  if (!is.null(pairs) && length(pairs) > 0) {
    for (i in seq_len(nrow(pairs))) {
      r <- as.character(pairs[i, 1]); c <- as.character(pairs[i, 2])
      if (r %in% names(df) && c %in% names(df)) {
        key <- paste0(r, "_x_", c)
        crosstabs[[key]] <- crosstab_basic(df, r, c)
        cat(sprintf("\n[交叉表] %s × %s (频数)\n", r, c))
        print(crosstabs[[key]]$freq)
      }
    }
  } else if (length(vars$categorical) >= 2) {
    # 自动:头两个分类变量交叉
    r <- vars$categorical[1]; c <- vars$categorical[2]
    key <- paste0(r, "_x_", c)
    crosstabs[[key]] <- crosstab_basic(df, r, c)
    cat(sprintf("\n[自动交叉表] %s × %s\n", r, c))
    print(crosstabs[[key]]$freq)
  }

  # 4.6 保存 ───────────────────────────────────────────────────
  dir.create("output/results", showWarnings = FALSE, recursive = TRUE)
  result <- list(
    frequencies = freqs,
    descriptives = desc,
    normality = norm_t,
    by_group = by_group,
    crosstabs = crosstabs,
    meta = list(
      survey_id = survey_id,
      n_total = nrow(df),
      n_numeric = length(vars$numeric),
      n_categorical = length(vars$categorical),
      ts = as.character(Sys.time())
    )
  )
  out_path <- sprintf("output/results/descriptives_%s.rds", survey_suffix(survey_id))
  saveRDS(result, out_path)
  cat(sprintf("\n✓ 已保存 → %s\n", out_path))
}

message("描述统计完成")
