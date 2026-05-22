#!/usr/bin/env Rscript
# 02-analyze/regression.R — SPSS 等价回归分析 (generic)
#
# plan.json:
#   {"regression": {
#       "linear":     [{"response": "extra_spend", "predictors": ["age_num","income_num","gender_bin"]}],
#       "hierarchical": [{"response": "y", "blocks": [["x1","x2"], ["x3"], ["x4","x5"]]}],
#       "logistic":   [{"response": "used_bin", "predictors": ["age_num","gender_bin","income_num"]}],
#       "multinomial":[{"response": "status",   "predictors": ["age_num","income_num"]}],
#       "poisson":    [{"response": "count_var","predictors": ["x1","x2"]}]
#   }}
#
# 自动行为:
#   - linear: 第 1 个数值列作 Y, 其余 ≤4 个数值列作 X
#   - logistic: 任一 _bin / 二分类列作 Y, 其余数值列作 X
#
# 输出 RDS:
#   $linear        list of {model_summary, anova, coefficients, collinearity, residual_diagnostics, influence_top10}
#   $hierarchical  list of {blocks_summary, ...}
#   $logistic      list of {model_summary, coefficients, classification_table}
#   $multinomial   list (可选)
#   $poisson       list (可选)
#   $meta

.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/regression.R")
module_header("回归分析 (SPSS 等价)")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$regression, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db)); DBI::dbReadTable(db, "respondents")
}

auto_detect <- function(df) {
  numeric_vars <- names(df)[vapply(df, is.numeric, logical(1))]
  numeric_vars <- setdiff(numeric_vars, c("id", "respondent_id"))
  numeric_vars <- numeric_vars[vapply(df[numeric_vars], function(v) {
    v <- v[!is.na(v)]; length(unique(v)) > 3 && length(v) >= 20
  }, logical(1))]
  bin_vars <- names(df)[vapply(df, function(v) {
    u <- unique(v[!is.na(v)])
    length(u) == 2 && (is.numeric(v) && all(u %in% c(0, 1)) || is.logical(v))
  }, logical(1))]
  list(numeric = numeric_vars, binary = bin_vars)
}

run_for_survey <- function(survey_id) {
  cat(sprintf("\n[regression] %s ─────────────────────\n", survey_id))
  df <- load_wide(survey_id); plan <- read_plan(); det <- auto_detect(df)

  # ── 自动 specs ──────────────────────────────────────
  if (is.null(plan$linear) && length(det$numeric) >= 2) {
    plan$linear <- list(list(
      response = det$numeric[1],
      predictors = head(det$numeric[-1], 4)
    ))
  }
  if (is.null(plan$logistic) && length(det$binary) >= 1 && length(det$numeric) >= 1) {
    plan$logistic <- list(list(
      response = det$binary[1],
      predictors = head(setdiff(det$numeric, det$binary[1]), 4)
    ))
  }

  result <- list(linear = list(), hierarchical = list(),
                 logistic = list(), multinomial = list(), poisson = list())

  # ── 1. Linear ──────────────────────────────────────
  for (sp in (plan$linear %||% list())) {
    y <- sp$response; xs <- unlist(sp$predictors)
    if (is.null(y) || !y %in% names(df)) next
    xs <- intersect(xs, names(df)); if (length(xs) == 0) next
    f <- stats::as.formula(paste(y, "~", paste(xs, collapse = " + ")))
    r <- tryCatch(linear_regression(f, df[, c(y, xs)]),
                  error = function(e) list(error = conditionMessage(e)))
    result$linear[[paste0(y, "__by__", paste(xs, collapse = "_"))]] <- r
  }

  # ── 2. Hierarchical ─────────────────────────────────
  for (sp in (plan$hierarchical %||% list())) {
    y <- sp$response; blks <- sp$blocks
    if (is.null(y) || !y %in% names(df) || length(blks) < 2) next
    all_vars <- unlist(blks); all_vars <- intersect(all_vars, names(df))
    r <- tryCatch(hierarchical_regression(blks, df[, c(y, all_vars)], y),
                  error = function(e) list(error = conditionMessage(e)))
    result$hierarchical[[y]] <- r
  }

  # ── 3. Logistic Binary ──────────────────────────────
  for (sp in (plan$logistic %||% list())) {
    y <- sp$response; xs <- unlist(sp$predictors)
    if (is.null(y) || !y %in% names(df)) next
    xs <- intersect(xs, names(df)); if (length(xs) == 0) next
    f <- stats::as.formula(paste(y, "~", paste(xs, collapse = " + ")))
    r <- tryCatch(logistic_regression(f, df[, c(y, xs)]),
                  error = function(e) list(error = conditionMessage(e)))
    result$logistic[[paste0(y, "__by__", paste(xs, collapse = "_"))]] <- r
  }

  # ── 4. Multinomial ──────────────────────────────────
  for (sp in (plan$multinomial %||% list())) {
    y <- sp$response; xs <- unlist(sp$predictors)
    if (is.null(y) || !y %in% names(df)) next
    xs <- intersect(xs, names(df)); if (length(xs) == 0) next
    f <- stats::as.formula(paste(y, "~", paste(xs, collapse = " + ")))
    r <- tryCatch(multinomial_logistic(f, df[, c(y, xs)]),
                  error = function(e) list(error = conditionMessage(e)))
    result$multinomial[[y]] <- r
  }

  # ── 5. Poisson ──────────────────────────────────────
  for (sp in (plan$poisson %||% list())) {
    y <- sp$response; xs <- unlist(sp$predictors)
    if (is.null(y) || !y %in% names(df)) next
    xs <- intersect(xs, names(df)); if (length(xs) == 0) next
    f <- stats::as.formula(paste(y, "~", paste(xs, collapse = " + ")))
    r <- tryCatch(poisson_regression(f, df[, c(y, xs)]),
                  error = function(e) list(error = conditionMessage(e)))
    result$poisson[[y]] <- r
  }

  result$meta <- list(
    survey_id = survey_id, n_total = nrow(df),
    n_linear = length(result$linear), n_logistic = length(result$logistic),
    n_hierarchical = length(result$hierarchical),
    n_multinomial = length(result$multinomial),
    n_poisson = length(result$poisson),
    ts = format(Sys.time())
  )

  suffix <- if (survey_id == "survey1") "s1" else "s2"
  out <- sprintf("output/results/regression_%s.rds", suffix)
  saveRDS(result, out)
  cat(sprintf("[regression] %s → %s  (lin %d / log %d / hier %d / mn %d / poi %d)\n",
              survey_id, out, result$meta$n_linear, result$meta$n_logistic,
              result$meta$n_hierarchical, result$meta$n_multinomial, result$meta$n_poisson))
}

surveys <- target_surveys()
for (s in surveys) run_for_survey(s)
message("回归分析完成")
