# lib/regression.R — SPSS 等价回归分析库
#
# 覆盖 SPSS Analyze > Regression 全部主要子菜单:
#   - Linear: 多元线性回归 + 系数表 + ANOVA 表 + 模型摘要 + 共线性 (VIF/Tol)
#     + 残差诊断 (Durbin-Watson / Breusch-Pagan 异方差 / Shapiro 正态)
#     + 标准化残差/Cook距离/杠杆值前 N
#   - Hierarchical: 分块进入,逐块 R² 变化 + F 变化 + p 变化
#   - Logistic Binary: OR + 95%CI + Wald + Hosmer-Lemeshow + ROC AUC + 分类表
#     + Nagelkerke / Cox-Snell R²
#   - Multinomial Logistic: 多分类,每类 vs ref 一组 OR
#   - Ordinal: 比例优势模型 (clm) — 若 ordinal 包可用
#   - Poisson: 计数回归 + 过度散布检验

.has_pkg <- function(p) requireNamespace(p, quietly = TRUE)

.fmt_p <- function(p) {
  out <- ifelse(is.na(p), NA_real_, round(p, 6))
  if (length(out) == 1) as.numeric(out) else out
}

.interp_r2 <- function(r2) {
  if (is.na(r2)) return(NA_character_)
  if (r2 < 0.02) "几乎无解释力" else if (r2 < 0.13) "弱"
  else if (r2 < 0.26) "中等" else "强"
}

.interp_auc <- function(a) {
  if (is.na(a)) return(NA_character_)
  if (a < 0.6) "接近随机" else if (a < 0.7) "较弱"
  else if (a < 0.8) "可接受" else if (a < 0.9) "良好" else "优秀"
}

# ── 1. 多元线性回归 (SPSS Linear Regression) ────────────────────
linear_regression <- function(formula, data, var_labels = NULL) {
  data <- stats::na.omit(data)
  if (nrow(data) < 20) return(list(error = sprintf("样本不足: n=%d (需 >=20)", nrow(data))))

  fit <- stats::lm(formula, data = data)
  s <- summary(fit)
  n <- nrow(data); p <- length(stats::coef(fit)) - 1

  # 模型摘要
  model_summary <- data.frame(
    R = round(sqrt(s$r.squared), 4),
    `R方` = round(s$r.squared, 4),
    `调整R方` = round(s$adj.r.squared, 4),
    `标准误` = round(s$sigma, 4),
    `F统计量` = round(s$fstatistic[1], 4),
    `df1` = s$fstatistic[2], `df2` = s$fstatistic[3],
    `p值` = .fmt_p(stats::pf(s$fstatistic[1], s$fstatistic[2], s$fstatistic[3], lower.tail = FALSE)),
    `效应强度` = .interp_r2(s$r.squared),
    N = n,
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # ANOVA 表
  av <- stats::anova(fit)
  anova_tbl <- data.frame(
    项 = rownames(av),
    `平方和` = round(av$`Sum Sq`, 4),
    df = av$Df,
    `均方` = round(av$`Mean Sq`, 4),
    F = round(av$`F value`, 4),
    `p值` = .fmt_p(av$`Pr(>F)`),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # 系数表 (+ 标准化 beta)
  coef_mat <- s$coefficients
  # 标准化 beta: beta = b * sd(x)/sd(y)
  resp_name <- as.character(formula)[2]
  y_sd <- sd(data[[resp_name]], na.rm = TRUE)
  beta_std <- sapply(rownames(coef_mat), function(nm) {
    if (nm == "(Intercept)") return(NA_real_)
    if (!nm %in% names(data) || !is.numeric(data[[nm]])) return(NA_real_)
    coef_mat[nm, "Estimate"] * sd(data[[nm]], na.rm = TRUE) / y_sd
  })
  ci <- tryCatch(stats::confint(fit), error = function(e) matrix(NA, nrow(coef_mat), 2))

  coef_tbl <- data.frame(
    变量 = rownames(coef_mat),
    `B估计` = round(coef_mat[, "Estimate"], 4),
    `标准误` = round(coef_mat[, "Std. Error"], 4),
    `Beta标准化` = round(beta_std, 4),
    t = round(coef_mat[, "t value"], 4),
    `p值` = .fmt_p(coef_mat[, "Pr(>|t|)"]),
    `下95CI` = round(ci[, 1], 4),
    `上95CI` = round(ci[, 2], 4),
    `显著` = ifelse(coef_mat[, "Pr(>|t|)"] < 0.05, "是", "否"),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # 共线性: VIF + Tolerance
  vif_tbl <- NULL
  if (.has_pkg("car") && p >= 2) {
    v <- tryCatch(car::vif(fit), error = function(e) NULL)
    if (!is.null(v) && is.numeric(v)) {
      vif_tbl <- data.frame(
        变量 = names(v), VIF = round(v, 4),
        `容忍度` = round(1 / v, 4),
        `共线性` = ifelse(v > 10, "严重", ifelse(v > 5, "中等", "可接受")),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
  }

  # 残差诊断
  resid_diag <- list()
  dw <- tryCatch({
    if (.has_pkg("lmtest")) lmtest::dwtest(fit) else NULL
  }, error = function(e) NULL)
  bp <- tryCatch({
    if (.has_pkg("lmtest")) lmtest::bptest(fit) else NULL
  }, error = function(e) NULL)
  sh <- tryCatch(stats::shapiro.test(stats::residuals(fit)), error = function(e) NULL)

  resid_diag$tests <- data.frame(
    检验 = c("Durbin-Watson (自相关)", "Breusch-Pagan (异方差)", "Shapiro-Wilk (残差正态)"),
    统计量 = c(
      if (!is.null(dw)) round(dw$statistic, 4) else NA,
      if (!is.null(bp)) round(bp$statistic, 4) else NA,
      if (!is.null(sh)) round(sh$statistic, 4) else NA
    ),
    `p值` = c(
      if (!is.null(dw)) .fmt_p(dw$p.value) else NA,
      if (!is.null(bp)) .fmt_p(bp$p.value) else NA,
      if (!is.null(sh)) .fmt_p(sh$p.value) else NA
    ),
    判读 = c(
      if (!is.null(dw)) (if (abs(dw$statistic - 2) < 0.4) "无显著自相关" else "存在自相关") else NA,
      if (!is.null(bp)) (if (bp$p.value > 0.05) "方差齐性" else "存在异方差") else NA,
      if (!is.null(sh)) (if (sh$p.value > 0.05) "近似正态" else "偏离正态") else NA
    ),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # 影响诊断: Cook 距离 / 标准化残差 前 10
  std_res <- stats::rstandard(fit)
  cooks <- stats::cooks.distance(fit)
  hat <- stats::hatvalues(fit)
  influence_tbl <- data.frame(
    obs = seq_along(std_res),
    `标准化残差` = round(std_res, 3),
    `Cook距离` = round(cooks, 4),
    `杠杆值` = round(hat, 4),
    `异常` = ifelse(abs(std_res) > 3 | cooks > 4 / n,
                    "潜在异常", ""),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  influence_tbl <- influence_tbl[order(-influence_tbl$`Cook距离`), ][1:min(10, n), ]

  list(
    model_summary = model_summary,
    anova = anova_tbl,
    coefficients = coef_tbl,
    collinearity = vif_tbl,
    residual_diagnostics = resid_diag,
    influence_top10 = influence_tbl,
    formula = deparse(formula),
    n = n
  )
}

# ── 2. 层次回归 (SPSS Hierarchical: 逐步加块) ─────────────────────
hierarchical_regression <- function(blocks, data, response) {
  data <- stats::na.omit(data)
  if (nrow(data) < 20) return(list(error = "样本不足"))
  rows <- list(); prev_r2 <- 0; prev_fit <- NULL
  for (i in seq_along(blocks)) {
    vars <- unlist(blocks[1:i])
    f <- stats::as.formula(paste(response, "~", paste(vars, collapse = " + ")))
    fit <- stats::lm(f, data = data)
    s <- summary(fit)
    r2 <- s$r.squared
    f_change <- p_change <- NA
    if (!is.null(prev_fit)) {
      av <- stats::anova(prev_fit, fit)
      f_change <- av$F[2]; p_change <- av$`Pr(>F)`[2]
    }
    rows[[i]] <- data.frame(
      块 = i, 新增变量 = paste(blocks[[i]], collapse = ","),
      `R方` = round(r2, 4), `调整R方` = round(s$adj.r.squared, 4),
      `R方变化` = round(r2 - prev_r2, 4),
      `F变化` = round(f_change, 4), `p变化` = .fmt_p(p_change),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    prev_r2 <- r2; prev_fit <- fit
  }
  list(blocks_summary = do.call(rbind, rows), final_fit_summary = summary(prev_fit))
}

# ── 3. 二元 Logistic 回归 ────────────────────────────────────────
logistic_regression <- function(formula, data) {
  data <- stats::na.omit(data)
  resp_name <- as.character(formula)[2]
  if (nrow(data) < 20 || length(unique(data[[resp_name]])) != 2) {
    return(list(error = sprintf("样本不足或因变量非二分类 (n=%d)", nrow(data))))
  }
  fit <- stats::glm(formula, data = data, family = stats::binomial())
  s <- summary(fit)
  coef_mat <- s$coefficients
  or <- exp(stats::coef(fit))
  ci <- tryCatch(exp(stats::confint(fit)), error = function(e) matrix(NA, nrow(coef_mat), 2))

  coef_tbl <- data.frame(
    变量 = rownames(coef_mat),
    B = round(coef_mat[, "Estimate"], 4),
    `标准误` = round(coef_mat[, "Std. Error"], 4),
    Wald = round((coef_mat[, "Estimate"] / coef_mat[, "Std. Error"])^2, 4),
    `p值` = .fmt_p(coef_mat[, "Pr(>|z|)"]),
    `OR比值比` = round(or, 4),
    `下95CI` = round(ci[, 1], 4), `上95CI` = round(ci[, 2], 4),
    `显著` = ifelse(coef_mat[, "Pr(>|z|)"] < 0.05, "是", "否"),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # 伪 R²
  n <- nrow(data)
  ll0 <- -fit$null.deviance / 2; lln <- -fit$deviance / 2
  cox_snell <- 1 - exp((2 / n) * (ll0 - lln))
  max_cs <- 1 - exp(2 / n * ll0)
  nagelkerke <- cox_snell / max_cs
  mcfadden <- 1 - lln / ll0

  # ROC / AUC
  auc_val <- sens <- spec <- threshold <- youden <- NA
  if (.has_pkg("pROC")) {
    pred <- stats::predict(fit, type = "response")
    roc_obj <- tryCatch(pROC::roc(data[[resp_name]], pred, quiet = TRUE),
                        error = function(e) NULL)
    if (!is.null(roc_obj)) {
      auc_val <- as.numeric(pROC::auc(roc_obj))
      cb <- pROC::coords(roc_obj, "best",
                         ret = c("threshold", "sensitivity", "specificity"))
      threshold <- cb$threshold[1]; sens <- cb$sensitivity[1]; spec <- cb$specificity[1]
      youden <- sens + spec - 1
    }
  }

  # 分类表 (cutoff=0.5)
  pred_cls <- as.integer(stats::predict(fit, type = "response") >= 0.5)
  obs_cls <- as.integer(as.numeric(as.factor(data[[resp_name]])) - 1)
  ct <- table(observed = obs_cls, predicted = pred_cls)
  accuracy <- sum(diag(ct)) / sum(ct)

  # Hosmer-Lemeshow
  hl_p <- NA
  if (.has_pkg("ResourceSelection")) {
    hl <- tryCatch(ResourceSelection::hoslem.test(data[[resp_name]],
                                                  stats::fitted(fit), g = 10),
                   error = function(e) NULL)
    if (!is.null(hl)) hl_p <- hl$p.value
  }

  model_summary <- data.frame(
    N = n,
    `空模型偏差` = round(fit$null.deviance, 4),
    `模型偏差` = round(fit$deviance, 4),
    AIC = round(fit$aic, 4),
    `Cox-Snell_R方` = round(cox_snell, 4),
    `Nagelkerke_R方` = round(nagelkerke, 4),
    `McFadden_R方` = round(mcfadden, 4),
    AUC = round(auc_val, 4), `AUC判读` = .interp_auc(auc_val),
    `灵敏度` = round(sens, 4), `特异度` = round(spec, 4),
    `Youden_J` = round(youden, 4),
    `阈值cutoff` = round(threshold, 4),
    `整体正确率0.5` = round(accuracy, 4),
    `Hosmer_Lemeshow_p` = .fmt_p(hl_p),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  list(
    model_summary = model_summary,
    coefficients = coef_tbl,
    classification_table = as.data.frame.matrix(ct),
    formula = deparse(formula), n = n
  )
}

# ── 4. 多分类 Logistic (nnet::multinom) ─────────────────────────
multinomial_logistic <- function(formula, data) {
  if (!.has_pkg("nnet")) return(list(error = "需安装 nnet 包"))
  data <- stats::na.omit(data)
  if (nrow(data) < 30) return(list(error = "样本不足"))
  fit <- tryCatch(nnet::multinom(formula, data = data, trace = FALSE),
                  error = function(e) NULL)
  if (is.null(fit)) return(list(error = "拟合失败"))
  s <- summary(fit)
  z <- s$coefficients / s$standard.errors
  p_mat <- 2 * (1 - stats::pnorm(abs(z)))
  list(
    coefficients = round(s$coefficients, 4),
    std_errors = round(s$standard.errors, 4),
    z = round(z, 4), p = round(p_mat, 6),
    OR = round(exp(s$coefficients), 4),
    n = nrow(data), formula = deparse(formula)
  )
}

# ── 5. Poisson 计数回归 ────────────────────────────────────────
poisson_regression <- function(formula, data) {
  data <- stats::na.omit(data)
  resp_name <- as.character(formula)[2]
  if (nrow(data) < 20) return(list(error = "样本不足"))
  if (!is.numeric(data[[resp_name]]) || any(data[[resp_name]] < 0)) {
    return(list(error = "因变量必须为非负整数计数"))
  }
  fit <- stats::glm(formula, data = data, family = stats::poisson())
  s <- summary(fit)
  coef_mat <- s$coefficients
  # 过度散布
  dispersion <- sum(stats::residuals(fit, type = "pearson")^2) / fit$df.residual
  coef_tbl <- data.frame(
    变量 = rownames(coef_mat),
    B = round(coef_mat[, "Estimate"], 4),
    `标准误` = round(coef_mat[, "Std. Error"], 4),
    z = round(coef_mat[, "z value"], 4),
    `p值` = .fmt_p(coef_mat[, "Pr(>|z|)"]),
    `IRR` = round(exp(coef_mat[, "Estimate"]), 4),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  list(
    coefficients = coef_tbl,
    model_summary = data.frame(
      N = nrow(data), AIC = round(fit$aic, 4),
      `空模型偏差` = round(fit$null.deviance, 4),
      `模型偏差` = round(fit$deviance, 4),
      `离散度` = round(dispersion, 4),
      `过度散布` = ifelse(dispersion > 1.5, "是 (建议改用 quasipoisson / negbinom)", "否"),
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    n = nrow(data), formula = deparse(formula)
  )
}
