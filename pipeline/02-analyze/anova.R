#!/usr/bin/env Rscript
# 02-analyze/anova.R — SPSS 等价单因素 ANOVA (generic)
#
# plan.json:
#   {"anova": {"specs": [{"dv": "extra_spend", "group": "age_group"}, ...]}}
#
# 无 plan 时自动:数值列 × 多分类列(3-8 levels)
#
# 输出 output/results/anova_<sid>.rds:
#   $summaries        rbind(每个 spec 一行)
#   $group_means      命名 list(spec_id → df)
#   $tukey            命名 list
#   $games_howell     命名 list
#   $kruskal          rbind
#   $dunn             命名 list
#   $meta

.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source("lib/utils.R"); source("lib/inferential.R")
module_header("ANOVA (SPSS 等价单因素)")

`%||%` <- function(a, b) if (is.null(a)) b else a

read_plan <- function() {
  pth <- "output/results/analysis_plan.json"
  if (!file.exists(pth) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(pth, simplifyVector = FALSE)$anova, error = function(e) list())
}

load_wide <- function(survey_id) {
  db <- DBI::dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(DBI::dbDisconnect(db)); DBI::dbReadTable(db, "respondents")
}

auto_detect <- function(df) {
  numeric_vars <- names(df)[vapply(df, is.numeric, logical(1))]
  numeric_vars <- setdiff(numeric_vars, c("id", "respondent_id"))
  numeric_vars <- numeric_vars[vapply(df[numeric_vars], function(v) {
    v <- v[!is.na(v)]; length(unique(v)) > 3 && length(v) >= 10
  }, logical(1))]
  multi_vars <- names(df)[vapply(df, function(v) {
    u <- unique(v[!is.na(v)])
    length(u) >= 3 && length(u) <= 8 && (is.character(v) || is.factor(v))
  }, logical(1))]
  list(numeric = numeric_vars, multi = multi_vars)
}

run_for_survey <- function(survey_id) {
  cat(sprintf("\n[anova] %s ─────────────────────\n", survey_id))
  df <- load_wide(survey_id); plan <- read_plan(); det <- auto_detect(df)

  specs <- plan$specs
  if (is.null(specs)) {
    specs <- list()
    for (g in head(det$multi, 3)) for (d in head(det$numeric, 4)) {
      specs[[length(specs) + 1]] <- list(dv = d, group = g)
    }
  }

  sum_rows <- list(); gm_list <- list(); tk_list <- list()
  gh_list  <- list(); kw_rows <- list(); dn_list <- list()

  for (sp in specs) {
    d <- sp$dv; g <- sp$group
    if (!d %in% names(df) || !g %in% names(df)) next
    key <- sprintf("%s__by__%s", d, g)

    aov_r <- one_way_anova(df[[d]], df[[g]], dv_name = d, group_name = g)
    if (is.null(aov_r)) next
    sum_rows[[length(sum_rows) + 1]] <- aov_r$summary
    gm_list[[key]] <- aov_r$group_means

    tk <- tukey_posthoc(aov_r$aov_obj)
    if (!is.null(tk)) tk_list[[key]] <- tk
    gh <- games_howell(df[[d]], df[[g]])
    if (!is.null(gh)) gh_list[[key]] <- gh

    kw <- kruskal_wallis(df[[d]], df[[g]], dv_name = d, group_name = g)
    if (!is.null(kw)) kw_rows[[length(kw_rows) + 1]] <- kw
    dn <- dunn_posthoc(df[[d]], df[[g]])
    if (!is.null(dn)) dn_list[[key]] <- dn
  }

  result <- list(
    summaries = if (length(sum_rows) > 0) do.call(rbind, sum_rows) else NULL,
    group_means = gm_list,
    tukey = tk_list,
    games_howell = gh_list,
    kruskal = if (length(kw_rows) > 0) do.call(rbind, kw_rows) else NULL,
    dunn = dn_list,
    meta = list(survey_id = survey_id, n_total = nrow(df),
                n_specs = length(specs), ts = format(Sys.time()))
  )

  suffix <- if (survey_id == "survey1") "s1" else "s2"
  out <- sprintf("output/results/anova_%s.rds", suffix)
  saveRDS(result, out)
  cat(sprintf("[anova] %s → %s  (%d specs)\n", survey_id, out, length(specs)))
}

surveys <- target_surveys()
for (s in surveys) run_for_survey(s)
message("ANOVA 完成")
