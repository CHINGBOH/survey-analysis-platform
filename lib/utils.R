# lib/utils.R — 通用工具函数

#' 安全执行：捕获错误并返回 NA 结果
safe_run <- function(expr, fallback=NULL) {
  tryCatch(expr, error=function(e) {
    warning("Module error: ", e$message)
    fallback
  })
}

#' 打印模块标题
module_header <- function(name) {
  msg <- sprintf("\n========== %s ==========", name)
  message(msg)
}

#' 清理数值向量（去 NA、去 Inf）
clean_numeric <- function(x) {
  x[is.finite(x)]
}

#' 目标调查：从命令行参数读取要分析的 survey
#' Rscript module.R survey1        → 只跑 survey1
#' Rscript module.R survey1 survey2 → 跑两个
#' Rscript module.R                → 默认两个都跑
target_surveys <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  sel <- args[args %in% c("survey1", "survey2")]
  if (length(sel) >= 1) sel else c("survey1", "survey2")
}

#' survey_id → 结果文件后缀 (survey1→s1, survey2→s2)
survey_suffix <- function(survey_id) {
  if (survey_id == "survey1") "s1" else "s2"
}
