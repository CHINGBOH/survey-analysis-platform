#!/usr/bin/env Rscript
# 03-integrate/read_result.R — 读取单个模块结果 .rds，输出 JSON
# 用法: Rscript read_result.R output/results/reliability_s1.rds
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("{}"); quit(status = 0) }
path <- args[1]
if (!file.exists(path)) { cat(sprintf('{"error":"file not found: %s"}', path)); quit(status = 0) }
suppressMessages(library(jsonlite))
x <- readRDS(path)
cat(toJSON(x, auto_unbox = TRUE, digits = 6, na = "string", force = TRUE))
