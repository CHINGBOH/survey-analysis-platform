#!/usr/bin/env Rscript
# 02-analyze/ttest.R — t检验（SQLite）
source("lib/spss_tables.R"); source("lib/db.R"); source("lib/utils.R")
module_header("t检验")

for (survey_id in target_surveys()) {
  df <- read_respondents(survey_id)
  t1 <- t.test(df$impact_num, mu=3)
  t2 <- ttest_table(impact_num ~ gender, data=df)
  mw <- wilcox.test(impact_num ~ gender, data=df)
  result <- list(one_sample=list(t=t1$statistic,df=t1$parameter,p=t1$p.value), independent=t2, mann_whitney=list(W=mw$statistic,p=mw$p.value))
  saveRDS(result, sprintf("output/results/ttest_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("t检验完成")
