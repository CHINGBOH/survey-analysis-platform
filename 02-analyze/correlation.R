#!/usr/bin/env Rscript
# 02-analyze/correlation.R — 相关分析（SQLite）
source("lib/spss_tables.R"); source("lib/db.R"); source("lib/utils.R"); module_header("相关分析")
for (sid in c("survey1","survey2")) {
  df <- read_respondents(sid)
  cv <- df %>% dplyr::select(where(is.numeric)) %>% dplyr::select(-matches("bin|duration|impulse|env_will|speeder")) %>% na.omit()
  r <- list(pearson=round(cor(cv,method="pearson"),3), spearman=round(cor(cv,method="spearman"),3))
  saveRDS(r, sprintf("output/results/correlation_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("相关分析完成")
