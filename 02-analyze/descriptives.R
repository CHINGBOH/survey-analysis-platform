#!/usr/bin/env Rscript
# 02-analyze/descriptives.R — SQLite 两表合并版本
.libPaths(c("~/R/libs", .libPaths()))
library(DBI); library(RSQLite); library(psych)
source("lib/utils.R"); module_header("描述统计")

for (survey_id in c("survey1","survey2")) {
  con <- dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  on.exit(dbDisconnect(con))

  # 频率分布（respondents 宽表）
  for (v in c("gender","age_group","status","used_voucher")) {
    tbl <- dbGetQuery(con, sprintf("SELECT %s AS 类别, COUNT(*) AS 频数, ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM respondents WHERE survey='%s'),1) AS 百分比 FROM respondents WHERE survey='%s' AND %s IS NOT NULL GROUP BY %s ORDER BY 频数 DESC", v, survey_id, survey_id, v, v))
    cat(sprintf("\n%s:\n", v)); print(tbl)
  }

  # 描述统计：pivot 数值变量（respondents 宽表 + responses 长表 pivot）
  num_df <- dbGetQuery(con, sprintf("SELECT impact_num, extra_spend, saving_amt, attention_num, dynamic_num FROM respondents WHERE survey='%s'", survey_id))
  # 从 responses pivot Likert 变量
  likert <- dbGetQuery(con, "SELECT respondent_id, variable, value FROM responses WHERE category='likert'")
  if (nrow(likert) > 0) {
    likert_wide <- reshape(likert, idvar="respondent_id", timevar="variable", direction="wide")
    names(likert_wide) <- sub("^value\\.", "", names(likert_wide))
    num_df <- cbind(num_df, likert_wide[match(1:nrow(num_df), likert_wide$respondent_id), setdiff(names(likert_wide), "respondent_id")])
  }
  desc <- psych::describe(num_df)
  desc_tbl <- round(desc[,c("n","mean","sd","median","min","max","skew","kurtosis","se")], 3)
  desc_tbl$变量 <- rownames(desc_tbl)
  print(as.data.frame(desc_tbl))

  # 正态性
  for (vn in intersect(c("impact_num","ai_accept","meta_accept","green_accept","second_accept"), names(num_df))) {
    x <- na.omit(num_df[[vn]])
    if (length(x) > 3) {
      sw <- shapiro.test(x)
      cat(sprintf("SW %s: W=%.4f p=%.4f\n", vn, sw$statistic, sw$p.value))
    }
  }

  dir.create("output/results", showWarnings=FALSE, recursive=TRUE)
  n_total <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM respondents WHERE survey='%s'", survey_id))$n
  result <- list(descriptives=desc_tbl, stats=list(n=n_total))
  saveRDS(result, sprintf("output/results/descriptives_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("描述统计完成")
