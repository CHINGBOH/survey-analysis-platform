#!/usr/bin/env Rscript
# 01-clean/clean_survey1.R
# 调查一 清洗编码：文本→数值
# 输入: data/raw/问卷数据_完整版_209条.xlsx
# 输出: data/cleaned/survey1.rds

source("lib/encode.R")
source("lib/utils.R")

module_header("调查一 清洗编码")

df_raw <- load_survey("data/raw/问卷数据_完整版_209条.xlsx")
message(sprintf("原始: %d × %d", nrow(df_raw), ncol(df_raw)))

df_clean <- encode_survey1(df_raw)

message(sprintf("清洗后: %d × %d", nrow(df_clean), ncol(df_clean)))
message("变量列表:")
for (nm in names(df_clean)) {
  na_count <- sum(is.na(df_clean[[nm]]))
  na_pct <- round(na_count / nrow(df_clean) * 100, 1)
  message(sprintf("  %-20s NA=%3d (%.1f%%)", nm, na_count, na_pct))
}

if (!dir.exists("data/cleaned")) dir.create("data/cleaned", recursive=TRUE)
saveRDS(df_clean, "data/cleaned/survey1.rds")
message("Saved: data/cleaned/survey1.rds")
