#!/usr/bin/env Rscript
# 02-analyze/factor_analysis.R — SPSS 等价 PCA / EFA (generic)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/multivariate.R")
module_header("因子分析 (PCA / EFA)")

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$factor_analysis, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db))
  DBI::dbReadTable(db, "respondents")
}

auto_likert_items <- function(df) {
  candidates <- names(df)[vapply(df, function(v) {
    if (!is.numeric(v)) return(FALSE)
    u <- unique(v[!is.na(v)])
    length(u) >= 3 && length(u) <= 7 && all(u >= 0 & u <= 10)
  }, logical(1))]
  candidates <- setdiff(candidates, c("id", "respondent_id"))
  candidates
}

run_for_survey <- function(survey_id) {
  df <- load_wide(survey_id)
  plan <- read_plan()
  items_specs <- plan$specs %||% list()
  if (length(items_specs) == 0) {
    items <- auto_likert_items(df)
    if (length(items) >= 3) items_specs <- list(list(name = "auto_likert", items = items))
  }

  pca_out <- list(); efa_out <- list(); kmo_out <- list()
  for (sp in items_specs) {
    nm <- sp$name %||% "default"
    its <- intersect(unlist(sp$items), names(df))
    if (length(its) < 2) next
    sub <- df[, its, drop = FALSE]
    kmo_out[[nm]] <- kmo_bartlett(sub)
    pca_out[[nm]] <- pca_analysis(sub, n_factors = sp$n_factors %||% NULL,
                                  rotate = sp$rotate %||% "varimax")
    if (length(its) >= 3 && nrow(na.omit(sub)) >= 30) {
      efa_out[[nm]] <- efa_analysis(sub, n_factors = sp$n_factors %||% NULL,
                                    rotate = sp$rotate %||% "varimax",
                                    fm = sp$fm %||% "pa")
    }
  }

  `%||%` <- function(a, b) if (is.null(a)) b else a
  res <- list(
    kmo = kmo_out, pca = pca_out, efa = efa_out,
    meta = list(survey_id = survey_id, n_total = nrow(df),
                n_specs = length(items_specs), ts = format(Sys.time()))
  )
  out <- sprintf("output/results/factor_analysis_%s.rds", survey_suffix(survey_id))
  saveRDS(res, out)
  cat(sprintf("[factor] %s → %s  (%d specs)\n", survey_id, out, length(items_specs)))
}

`%||%` <- function(a, b) if (is.null(a)) b else a
for (s in target_surveys()) run_for_survey(s)
message("因子分析完成")
