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
