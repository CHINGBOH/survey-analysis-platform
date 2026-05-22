#!/usr/bin/env Rscript
# 02-analyze/crosstabs.R — SPSS 等价 Crosstabs (generic)
#
# plan.json:
#   {"crosstabs": {"pairs": [["gender","used_voucher"], ["age_group","status"]]}}
#
# 无 plan 时自动:所有低基数分类列两两配对(最多 12 对)
#
# 输出 output/results/crosstabs_<sid>.rds:
#   命名 list: <row>_<col> → list(crosstab, expected, std_residuals, measures, title)

.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/inferential.R")
module_header("交叉表与关联度量 (SPSS 等价)")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$crosstabs, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db)); DBI::dbReadTable(db, "respondents")
}

auto_detect_cat <- function(df) {
  cat_vars <- names(df)[vapply(df, function(v) {
    u <- unique(v[!is.na(v)])
    length(u) >= 2 && length(u) <= 8 &&
      (is.character(v) || is.factor(v) || is.logical(v) ||
       (is.numeric(v) && all(u %in% c(0, 1))))
  }, logical(1))]
  setdiff(cat_vars, c("id", "respondent_id"))
}

run_for_survey <- function(survey_id) {
  cat(sprintf("\n[crosstabs] %s ─────────────────────\n", survey_id))
  df <- load_wide(survey_id); plan <- read_plan()
  cat_vars <- auto_detect_cat(df)

  pairs <- plan$pairs
  if (is.null(pairs) || length(pairs) == 0) {
    pairs <- list()
    if (length(cat_vars) >= 2) {
      for (i in 1:(length(cat_vars) - 1)) for (j in (i + 1):length(cat_vars)) {
        pairs[[length(pairs) + 1]] <- c(cat_vars[i], cat_vars[j])
        if (length(pairs) >= 12) break
      }
      if (length(pairs) >= 12) pairs <- pairs[1:12]
    }
  }

  result <- list()
  for (pr in pairs) {
    r <- pr[[1]]; c <- pr[[2]]
    if (!r %in% names(df) || !c %in% names(df)) next
    res <- tryCatch(chisq_full(df[[r]], df[[c]], row_name = r, col_name = c),
                    error = function(e) NULL)
    if (!is.null(res)) result[[paste0(r, "_", c)]] <- res
  }

  result$.meta <- list(survey_id = survey_id, n_total = nrow(df),
                       n_pairs = length(result), ts = format(Sys.time()))

  suffix <- if (survey_id == "survey1") "s1" else "s2"
  out <- sprintf("output/results/crosstabs_%s.rds", suffix)
  saveRDS(result, out)
  cat(sprintf("[crosstabs] %s → %s  (%d pairs)\n", survey_id, out, length(result) - 1))
}

surveys <- target_surveys()
for (s in surveys) run_for_survey(s)
message("交叉表完成")
