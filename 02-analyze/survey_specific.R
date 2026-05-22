#!/usr/bin/env Rscript
# 02-analyze/survey_specific.R — 问卷专用 (Likert / 缺失 / 异常 / 文本)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/survey_specific.R")
module_header("问卷专用分析")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$survey_specific, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db))
  DBI::dbReadTable(db, "respondents")
}

auto_likert <- function(df) {
  names(df)[vapply(df, function(v) {
    if (!is.numeric(v)) return(FALSE)
    u <- unique(v[!is.na(v)])
    length(u) >= 3 && length(u) <= 7 && all(u >= 0 & u <= 10)
  }, logical(1))]
}

auto_numeric <- function(df) {
  v <- names(df)[vapply(df, is.numeric, logical(1))]
  setdiff(v, c("id", "respondent_id"))
}

auto_text <- function(df) {
  names(df)[vapply(df, function(v) {
    is.character(v) && mean(nchar(v[!is.na(v)]), na.rm = TRUE) >= 5
  }, logical(1))]
}

run_for_survey <- function(survey_id) {
  df <- load_wide(survey_id)
  plan <- read_plan()

  # Likert
  likert_vars <- plan$likert_vars %||% auto_likert(df)
  scale_max <- plan$scale_max %||% 5
  lik_sum <- list(); lik_dist <- list()
  for (v in likert_vars) {
    s <- likert_summary(df[[v]], var_name = v, scale_max = scale_max)
    if (!is.null(s)) lik_sum[[length(lik_sum) + 1]] <- s
    d <- likert_distribution(df[[v]], var_name = v, scale_max = scale_max)
    if (!is.null(d)) lik_dist[[length(lik_dist) + 1]] <- d
  }
  likert_summary_df <- if (length(lik_sum) > 0) do.call(rbind, lik_sum) else NULL
  likert_dist_df <- if (length(lik_dist) > 0) do.call(rbind, lik_dist) else NULL

  # 缺失
  missing_df <- missing_pattern(df)

  # 异常值 (数值列前 8 个)
  num_vars <- head(auto_numeric(df), 8)
  out_z <- list(); out_iqr <- list()
  for (v in num_vars) {
    r1 <- outliers_zscore(df[[v]])
    r2 <- outliers_iqr(df[[v]])
    out_z[[length(out_z) + 1]] <- data.frame(变量 = v, n异常 = r1$n_outliers, 阈值 = r1$threshold, row.names = NULL)
    out_iqr[[length(out_iqr) + 1]] <- data.frame(变量 = v, n异常 = r2$n_outliers, 下限 = r2$lower, 上限 = r2$upper, row.names = NULL)
  }
  z_df <- if (length(out_z) > 0) do.call(rbind, out_z) else NULL
  iqr_df <- if (length(out_iqr) > 0) do.call(rbind, out_iqr) else NULL

  # Mahalanobis (多元)
  maha <- if (length(num_vars) >= 2) outliers_mahalanobis(df[, num_vars, drop = FALSE]) else list(error = "数值列不足")

  # 文本
  txt_vars <- plan$text_vars %||% head(auto_text(df), 3)
  txt_stats <- list(); txt_sent <- list()
  for (v in txt_vars) {
    s <- text_basic_stats(df[[v]])
    if (!is.null(s)) { s$变量 <- v; txt_stats[[length(txt_stats) + 1]] <- s }
    sent <- text_sentiment(df[[v]])
    if (!is.null(sent)) { sent$变量 <- v; txt_sent[[length(txt_sent) + 1]] <- sent }
  }
  txt_df <- if (length(txt_stats) > 0) do.call(rbind, txt_stats) else NULL
  sent_df <- if (length(txt_sent) > 0) do.call(rbind, txt_sent) else NULL

  res <- list(
    likert = list(summary = likert_summary_df, distribution = likert_dist_df, scale_max = scale_max),
    missing = missing_df,
    outliers = list(zscore = z_df, iqr = iqr_df, mahalanobis = maha),
    text = list(stats = txt_df, sentiment = sent_df),
    meta = list(survey_id = survey_id, n_total = nrow(df),
                n_likert = length(likert_vars), n_text = length(txt_vars),
                ts = format(Sys.time()))
  )
  out <- sprintf("output/results/survey_specific_%s.rds", survey_suffix(survey_id))
  saveRDS(res, out)
  cat(sprintf("[survey_specific] %s → %s\n", survey_id, out))
}

for (s in target_surveys()) run_for_survey(s)
message("问卷专用分析完成")
