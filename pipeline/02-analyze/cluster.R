#!/usr/bin/env Rscript
# 02-analyze/cluster.R — SPSS 等价 KMeans / 层次聚类 / 判别 (generic)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/multivariate.R")
module_header("聚类 + 判别")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$cluster, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db))
  DBI::dbReadTable(db, "respondents")
}

auto_numeric_vars <- function(df) {
  v <- names(df)[vapply(df, is.numeric, logical(1))]
  v <- setdiff(v, c("id", "respondent_id"))
  v[vapply(df[v], function(x) length(unique(x[!is.na(x)])) > 3 && length(x[!is.na(x)]) >= 30, logical(1))]
}

run_for_survey <- function(survey_id) {
  df <- load_wide(survey_id)
  plan <- read_plan()
  specs <- plan$specs %||% list()
  if (length(specs) == 0) {
    nv <- head(auto_numeric_vars(df), 6)
    if (length(nv) >= 2) specs <- list(list(name = "auto", vars = nv, k = 3))
  }

  km_list <- list(); hc_list <- list(); ld_list <- list()
  for (sp in specs) {
    nm <- sp$name %||% paste(unlist(sp$vars), collapse = "_")
    vars <- intersect(unlist(sp$vars), names(df))
    if (length(vars) < 2) next
    sub <- df[, vars, drop = FALSE]
    k <- sp$k %||% 3
    km_list[[nm]] <- kmeans_cluster(sub, k = k)
    hc_list[[nm]] <- hclust_cluster(sub, k = k, method = sp$hc_method %||% "ward.D2")
    # 用 kmeans 标签做判别交叉验证
    if (!is.null(km_list[[nm]]$cluster_assignment)) {
      lda_df <- na.omit(sub)
      if (nrow(lda_df) == length(km_list[[nm]]$cluster_assignment)) {
        lda_df$cluster <- factor(km_list[[nm]]$cluster_assignment)
        ld_list[[nm]] <- discriminant_analysis(lda_df, "cluster", vars)
      }
    }
  }

  res <- list(
    kmeans = km_list, hclust = hc_list, discriminant = ld_list,
    meta = list(survey_id = survey_id, n_total = nrow(df),
                n_specs = length(specs), ts = format(Sys.time()))
  )
  out <- sprintf("output/results/cluster_%s.rds", survey_suffix(survey_id))
  saveRDS(res, out)
  cat(sprintf("[cluster] %s → %s  (%d specs)\n", survey_id, out, length(specs)))
}

for (s in target_surveys()) run_for_survey(s)
message("聚类完成")
