# lib/survey_specific.R — 问卷专用分析 (Likert / 权重 / 缺失 / 异常 / 文本)
.libPaths(c("~/R/libs", .libPaths()))

.fmt <- function(x, d = 4) ifelse(is.na(x), NA_real_, round(x, d))

# === Likert 量表分析 ========================================================
likert_summary <- function(x, var_name = "", scale_max = 5) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NULL)
  if (!is.numeric(x)) return(NULL)
  n <- length(x)
  tab <- table(factor(x, levels = 1:scale_max))
  pct <- round(prop.table(tab) * 100, 2)
  # Top2 / Bottom2
  top2 <- sum(x >= (scale_max - 1)) / n * 100
  bot2 <- sum(x <= 2) / n * 100
  # NPS-like (适用于 0-10 推荐量表;对 5 级近似)
  promoters <- if (scale_max == 10) sum(x >= 9) / n * 100 else sum(x >= scale_max) / n * 100
  detractors <- if (scale_max == 10) sum(x <= 6) / n * 100 else sum(x <= 2) / n * 100
  nps <- promoters - detractors
  data.frame(
    变量 = var_name, n = n,
    均值 = .fmt(mean(x)), SD = .fmt(sd(x)),
    Top2Box = .fmt(top2, 2),
    Bottom2Box = .fmt(bot2, 2),
    NPS = .fmt(nps, 2),
    promoters_pct = .fmt(promoters, 2),
    detractors_pct = .fmt(detractors, 2),
    row.names = NULL
  )
}

likert_distribution <- function(x, var_name = "", scale_max = 5) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NULL)
  tab <- table(factor(x, levels = 1:scale_max))
  data.frame(
    变量 = var_name,
    分值 = 1:scale_max,
    频数 = as.numeric(tab),
    占比_pct = .fmt(as.numeric(prop.table(tab) * 100), 2),
    row.names = NULL
  )
}

# === 缺失值分析 + 处理 ======================================================
missing_pattern <- function(df) {
  miss <- sapply(df, function(v) sum(is.na(v)))
  data.frame(
    变量 = names(miss),
    缺失数 = as.numeric(miss),
    缺失率_pct = .fmt(as.numeric(miss) / nrow(df) * 100, 2),
    row.names = NULL
  )
}

impute_simple <- function(df, method = "median") {
  out <- df
  for (n in names(out)) {
    v <- out[[n]]
    if (is.numeric(v) && any(is.na(v))) {
      fill <- switch(method,
        mean = mean(v, na.rm = TRUE),
        median = median(v, na.rm = TRUE),
        zero = 0,
        median(v, na.rm = TRUE))
      out[[n]][is.na(v)] <- fill
    } else if (!is.numeric(v) && any(is.na(v))) {
      tab <- table(v, useNA = "no")
      if (length(tab) > 0) out[[n]][is.na(v)] <- names(tab)[which.max(tab)]
    }
  }
  out
}

impute_mi <- function(df, m = 5, maxit = 5) {
  if (!requireNamespace("mice", quietly = TRUE)) {
    return(list(error = "mice 包未安装,回退中位数插补"))
  }
  imp <- tryCatch(mice::mice(df, m = m, maxit = maxit, printFlag = FALSE),
                  error = function(e) return(list(error = e$message)))
  if (!is.null(imp$error)) return(imp)
  list(imp = imp, completed = mice::complete(imp, 1), m = m)
}

# === 异常值检测 =============================================================
outliers_zscore <- function(x, threshold = 3) {
  x <- as.numeric(x)
  z <- abs(scale(x, center = TRUE, scale = TRUE))[, 1]
  list(method = "Z-score", threshold = threshold,
       n_outliers = sum(z > threshold, na.rm = TRUE),
       idx = which(z > threshold))
}

outliers_iqr <- function(x, k = 1.5) {
  x <- as.numeric(x)
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  iqr <- q[2] - q[1]
  lo <- q[1] - k * iqr; hi <- q[2] + k * iqr
  list(method = "IQR", k = k, lower = .fmt(lo, 4), upper = .fmt(hi, 4),
       n_outliers = sum(x < lo | x > hi, na.rm = TRUE),
       idx = which(x < lo | x > hi))
}

outliers_mahalanobis <- function(df, alpha = 0.001) {
  df <- na.omit(df[, sapply(df, is.numeric), drop = FALSE])
  if (ncol(df) < 2) return(list(error = "需 ≥2 数值列"))
  ctr <- colMeans(df); cv <- cov(df)
  cv_inv <- tryCatch(solve(cv), error = function(e) return(NULL))
  if (is.null(cv_inv)) return(list(error = "协方差矩阵不可逆"))
  d2 <- mahalanobis(df, ctr, cv)
  thr <- qchisq(1 - alpha, df = ncol(df))
  list(method = "Mahalanobis", threshold = .fmt(thr, 4),
       n_outliers = sum(d2 > thr),
       idx = which(d2 > thr))
}

# === 权重计算 (Rim/Raking) ==================================================
rim_weighting <- function(df, targets) {
  # targets: named list, e.g. list(gender = c(M=0.5, F=0.5), age_grp = c(...))
  n <- nrow(df)
  w <- rep(1, n)
  for (iter in 1:30) {
    for (v in names(targets)) {
      tab <- prop.table(table(df[[v]]))
      tgt <- targets[[v]]
      common <- intersect(names(tab), names(tgt))
      adj <- tgt[common] / tab[common]
      for (cat in common) {
        idx <- which(df[[v]] == cat)
        w[idx] <- w[idx] * adj[cat]
      }
    }
    w <- w * n / sum(w)
  }
  list(weights = w, mean = mean(w), sd = sd(w), min = min(w), max = max(w),
       eff_n = sum(w)^2 / sum(w^2))
}

# === 文本分析 (轻量,无外部 NLP) =============================================
text_basic_stats <- function(x) {
  x <- as.character(x[!is.na(x) & x != ""])
  if (length(x) == 0) return(NULL)
  nchar_each <- nchar(x)
  data.frame(
    n_responses = length(x),
    avg_length = .fmt(mean(nchar_each), 2),
    median_length = .fmt(median(nchar_each), 1),
    max_length = max(nchar_each),
    min_length = min(nchar_each),
    row.names = NULL
  )
}

text_word_freq <- function(x, top_n = 30) {
  x <- as.character(x[!is.na(x) & x != ""])
  if (length(x) == 0) return(NULL)
  # 中英混合简单分词
  if (requireNamespace("jiebaR", quietly = TRUE)) {
    seg <- jiebaR::worker(stop_word = "")
    words <- unlist(lapply(x, function(s) seg <= s))
  } else {
    # 退化:按空格 + 标点
    words <- unlist(strsplit(x, "[[:space:][:punct:]]+"))
  }
  words <- words[nchar(words) >= 2]
  tab <- sort(table(words), decreasing = TRUE)
  head(data.frame(词 = names(tab), 频次 = as.numeric(tab), row.names = NULL), top_n)
}

# 轻量情感:正/负词典 (示例,可扩展)
text_sentiment <- function(x,
                           pos = c("好", "棒", "满意", "喜欢", "推荐", "优秀", "happy", "good", "great"),
                           neg = c("差", "烂", "不满", "讨厌", "失望", "糟糕", "bad", "poor", "terrible")) {
  x <- as.character(x[!is.na(x) & x != ""])
  if (length(x) == 0) return(NULL)
  pos_n <- sapply(x, function(s) sum(sapply(pos, function(p) lengths(regmatches(s, gregexpr(p, s, ignore.case = TRUE))))))
  neg_n <- sapply(x, function(s) sum(sapply(neg, function(p) lengths(regmatches(s, gregexpr(p, s, ignore.case = TRUE))))))
  score <- pos_n - neg_n
  data.frame(
    n_responses = length(x),
    pos_avg = .fmt(mean(pos_n), 2),
    neg_avg = .fmt(mean(neg_n), 2),
    sentiment_score_avg = .fmt(mean(score), 2),
    pos_pct = .fmt(mean(score > 0) * 100, 2),
    neg_pct = .fmt(mean(score < 0) * 100, 2),
    neutral_pct = .fmt(mean(score == 0) * 100, 2),
    row.names = NULL
  )
}
