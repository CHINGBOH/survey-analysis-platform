# lib/inferential.R — SPSS 等价推断统计库
#
# 涵盖 SPSS Analyze > Compare Means / Nonparametric Tests / Crosstabs 全部主功能:
#   - 单样本 t / 独立样本 t(Welch+Student+Levene+Cohen's d) / 配对 t
#   - 单因素 ANOVA + Welch ANOVA + Tukey HSD + Games-Howell + η²/ω²/partial η²
#   - 非参:Mann-Whitney U / Wilcoxon 符号秩 / Kruskal-Wallis + Dunn 事后 / Friedman
#   - 卡方独立性 + Fisher 精确 + Yates 校正 + Phi / Cramer's V / Lambda / Gamma
#     + 标准化残差 + 期望频数
#
# 设计:每个函数返回一个 data.frame(SPSS 风格中文表头) 或 list,可直接 saveRDS

.has_pkg <- function(p) requireNamespace(p, quietly = TRUE)

# ── 0. 通用辅助 ────────────────────────────────────────────────────
.fmt_p <- function(p) {
  if (is.na(p)) return(NA_real_)
  round(p, 6)
}

.cohens_d <- function(x, y) {
  nx <- sum(!is.na(x)); ny <- sum(!is.na(y))
  mx <- mean(x, na.rm = TRUE); my <- mean(y, na.rm = TRUE)
  sx <- stats::var(x, na.rm = TRUE); sy <- stats::var(y, na.rm = TRUE)
  sp <- sqrt(((nx - 1) * sx + (ny - 1) * sy) / (nx + ny - 2))
  if (!is.finite(sp) || sp == 0) return(NA_real_)
  (mx - my) / sp
}

.interp_d <- function(d) {
  if (is.na(d)) return(NA_character_)
  ad <- abs(d)
  if (ad < 0.2) "可忽略" else if (ad < 0.5) "小" else if (ad < 0.8) "中" else "大"
}

# ── 1. 单样本 t 检验 ────────────────────────────────────────────
one_sample_t <- function(x, mu = 0, var_name = "") {
  x <- x[!is.na(x)]
  if (length(x) < 3) return(NULL)
  tt <- stats::t.test(x, mu = mu)
  data.frame(
    变量 = var_name, N = length(x),
    均值 = round(mean(x), 4), 检验值 = mu,
    t = round(tt$statistic, 4), df = round(tt$parameter, 2),
    `p值` = .fmt_p(tt$p.value),
    `均值差` = round(mean(x) - mu, 4),
    `下95CI` = round(tt$conf.int[1], 4),
    `上95CI` = round(tt$conf.int[2], 4),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 2. 独立样本 t 检验(SPSS 三联表:Levene + Student + Welch + d) ─
independent_t <- function(dv, group, dv_name = "", group_name = "") {
  ok <- !is.na(dv) & !is.na(group)
  dv <- dv[ok]; group <- as.factor(group[ok])
  lv <- levels(group)
  if (length(lv) != 2) return(NULL)
  x <- dv[group == lv[1]]; y <- dv[group == lv[2]]
  if (length(x) < 3 || length(y) < 3) return(NULL)

  # Levene 方差齐性
  lev_p <- NA_real_; lev_f <- NA_real_
  if (.has_pkg("car")) {
    lt <- tryCatch(car::leveneTest(dv ~ group, center = "median"), error = function(e) NULL)
    if (!is.null(lt)) { lev_f <- lt$`F value`[1]; lev_p <- lt$`Pr(>F)`[1] }
  }
  tt_eq  <- stats::t.test(x, y, var.equal = TRUE)
  tt_neq <- stats::t.test(x, y, var.equal = FALSE)
  d <- .cohens_d(x, y)

  data.frame(
    因变量 = dv_name, 分组变量 = group_name,
    组1 = lv[1], `组1_N` = length(x), `组1_均值` = round(mean(x), 4), `组1_标准差` = round(sd(x), 4),
    组2 = lv[2], `组2_N` = length(y), `组2_均值` = round(mean(y), 4), `组2_标准差` = round(sd(y), 4),
    `Levene_F` = round(lev_f, 4), `Levene_p` = .fmt_p(lev_p),
    `方差齐性假定` = ifelse(is.na(lev_p) || lev_p > 0.05, "假定相等", "假定不等"),
    `t_等方差` = round(tt_eq$statistic, 4), `df_等方差` = round(tt_eq$parameter, 2),
    `p_等方差` = .fmt_p(tt_eq$p.value),
    `t_Welch` = round(tt_neq$statistic, 4), `df_Welch` = round(tt_neq$parameter, 2),
    `p_Welch` = .fmt_p(tt_neq$p.value),
    `均值差` = round(mean(x) - mean(y), 4),
    `下95CI` = round(tt_neq$conf.int[1], 4), `上95CI` = round(tt_neq$conf.int[2], 4),
    `Cohens_d` = round(d, 4), `效应量` = .interp_d(d),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 3. 配对 t 检验 ──────────────────────────────────────────────
paired_t <- function(x, y, var1 = "", var2 = "") {
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]; y <- y[ok]
  if (length(x) < 3) return(NULL)
  tt <- stats::t.test(x, y, paired = TRUE)
  diff <- x - y
  d <- mean(diff) / sd(diff)
  data.frame(
    变量1 = var1, 变量2 = var2, N = length(x),
    `均值1` = round(mean(x), 4), `均值2` = round(mean(y), 4),
    `差值均值` = round(mean(diff), 4), `差值标准差` = round(sd(diff), 4),
    t = round(tt$statistic, 4), df = tt$parameter,
    `p值` = .fmt_p(tt$p.value),
    `下95CI` = round(tt$conf.int[1], 4), `上95CI` = round(tt$conf.int[2], 4),
    `Cohens_d` = round(d, 4), `效应量` = .interp_d(d),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 4. Mann-Whitney U(非参对应独立 t) ─────────────────────────
mann_whitney <- function(dv, group, dv_name = "", group_name = "") {
  ok <- !is.na(dv) & !is.na(group)
  dv <- dv[ok]; group <- as.factor(group[ok])
  if (length(levels(group)) != 2) return(NULL)
  mw <- suppressWarnings(stats::wilcox.test(dv ~ group, exact = FALSE))
  data.frame(
    因变量 = dv_name, 分组变量 = group_name,
    W = round(mw$statistic, 2),
    `p值` = .fmt_p(mw$p.value),
    备注 = "近似算法(有 ties)",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 5. Wilcoxon 符号秩(非参对应配对 t) ────────────────────────
wilcoxon_signed <- function(x, y, var1 = "", var2 = "") {
  ok <- !is.na(x) & !is.na(y)
  if (sum(ok) < 3) return(NULL)
  w <- suppressWarnings(stats::wilcox.test(x[ok], y[ok], paired = TRUE, exact = FALSE))
  data.frame(变量1 = var1, 变量2 = var2, N = sum(ok),
             V = round(w$statistic, 2), `p值` = .fmt_p(w$p.value),
             stringsAsFactors = FALSE, check.names = FALSE)
}

# ── 6. 单因素 ANOVA(SPSS One-Way) ───────────────────────────────
one_way_anova <- function(dv, group, dv_name = "", group_name = "") {
  ok <- !is.na(dv) & !is.na(group)
  dv <- dv[ok]; group <- as.factor(group[ok])
  if (length(levels(group)) < 2 || length(dv) < length(levels(group)) + 2) return(NULL)

  aov_fit <- stats::aov(dv ~ group)
  s <- summary(aov_fit)[[1]]
  ss_b <- s$`Sum Sq`[1]; ss_w <- s$`Sum Sq`[2]; ss_t <- ss_b + ss_w
  df_b <- s$Df[1]; df_w <- s$Df[2]
  ms_w <- s$`Mean Sq`[2]
  eta2 <- ss_b / ss_t
  omega2 <- (ss_b - df_b * ms_w) / (ss_t + ms_w)
  partial_eta2 <- ss_b / (ss_b + ss_w)
  f_val <- s$`F value`[1]; p_val <- s$`Pr(>F)`[1]

  # Welch ANOVA(方差不齐时更稳)
  wt <- tryCatch(stats::oneway.test(dv ~ group, var.equal = FALSE),
                 error = function(e) NULL)
  welch_f <- if (!is.null(wt)) wt$statistic else NA_real_
  welch_p <- if (!is.null(wt)) wt$p.value else NA_real_

  # Levene
  lev_p <- NA_real_
  if (.has_pkg("car")) {
    lt <- tryCatch(car::leveneTest(dv ~ group, center = "median"), error = function(e) NULL)
    if (!is.null(lt)) lev_p <- lt$`Pr(>F)`[1]
  }

  summary_tbl <- data.frame(
    因变量 = dv_name, 分组变量 = group_name,
    组数 = length(levels(group)), N = length(dv),
    `组间SS` = round(ss_b, 4), `组内SS` = round(ss_w, 4),
    `组间df` = df_b, `组内df` = df_w,
    F = round(f_val, 4), `p值` = .fmt_p(p_val),
    `Levene_p` = .fmt_p(lev_p),
    `Welch_F` = round(welch_f, 4), `Welch_p` = .fmt_p(welch_p),
    `eta_squared` = round(eta2, 4),
    `partial_eta_squared` = round(partial_eta2, 4),
    `omega_squared` = round(omega2, 4),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # 组均值
  group_means <- as.data.frame(
    do.call(rbind, tapply(dv, group, function(v) {
      c(N = length(v), 均值 = round(mean(v), 4), 标准差 = round(sd(v), 4),
        最小 = round(min(v), 4), 最大 = round(max(v), 4))
    }))
  )
  group_means$组 <- rownames(group_means); rownames(group_means) <- NULL
  group_means <- group_means[, c("组", setdiff(names(group_means), "组"))]

  list(summary = summary_tbl, group_means = group_means, aov_obj = aov_fit)
}

# ── 7. Tukey HSD 事后比较 ──────────────────────────────────────
tukey_posthoc <- function(aov_fit) {
  if (is.null(aov_fit)) return(NULL)
  tk <- tryCatch(stats::TukeyHSD(aov_fit), error = function(e) NULL)
  if (is.null(tk)) return(NULL)
  m <- tk[[1]]
  data.frame(
    比较 = rownames(m),
    `均值差` = round(m[, "diff"], 4),
    `下95CI` = round(m[, "lwr"], 4),
    `上95CI` = round(m[, "upr"], 4),
    `p_adj` = round(m[, "p adj"], 6),
    `显著` = ifelse(m[, "p adj"] < 0.05, "是", "否"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 8. Games-Howell(方差不齐时的事后比较) ──────────────────────
games_howell <- function(dv, group) {
  ok <- !is.na(dv) & !is.na(group)
  dv <- dv[ok]; group <- as.factor(group[ok])
  lv <- levels(group)
  if (length(lv) < 2) return(NULL)
  out <- list()
  for (i in 1:(length(lv) - 1)) for (j in (i + 1):length(lv)) {
    x <- dv[group == lv[i]]; y <- dv[group == lv[j]]
    nx <- length(x); ny <- length(y)
    if (nx < 2 || ny < 2) next
    mx <- mean(x); my <- mean(y)
    vx <- var(x); vy <- var(y)
    se <- sqrt(vx / nx + vy / ny)
    t_stat <- (mx - my) / se
    df <- (vx / nx + vy / ny)^2 /
      ((vx / nx)^2 / (nx - 1) + (vy / ny)^2 / (ny - 1))
    p <- 2 * (1 - stats::pt(abs(t_stat), df))
    out[[length(out) + 1]] <- data.frame(
      比较 = paste(lv[j], lv[i], sep = "-"),
      `均值差` = round(mx - my, 4),
      t = round(t_stat, 4), df = round(df, 2),
      `p值` = .fmt_p(p), `显著` = ifelse(p < 0.05, "是", "否"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

# ── 9. Kruskal-Wallis(非参对应单因素 ANOVA) ───────────────────
kruskal_wallis <- function(dv, group, dv_name = "", group_name = "") {
  ok <- !is.na(dv) & !is.na(group)
  dv <- dv[ok]; group <- as.factor(group[ok])
  if (length(levels(group)) < 2) return(NULL)
  kw <- stats::kruskal.test(dv ~ group)
  data.frame(
    因变量 = dv_name, 分组变量 = group_name,
    `卡方` = round(kw$statistic, 4), df = kw$parameter,
    `p值` = .fmt_p(kw$p.value),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 10. Dunn 事后(非参 KW 后续) ───────────────────────────────
dunn_posthoc <- function(dv, group) {
  if (!.has_pkg("FSA")) return(NULL)
  ok <- !is.na(dv) & !is.na(group)
  dn <- tryCatch(FSA::dunnTest(dv[ok], as.factor(group[ok]), method = "bonferroni"),
                 error = function(e) NULL)
  if (is.null(dn)) return(NULL)
  res <- dn$res
  data.frame(
    比较 = res$Comparison, Z = round(res$Z, 4),
    `p_unadj` = round(res$P.unadj, 6), `p_adj` = round(res$P.adj, 6),
    `显著` = ifelse(res$P.adj < 0.05, "是", "否"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# ── 11. 卡方独立性 + 关联度量(SPSS Crosstabs 全套) ────────────
chisq_full <- function(x, y, row_name = "行", col_name = "列") {
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]; y <- y[ok]
  if (length(x) < 5) return(NULL)
  tbl <- table(x, y)
  if (any(dim(tbl) < 2)) return(NULL)
  dimnames(tbl) <- list(row_name = dimnames(tbl)[[1]], col_name = dimnames(tbl)[[2]])

  n <- sum(tbl)
  ct <- suppressWarnings(stats::chisq.test(tbl))
  # 是否需要 Yates / Fisher
  use_yates <- all(dim(tbl) == 2)
  yates <- if (use_yates) suppressWarnings(stats::chisq.test(tbl, correct = TRUE)) else NULL
  fisher <- if (any(ct$expected < 5) || all(dim(tbl) == 2)) {
    tryCatch(stats::fisher.test(tbl, simulate.p.value = (prod(dim(tbl)) > 6)),
             error = function(e) NULL)
  } else NULL

  phi <- if (all(dim(tbl) == 2)) sqrt(ct$statistic / n) else NA_real_
  cramer_v <- sqrt(ct$statistic / (n * (min(dim(tbl)) - 1)))
  contingency_c <- sqrt(ct$statistic / (ct$statistic + n))

  std_resid <- as.data.frame.matrix(round(ct$stdres, 3))
  expected  <- as.data.frame.matrix(round(ct$expected, 2))

  measures <- data.frame(
    指标 = c("Pearson χ²", "自由度", "p值",
             "连续性校正 χ²(Yates)", "Yates p",
             "Fisher 精确 p",
             "Phi", "Cramer's V", "列联系数 C", "样本量 N"),
    数值 = c(
      round(ct$statistic, 4), as.integer(ct$parameter), .fmt_p(ct$p.value),
      if (!is.null(yates)) round(yates$statistic, 4) else NA,
      if (!is.null(yates)) .fmt_p(yates$p.value) else NA,
      if (!is.null(fisher)) .fmt_p(fisher$p.value) else NA,
      round(phi, 4), round(cramer_v, 4), round(contingency_c, 4), n
    ),
    stringsAsFactors = FALSE
  )

  list(
    crosstab = tbl,
    expected = expected,
    std_residuals = std_resid,
    measures = measures,
    title = paste(row_name, "×", col_name, "交叉表")
  )
}

# ── 12. Friedman(配对多组非参,如重复测量) ─────────────────────
friedman_test <- function(mat, vars = NULL) {
  if (is.null(vars)) vars <- colnames(mat)
  m <- as.matrix(mat[, vars])
  m <- m[complete.cases(m), , drop = FALSE]
  if (nrow(m) < 3 || ncol(m) < 2) return(NULL)
  ft <- stats::friedman.test(m)
  data.frame(
    变量组 = paste(vars, collapse = ","),
    N = nrow(m), k = ncol(m),
    `卡方` = round(ft$statistic, 4), df = ft$parameter,
    `p值` = .fmt_p(ft$p.value),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}
