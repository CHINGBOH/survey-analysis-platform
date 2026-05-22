#!/usr/bin/env Rscript
# 02-analyze/reliability.R — 直接从 respondents 宽表读 Likert
.libPaths(c("~/R/libs", .libPaths()))
library(DBI); library(RSQLite); library(psych); source("lib/utils.R"); module_header("信度分析")

for (survey_id in target_surveys()) {
  con <- dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  likert <- dbGetQuery(con, sprintf("SELECT ai_accept, meta_accept, green_accept, second_accept FROM respondents WHERE survey='%s'", survey_id))
  dbDisconnect(con)
  likert <- na.omit(likert)
  if (nrow(likert) < 5) { saveRDS(list(error="样本不足"), sprintf("output/results/reliability_%s.rds", if(survey_id=="survey1")"s1" else "s2")); next }
  a <- alpha(likert); sp <- splitHalf(likert)
  r <- list(alpha_raw=a$total$raw_alpha, alpha_std=a$total$std.alpha, guttman_l6=a$total$G6,
    item_drop=round(a$alpha.drop$raw_alpha,4), split_sb=sp$spearman.brown, n_items=ncol(likert))
  saveRDS(r, sprintf("output/results/reliability_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("信度分析完成")
