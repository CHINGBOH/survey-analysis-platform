#!/usr/bin/env Rscript
# 02-analyze/crosstabs.R — 交叉表 + 卡方（SQLite）
source("lib/spss_tables.R"); source("lib/db.R"); source("lib/utils.R")
module_header("交叉表与关联度量")

for (survey_id in target_surveys()) {
  df <- read_respondents(survey_id)
  ct_gender <- crosstab_chi(df$gender, df$used_voucher, "性别", "使用消费券")
  ct_age    <- crosstab_chi(df$age_group, df$used_voucher, "年龄", "使用消费券")
  ct_status <- crosstab_chi(df$status, df$used_voucher, "身份", "使用消费券")
  result <- list(gender_use=ct_gender, age_use=ct_age, status_use=ct_status)
  saveRDS(result, sprintf("output/results/crosstabs_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("交叉表完成")
