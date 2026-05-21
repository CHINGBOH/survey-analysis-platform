#!/usr/bin/env Rscript
# 03-integrate/compile.R — 收集所有模块结果，编译为统一数据结构
source("lib/utils.R")
module_header("结果整合")

modules <- c("descriptives","crosstabs","ttest","anova","correlation",
             "reliability","factor_analysis","regression",
             "mediation","moderation","cluster","power_bootstrap")

all_results <- list()

for (survey_label in c("s1","s2")) {
  survey_results <- list()
  for (mod in modules) {
    path <- sprintf("output/results/%s_%s.rds", mod, survey_label)
    if (file.exists(path)) {
      survey_results[[mod]] <- readRDS(path)
    } else {
      warning("Missing: ", path)
      survey_results[[mod]] <- list(error="not found")
    }
  }
  all_results[[survey_label]] <- survey_results
}

# 附加元数据
all_results$meta <- list(
  date = Sys.Date(),
  modules = modules,
  surveys = c("survey1"="调查一（大学生为主 208份）","survey2"="调查二（学生+在职混合 205份）")
)

saveRDS(all_results, "output/results/compiled.rds")
message(sprintf("整合完成: %d 模块 × 2 调查", length(modules)))
message("Saved: output/results/compiled.rds")
