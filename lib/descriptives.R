# lib/descriptives.R — 通用 SPSS 等价描述统计库
#
# 设计目标:对标 SPSS Analyze > Descriptive Statistics 全部子菜单
#   - Frequencies(频率): 频数 / 有效% / 累计%
#   - Descriptives(描述): mean/sd/median/min/max/range/skew/kurt/CV/SE
#   - Explore(分层描述): 按 group 拆分
#   - Crosstabs basics(交叉表基础): 频数+行%+列%(独立性检验在 02-analyze/crosstabs.R)
#
# 输入:任意 data.frame + 列名向量
# 输出:命名 list,每个元素都是 data.frame,可直接 saveRDS 后给 Quarto 渲染

# ── Dependency: psych for skew/kurt, dplyr/tidyr if available ────────
.has_pkg <- function(p) requireNamespace(p, quietly = TRUE)

# ── 1. Frequency table ──────────────────────────────────────────────
#' 频率分布表(SPSS Frequencies 等价)
#'
#' @param x 向量(任意类型,会强转 factor)
#' @param sort_by "freq" | "value" — 排序方式
#' @return data.frame(类别, 频数, 百分比, 有效百分比, 累计百分比)
freq_table <- function(x, sort_by = "freq") {
  n_total <- length(x)
  x_valid <- x[!is.na(x)]
  n_valid <- length(x_valid)
  n_missing <- n_total - n_valid

  if (n_valid == 0) {
    return(data.frame(
      类别 = character(0), 频数 = integer(0),
      百分比 = numeric(0), 有效百分比 = numeric(0), 累计百分比 = numeric(0)
    ))
  }

  tbl <- as.data.frame(table(x_valid, useNA = "no"), stringsAsFactors = FALSE)
  names(tbl) <- c("类别", "频数")

  if (identical(sort_by, "freq")) {
    tbl <- tbl[order(-tbl$频数), , drop = FALSE]
  } else {
    tbl <- tbl[order(tbl$类别), , drop = FALSE]
  }

  tbl$百分比 <- round(tbl$频数 / n_total * 100, 2)
  tbl$有效百分比 <- round(tbl$频数 / n_valid * 100, 2)
  tbl$累计百分比 <- round(cumsum(tbl$有效百分比), 2)

  # 缺失行(若有)
  if (n_missing > 0) {
    miss_row <- data.frame(
      类别 = "缺失",
      频数 = n_missing,
      百分比 = round(n_missing / n_total * 100, 2),
      有效百分比 = NA_real_,
      累计百分比 = NA_real_
    )
    tbl <- rbind(tbl, miss_row)
  }
  rownames(tbl) <- NULL
  tbl
}

# ── 2. Numeric descriptives ────────────────────────────────────────
#' 数值变量描述统计(SPSS Descriptives + Explore 等价)
#'
#' @param x 数值向量
#' @return 单行 data.frame(全部指标)
desc_one <- function(x) {
  x_num <- suppressWarnings(as.numeric(x))
  x_valid <- x_num[is.finite(x_num)]
  n_valid <- length(x_valid)
  n_missing <- length(x_num) - n_valid

  if (n_valid < 1) {
    return(data.frame(
      N = 0, 缺失 = n_missing, 均值 = NA_real_, 标准误 = NA_real_,
      中位数 = NA_real_, 众数 = NA_real_, 标准差 = NA_real_, 方差 = NA_real_,
      极差 = NA_real_, 最小值 = NA_real_, 最大值 = NA_real_,
      Q1 = NA_real_, Q3 = NA_real_, IQR = NA_real_,
      变异系数 = NA_real_, 偏度 = NA_real_, 偏度标准误 = NA_real_,
      峰度 = NA_real_, 峰度标准误 = NA_real_
    ))
  }

  q <- stats::quantile(x_valid, probs = c(0.25, 0.5, 0.75), na.rm = TRUE, names = FALSE)
  m <- mean(x_valid)
  sd_v <- if (n_valid > 1) stats::sd(x_valid) else NA_real_
  se_v <- if (!is.na(sd_v)) sd_v / sqrt(n_valid) else NA_real_

  # 众数:最频繁值(连续取多个会取第一个)
  tab <- table(x_valid)
  mode_v <- as.numeric(names(tab)[which.max(tab)])

  # 偏度/峰度(用 psych,若无则 fallback)
  if (.has_pkg("psych")) {
    sk <- psych::skew(x_valid, na.rm = TRUE)
    ku <- psych::kurtosi(x_valid, na.rm = TRUE)
  } else {
    n <- n_valid
    if (n > 2 && !is.na(sd_v) && sd_v > 0) {
      sk <- sum((x_valid - m)^3) / (n * sd_v^3)
      ku <- sum((x_valid - m)^4) / (n * sd_v^4) - 3
    } else {
      sk <- NA_real_; ku <- NA_real_
    }
  }

  # 偏度/峰度标准误(SPSS 公式)
  n <- n_valid
  if (n >= 3) {
    se_sk <- sqrt((6 * n * (n - 1)) / ((n - 2) * (n + 1) * (n + 3)))
  } else {
    se_sk <- NA_real_
  }
  if (n >= 4) {
    se_ku <- 2 * se_sk * sqrt((n^2 - 1) / ((n - 3) * (n + 5)))
  } else {
    se_ku <- NA_real_
  }

  data.frame(
    N = n_valid,
    缺失 = n_missing,
    均值 = round(m, 4),
    标准误 = round(se_v, 4),
    中位数 = round(q[2], 4),
    众数 = round(mode_v, 4),
    标准差 = round(sd_v, 4),
    方差 = round(sd_v^2, 4),
    极差 = round(max(x_valid) - min(x_valid), 4),
    最小值 = round(min(x_valid), 4),
    最大值 = round(max(x_valid), 4),
    Q1 = round(q[1], 4),
    Q3 = round(q[3], 4),
    IQR = round(q[3] - q[1], 4),
    变异系数 = if (!is.na(sd_v) && m != 0) round(abs(sd_v / m) * 100, 2) else NA_real_,
    偏度 = round(sk, 4),
    偏度标准误 = round(se_sk, 4),
    峰度 = round(ku, 4),
    峰度标准误 = round(se_ku, 4)
  )
}

#' 批量描述统计
#'
#' @param df data.frame
#' @param vars 列名向量(NULL = 全部数值列)
#' @return data.frame(变量 + 全部指标)
desc_table <- function(df, vars = NULL) {
  if (is.null(vars)) {
    vars <- names(df)[vapply(df, is.numeric, logical(1))]
  }
  if (length(vars) == 0) return(data.frame())
  rows <- lapply(vars, function(v) {
    r <- desc_one(df[[v]])
    cbind(变量 = v, r)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ── 3. Split-file / by-group descriptives (SPSS Explore) ───────────
#' 按分组变量分层描述统计
#'
#' @param df data.frame
#' @param vars 数值变量列名
#' @param group 分组列名(单个)
#' @return data.frame(分组 + 变量 + 全部指标)
desc_by_group <- function(df, vars, group) {
  if (!(group %in% names(df))) {
    stop(sprintf("分组变量 %s 不在数据中", group))
  }
  g_vals <- unique(df[[group]])
  g_vals <- g_vals[!is.na(g_vals)]

  rows <- list()
  for (g in g_vals) {
    sub <- df[df[[group]] %in% g & !is.na(df[[group]]), , drop = FALSE]
    if (nrow(sub) == 0) next
    sub_desc <- desc_table(sub, vars)
    sub_desc <- cbind(分组 = as.character(g), sub_desc)
    rows[[length(rows) + 1]] <- sub_desc
  }
  if (length(rows) == 0) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ── 4. Cross-tabulation (frequencies only; chi-square in crosstabs.R)
#' 二维交叉表(频数 + 行% + 列%)
#'
#' @param df data.frame
#' @param row_var 行变量
#' @param col_var 列变量
#' @return list(freq, row_pct, col_pct) 各为 data.frame
crosstab_basic <- function(df, row_var, col_var) {
  sub <- df[!is.na(df[[row_var]]) & !is.na(df[[col_var]]), , drop = FALSE]
  if (nrow(sub) == 0) return(list(freq = data.frame(), row_pct = data.frame(), col_pct = data.frame()))

  tbl <- table(sub[[row_var]], sub[[col_var]])
  freq <- as.data.frame.matrix(addmargins(tbl))
  row_pct <- as.data.frame.matrix(round(prop.table(tbl, margin = 1) * 100, 2))
  col_pct <- as.data.frame.matrix(round(prop.table(tbl, margin = 2) * 100, 2))

  list(freq = freq, row_pct = row_pct, col_pct = col_pct)
}

# ── 5. Normality tests ─────────────────────────────────────────────
#' 正态性检验汇总(Shapiro-Wilk + Kolmogorov-Smirnov + 偏度峰度 z 值)
normality_table <- function(df, vars) {
  rows <- list()
  for (v in vars) {
    x <- na.omit(suppressWarnings(as.numeric(df[[v]])))
    if (length(x) < 3) next
    sw_p <- if (length(x) <= 5000) {
      tryCatch(stats::shapiro.test(x)$p.value, error = function(e) NA_real_)
    } else NA_real_
    ks_p <- tryCatch(
      suppressWarnings(stats::ks.test(x, "pnorm", mean(x), stats::sd(x))$p.value),
      error = function(e) NA_real_
    )
    rows[[length(rows) + 1]] <- data.frame(
      变量 = v, N = length(x),
      Shapiro_W_p = round(sw_p, 4),
      KS_p = round(ks_p, 4)
    )
  }
  if (length(rows) == 0) return(data.frame())
  do.call(rbind, rows)
}
