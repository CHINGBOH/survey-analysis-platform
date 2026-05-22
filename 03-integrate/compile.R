#!/usr/bin/env Rscript
# 03-integrate/compile.R — 收集结果并编译为统一数据结构
# 读取 output/results/plan.json（若存在）决定编译哪些 survey × 模块；
# 否则回退为"编译所有已存在的结果"。
source("lib/utils.R")
suppressMessages(library(jsonlite))
module_header("结果整合")

ALL_MODULES <- c("descriptives","crosstabs","ttest","anova","correlation",
                 "reliability","factor_analysis","regression",
                 "mediation","moderation","cluster","power_bootstrap")

plan_path <- "output/results/plan.json"
if (file.exists(plan_path)) {
  plan <- jsonlite::fromJSON(plan_path)
  surveys <- plan$surveys
  modules <- plan$modules
  compare <- isTRUE(plan$compare)
  focus   <- if (is.null(plan$focus)) "" else plan$focus
  message(sprintf("按计划编译: surveys=%s, %d 模块", paste(surveys, collapse="+"), length(modules)))
} else {
  # 回退：扫描已存在的结果文件
  surveys <- c("survey1","survey2")
  modules <- ALL_MODULES
  compare <- TRUE
  focus   <- ""
  message("无 plan.json，回退为编译全部已存在结果")
}

survey_labels <- setNames(
  ifelse(surveys == "survey1", "s1", "s2"),
  surveys
)

all_results <- list()
for (sid in surveys) {
  lbl <- survey_labels[[sid]]
  survey_results <- list()
  for (mod in modules) {
    path <- sprintf("output/results/%s_%s.rds", mod, lbl)
    if (file.exists(path)) {
      survey_results[[mod]] <- readRDS(path)
    }
    # 缺失则不放入（动态报告只渲染实际跑过的模块）
  }
  all_results[[lbl]] <- survey_results
}

survey_names <- c(
  "survey1" = "调查一（大学生为主 208份）",
  "survey2" = "调查二（学生+在职混合 205份）"
)

all_results$meta <- list(
  date = as.character(Sys.Date()),
  surveys = surveys,                          # 实际编译的 survey id
  survey_labels = unname(survey_labels),      # 对应 s1/s2
  survey_names = survey_names[surveys],
  modules = modules,                          # 实际编译的模块
  compare = compare,
  focus = focus
)

saveRDS(all_results, "output/results/compiled.rds")
message(sprintf("整合完成: %d 调查 × %d 模块", length(surveys), length(modules)))
message("Saved: output/results/compiled.rds")
