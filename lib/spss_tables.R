# lib/spss_tables.R — SPSS 风格表格生成器
# 统一输出格式：list(tables, stats, notes)

library(knitr)

#' 频率分布表（SPSS Frequencies 输出格式）
freq_table <- function(x, var_name="") {
  tbl <- as.data.frame(table(x, useNA="no"))
  names(tbl) <- c("类别", "频数")
  tbl$百分比 <- round(prop.table(tbl$频数) * 100, 1)
  tbl$有效百分比 <- round(tbl$频数 / sum(tbl$频数) * 100, 1)
  tbl$累计百分比 <- cumsum(tbl$有效百分比)
  list(table = tbl, title = paste(var_name, "频率分布"))
}

#' 描述统计表（SPSS Descriptives 格式）
desc_table <- function(df, vars=NULL) {
  if (is.null(vars)) vars <- names(df)
  d <- psych::describe(df[, vars, drop=FALSE])
  tbl <- round(d[, c("n","mean","sd","median","min","max","skew","kurtosis","se")], 3)
  list(table = tibble::rownames_to_column(tbl, "变量"), title = "描述统计量")
}

#' 交叉表 + 卡方（SPSS Crosstabs 格式）
crosstab_chi <- function(x, y, row_name="行", col_name="列") {
  ct <- table(x, y)
  ch <- chisq.test(ct)
  n_total <- sum(ct)
  min_dim <- min(nrow(ct), ncol(ct)) - 1

  measures <- data.frame(
    指标 = c("Pearson χ²","自由度","p值","Phi系数","Cramer's V","列联系数"),
    数值 = c(
      round(ch$statistic, 3), ch$parameter, round(ch$p.value, 4),
      round(sqrt(ch$statistic / n_total), 4),
      round(sqrt(ch$statistic / (n_total * min_dim)), 4),
      round(sqrt(ch$statistic / (ch$statistic + n_total)), 4)
    )
  )

  list(
    crosstab = ct,
    measures = measures,
    title = paste(row_name, "×", col_name, "交叉表")
  )
}

#' ANOVA 表（SPSS One-Way ANOVA 格式）
anova_table <- function(aov_obj) {
  s <- summary(aov_obj)[[1]]
  ss <- s$`Sum Sq`; ms <- s$`Mean Sq`
  eta2 <- ss[1] / sum(ss)
  omega2 <- (ss[1] - s$Df[1] * ms[2]) / (sum(ss) + ms[2])

  tbl <- data.frame(
    来源 = c("组间", "组内", "总计"),
    SS = round(c(ss[1], ss[2], sum(ss)), 3),
    df = c(s$Df[1], s$Df[2], sum(s$Df)),
    MS = round(c(ms[1], ms[2], NA), 3),
    F值 = c(round(s$`F value`[1], 3), "", ""),
    p值 = c(round(s$`Pr(>F)`[1], 4), "", "")
  )

  list(
    table = tbl,
    eta2 = eta2,
    omega2 = omega2,
    title = "单因素方差分析"
  )
}

#' 独立样本 t 检验结果（SPSS Independent Samples T Test 格式）
ttest_table <- function(formula, data) {
  t <- t.test(formula, data=data)
  lev <- car::leveneTest(formula, data=data)

  # 组统计量
  vars <- all.vars(formula)
  grp <- data[[vars[2]]]
  dv  <- data[[vars[1]]]
  group_stats <- data.frame(
    levels = levels(factor(grp)),
    N = as.numeric(table(factor(grp))),
    M = round(tapply(dv, factor(grp), mean, na.rm=TRUE), 3),
    SD = round(tapply(dv, factor(grp), sd, na.rm=TRUE), 3)
  )
  names(group_stats)[1] <- vars[2]

  # Cohen's d
  d_val <- tryCatch(
    effsize::cohen.d(formula, data=data)$estimate,
    error = function(e) NA
  )

  list(
    group_stats = group_stats,
    levene_F = round(lev$`F value`[1], 3),
    levene_p = round(lev$`Pr(>F)`[1], 4),
    t_val = round(t$statistic, 3),
    t_df   = round(t$parameter, 0),
    t_p    = round(t$p.value, 4),
    cohens_d = round(d_val, 4),
    ci_lower = round(t$conf.int[1], 3),
    ci_upper = round(t$conf.int[2], 3),
    title = paste(vars[2], "×", vars[1], "独立样本t检验")
  )
}

#' 保存模块结果
#' @param result list(tables, stats, notes)
#' @param module_name 模块名（如 "descriptives"）
#' @param survey_id   调查编号（"s1" 或 "s2"）
save_result <- function(result, module_name, survey_id) {
  out_dir <- "output/results"
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive=TRUE)
  path <- file.path(out_dir, paste0(module_name, "_", survey_id, ".rds"))
  saveRDS(result, path)
  message("Saved: ", path)
  invisible(path)
}

#' 加载模块结果
load_result <- function(module_name, survey_id) {
  path <- file.path("output/results", paste0(module_name, "_", survey_id, ".rds"))
  if (file.exists(path)) readRDS(path) else NULL
}
