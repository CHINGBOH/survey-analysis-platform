#!/usr/bin/env Rscript
# 02-analyze/rds_to_json.R — 把任意 RDS 转 JSON,供 Python 解读侧消费
# 用法: Rscript 02-analyze/rds_to_json.R <rds_path> [max_rows]
# 限制 data.frame 行数,避免 LLM 上下文爆炸; list 中嵌套结构原样保留

suppressPackageStartupMessages({
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("usage: rds_to_json.R <rds_path> [max_rows=30]")
}
rds_path <- args[1]
max_rows <- if (length(args) >= 2) as.integer(args[2]) else 30L

if (!file.exists(rds_path)) {
  stop(sprintf("RDS not found: %s", rds_path))
}

obj <- readRDS(rds_path)

# 递归裁剪 data.frame 行数,保留全部列
trim <- function(x) {
  if (is.data.frame(x)) {
    n <- nrow(x)
    if (n > max_rows) {
      attr(x, "truncated_from") <- n
      x <- head(x, max_rows)
    }
    return(x)
  }
  if (is.list(x)) {
    return(lapply(x, trim))
  }
  return(x)
}

obj <- trim(obj)

cat(toJSON(obj, auto_unbox = TRUE, na = "null", null = "null", digits = 6, pretty = FALSE))
