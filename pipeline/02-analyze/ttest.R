#!/usr/bin/env Rscript
# 02-analyze/ttest.R — SPSS 等价 t 检验 (generic)
#
# 优先读 output/results/analysis_plan.json:
#   {"ttest": {
#       "one_sample":   [{"var": "impact_num", "mu": 3}, ...],
#       "independent":  [{"dv": "extra_spend", "group": "gender"}, ...],
#       "paired":       [{"var1": "x", "var2": "y"}, ...],
#       "nonparam":     true
#   }}
#
# 无 plan 时自动:
#   - one_sample: 所有数值列 vs mu=mean(median 兜底)
#   - independent: 数值列 × 二分类列
#   - nonparam: 同时跑 Mann-Whitney
#
# 输出 output/results/ttest_<sid>.rds:
#   $one_sample / $independent / $paired / $mann_whitney / $wilcoxon / $meta

.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/inferential.R")
module_header("t 检验 (SPSS 等价)")

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$ttest, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db))
  DBI::dbReadTable(db, "respondents")
}

auto_detect <- function(df) {
  numeric_vars <- names(df)[vapply(df, is.numeric, logical(1))]
  numeric_vars <- setdiff(numeric_vars, c("id", "respondent_id"))
  # 排除几乎常量
  numeric_vars <- numeric_vars[vapply(df[numeric_vars], function(v) {
    v <- v[!is.na(v)]
    length(unique(v)) > 3 && length(v) >= 10
  }, logical(1))]
  # 二分类候选
  bin_vars <- names(df)[vapply(df, function(v) {
    u <- unique(v[!is.na(v)])
    length(u) == 2 && (is.character(v) || is.factor(v) || is.logical(v) || (is.numeric(v) && all(u %in% c(0, 1))))
  }, logical(1))]
  list(numeric = numeric_vars, binary = bin_vars)
}

run_for_survey <- function(survey_id) {
  cat(sprintf("\n[ttest] %s ─────────────────────\n", survey_id))
  df <- load_wide(survey_id)
  plan <- read_plan()
  det <- auto_detect(df)

  result <- list(one_sample = NULL, independent = NULL, paired = NULL,
                 mann_whitney = NULL, wilcoxon = NULL)

  # ── 1. one_sample ────────────────────────────────────
  one_specs <- plan$one_sample
  if (is.null(one_specs)) {
    one_specs <- lapply(head(det$numeric, 8), function(v) {
      list(var = v, mu = round(median(df[[v]], na.rm = TRUE), 2))
    })
  }
  one_rows <- list()
  for (sp in one_specs) {
    v <- sp$var; if (!v %in% names(df)) next
    r <- one_sample_t(df[[v]], mu = sp$mu %||% 0, var_name = v)
    if (!is.null(r)) one_rows[[length(one_rows) + 1]] <- r
  }
  if (length(one_rows) > 0) result$one_sample <- do.call(rbind, one_rows)

  # ── 2. independent ───────────────────────────────────
  ind_specs <- plan$independent
  if (is.null(ind_specs)) {
    ind_specs <- list()
    for (g in head(det$binary, 3)) for (d in head(det$numeric, 6)) {
      ind_specs[[length(ind_specs) + 1]] <- list(dv = d, group = g)
    }
  }
  ind_rows <- list(); mw_rows <- list()
  for (sp in ind_specs) {
    d <- sp$dv; g <- sp$group
    if (!d %in% names(df) || !g %in% names(df)) next
    r <- independent_t(df[[d]], df[[g]], dv_name = d, group_name = g)
    if (!is.null(r)) ind_rows[[length(ind_rows) + 1]] <- r
    mw <- mann_whitney(df[[d]], df[[g]], dv_name = d, group_name = g)
    if (!is.null(mw)) mw_rows[[length(mw_rows) + 1]] <- mw
  }
  if (length(ind_rows) > 0) result$independent <- do.call(rbind, ind_rows)
  if (length(mw_rows)  > 0) result$mann_whitney <- do.call(rbind, mw_rows)

  # ── 3. paired ────────────────────────────────────────
  pair_specs <- plan$paired
  if (!is.null(pair_specs)) {
    p_rows <- list(); w_rows <- list()
    for (sp in pair_specs) {
      v1 <- sp$var1; v2 <- sp$var2
      if (!v1 %in% names(df) || !v2 %in% names(df)) next
      r <- paired_t(df[[v1]], df[[v2]], var1 = v1, var2 = v2)
      if (!is.null(r)) p_rows[[length(p_rows) + 1]] <- r
      w <- wilcoxon_signed(df[[v1]], df[[v2]], var1 = v1, var2 = v2)
      if (!is.null(w)) w_rows[[length(w_rows) + 1]] <- w
    }
    if (length(p_rows) > 0) result$paired <- do.call(rbind, p_rows)
    if (length(w_rows) > 0) result$wilcoxon <- do.call(rbind, w_rows)
  }

  result$meta <- list(
    survey_id = survey_id, n_total = nrow(df),
    n_one_sample = nrow(result$one_sample %||% data.frame()),
    n_independent = nrow(result$independent %||% data.frame()),
    n_paired = nrow(result$paired %||% data.frame()),
    ts = format(Sys.time())
  )

  suffix <- if (survey_id == "survey1") "s1" else "s2"
  out <- sprintf("output/results/ttest_%s.rds", suffix)
  saveRDS(result, out)
  cat(sprintf("[ttest] %s → %s  (单样本%d / 独立%d / 配对%d)\n",
              survey_id, out, result$meta$n_one_sample,
              result$meta$n_independent, result$meta$n_paired))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

surveys <- target_surveys()
for (s in surveys) run_for_survey(s)
message("t 检验完成")
