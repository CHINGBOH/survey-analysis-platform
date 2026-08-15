#!/usr/bin/env Rscript
# 02-analyze/reliability.R — SPSS 等价 Cronbach α + 分半 + 项目分析 (generic)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/multivariate.R")
module_header("信度 + 项目分析")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$reliability, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db))
  DBI::dbReadTable(db, "respondents")
}

auto_likert_scales <- function(df) {
  candidates <- names(df)[vapply(df, function(v) {
    if (!is.numeric(v)) return(FALSE)
    u <- unique(v[!is.na(v)])
    length(u) >= 3 && length(u) <= 7 && all(u >= 0 & u <= 10)
  }, logical(1))]
  candidates <- setdiff(candidates, c("id", "respondent_id"))
  if (length(candidates) >= 2) list(list(name = "auto_likert", items = candidates)) else list()
}

run_for_survey <- function(survey_id) {
  df <- load_wide(survey_id)
  plan <- read_plan()
  specs <- plan$specs %||% auto_likert_scales(df)

  scales_out <- list()
  for (sp in specs) {
    nm <- sp$name %||% "default"
    its <- intersect(unlist(sp$items), names(df))
    if (length(its) < 2) next
    scales_out[[nm]] <- reliability_analysis(df[, its, drop = FALSE], items = its)
  }

  res <- list(
    scales = scales_out,
    meta = list(survey_id = survey_id, n_total = nrow(df),
                n_scales = length(scales_out), ts = format(Sys.time()))
  )
  out <- sprintf("output/results/reliability_%s.rds", survey_suffix(survey_id))
  saveRDS(res, out)
  cat(sprintf("[reliability] %s → %s  (%d scales)\n", survey_id, out, length(scales_out)))
}

for (s in target_surveys()) run_for_survey(s)
message("信度完成")
