# lib/chart_stat.R — 统计专用图表 (Scree / Biplot / 森林 / ROC / 火山 / Mosaic / K-M / 诊断 4 联)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(ggplot2); library(scales) })

THEME_STAT <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"))

# 1) 碎石图 (Scree) — 因子分析
chart_scree <- function(eigenvalues, n_kaiser = NULL, title = "碎石图") {
  df <- data.frame(成分 = seq_along(eigenvalues), 特征值 = as.numeric(eigenvalues))
  if (is.null(n_kaiser)) n_kaiser <- sum(df$特征值 > 1)
  ggplot(df, aes(x = 成分, y = 特征值)) +
    geom_line(color = "#1f77b4", linewidth = 0.8) +
    geom_point(size = 3, color = "#1f77b4") +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    annotate("text", x = max(df$成分) * 0.85, y = 1.1, label = "Kaiser 准则 = 1",
             color = "red", size = 3) +
    scale_x_continuous(breaks = seq_len(nrow(df))) +
    labs(title = title, subtitle = sprintf("保留 %d 个特征值 >1", n_kaiser),
         x = "主成分编号", y = "特征值") + THEME_STAT
}

# 2) 双标图 (Biplot) — PCA
chart_biplot <- function(scores, loadings, title = "PCA 双标图") {
  scores <- as.data.frame(scores[, 1:2, drop = FALSE]); names(scores) <- c("PC1", "PC2")
  loadings <- as.data.frame(loadings[, 1:2, drop = FALSE]); names(loadings) <- c("PC1", "PC2")
  loadings$var <- rownames(loadings)
  scl <- max(abs(scores)) / max(abs(loadings)) * 0.7
  ggplot() +
    geom_point(data = scores, aes(PC1, PC2), color = "#888", alpha = 0.4, size = 1.5) +
    geom_segment(data = loadings, aes(x = 0, y = 0, xend = PC1 * scl, yend = PC2 * scl),
                 arrow = arrow(length = unit(0.2, "cm")), color = "#d62728", linewidth = 0.7) +
    geom_text(data = loadings, aes(PC1 * scl * 1.1, PC2 * scl * 1.1, label = var),
              color = "#d62728", size = 3.2) +
    labs(title = title, x = "PC1", y = "PC2") + THEME_STAT +
    geom_vline(xintercept = 0, linetype = "dotted") +
    geom_hline(yintercept = 0, linetype = "dotted")
}

# 3) 森林图 (通用 — 标签 + 估计值 + CI)
chart_forest <- function(df, x_col = "estimate", lo_col = "lo", hi_col = "hi",
                         label_col = "label", ref = 0, title = "森林图") {
  df <- df[order(df[[x_col]]), ]
  df$label <- factor(df[[label_col]], levels = df[[label_col]])
  ggplot(df, aes(x = .data[[x_col]], y = label)) +
    geom_vline(xintercept = ref, linetype = "dashed", color = "red") +
    geom_errorbarh(aes(xmin = .data[[lo_col]], xmax = .data[[hi_col]]), height = 0.2, color = "#333") +
    geom_point(size = 3, color = "#1f77b4") +
    labs(title = title, x = "估计值 (95% CI)", y = NULL) + THEME_STAT
}

# 4) ROC 曲线 — 真实 ROC (输入预测概率 + 实际)
chart_roc <- function(actual, predicted, title = "ROC 曲线") {
  if (requireNamespace("pROC", quietly = TRUE)) {
    r <- tryCatch(pROC::roc(actual, predicted, quiet = TRUE), error = function(e) NULL)
    if (!is.null(r)) {
      df <- data.frame(fpr = 1 - r$specificities, tpr = r$sensitivities)
      df <- df[order(df$fpr, df$tpr), ]
      auc <- as.numeric(r$auc)
      return(ggplot(df, aes(fpr, tpr)) +
               geom_line(color = "#d62728", linewidth = 1) +
               geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray") +
               annotate("text", x = 0.65, y = 0.1, label = sprintf("AUC = %.3f", auc),
                        color = "#d62728", size = 5) +
               coord_equal() + labs(title = title, x = "1 - 特异度 (FPR)", y = "灵敏度 (TPR)") + THEME_STAT)
    }
  }
  ggplot() + annotate("text", x = 0.5, y = 0.5, label = "需 pROC 包") + THEME_STAT
}

# 5) 火山图 (volcano)
chart_volcano <- function(df, fc_col = "log2fc", p_col = "p", label_col = "label",
                          fc_thr = 1, p_thr = 0.05, title = "火山图") {
  df$nlog10p <- -log10(pmax(df[[p_col]], 1e-30))
  df$sig <- with(df, ifelse(get(p_col) < p_thr & abs(get(fc_col)) > fc_thr,
                            ifelse(get(fc_col) > 0, "up", "down"), "ns"))
  ggplot(df, aes(.data[[fc_col]], nlog10p, color = sig)) +
    geom_point(alpha = 0.7, size = 2) +
    scale_color_manual(values = c(up = "#d62728", down = "#1f77b4", ns = "gray")) +
    geom_vline(xintercept = c(-fc_thr, fc_thr), linetype = "dashed") +
    geom_hline(yintercept = -log10(p_thr), linetype = "dashed") +
    labs(title = title, x = "log2 倍数变化", y = "-log10(p)") + THEME_STAT
}

# 6) 马赛克图 (Mosaic) — 交叉表
chart_mosaic <- function(tab, title = "马赛克图") {
  if (!requireNamespace("ggmosaic", quietly = TRUE)) {
    # 退化:堆叠百分比柱状
    df <- as.data.frame(prop.table(tab, margin = 1) * 100)
    names(df) <- c("行", "列", "占比")
    return(ggplot(df, aes(行, 占比, fill = 列)) +
             geom_col() + scale_fill_brewer(palette = "Set2") +
             labs(title = title, x = NULL, y = "占比 (%)") + THEME_STAT)
  }
  df <- as.data.frame(tab); names(df) <- c("X", "Y", "Freq")
  ggplot(df) + ggmosaic::geom_mosaic(aes(weight = Freq, x = ggmosaic::product(X), fill = Y)) +
    labs(title = title) + THEME_STAT
}

# 7) Kaplan-Meier 曲线
chart_km <- function(time, event, group = NULL, title = "Kaplan-Meier 生存曲线") {
  if (!requireNamespace("survival", quietly = TRUE)) {
    return(ggplot() + annotate("text", x = 0.5, y = 0.5, label = "需 survival 包") + THEME_STAT)
  }
  sd <- if (is.null(group)) survival::survfit(survival::Surv(time, event) ~ 1)
        else survival::survfit(survival::Surv(time, event) ~ group)
  df <- data.frame(time = sd$time, surv = sd$surv,
                   group = if (is.null(sd$strata)) "all" else rep(names(sd$strata), sd$strata))
  ggplot(df, aes(time, surv, color = group)) +
    geom_step(linewidth = 1) + scale_y_continuous(limits = c(0, 1), labels = percent) +
    labs(title = title, x = "时间", y = "生存概率") + THEME_STAT
}

# 8) 回归诊断 4 联 (返回 4 个 ggplot,调用方 patchwork 合并)
chart_diagnostics4 <- function(model) {
  fv <- fitted(model); res <- resid(model); std <- rstandard(model); lev <- hatvalues(model); cook <- cooks.distance(model)
  d <- data.frame(fitted = fv, residuals = res, std = std, lev = lev, cook = cook)
  p1 <- ggplot(d, aes(fitted, residuals)) + geom_point(alpha = 0.5) + geom_smooth(method = "loess", se = FALSE) +
        geom_hline(yintercept = 0, linetype = "dashed") + labs(title = "残差 vs 拟合") + THEME_STAT
  p2 <- ggplot(d, aes(sample = std)) + stat_qq() + stat_qq_line() + labs(title = "Q-Q 图") + THEME_STAT
  p3 <- ggplot(d, aes(fitted, sqrt(abs(std)))) + geom_point(alpha = 0.5) + geom_smooth(method = "loess", se = FALSE) +
        labs(title = "尺度-位置") + THEME_STAT
  p4 <- ggplot(d, aes(lev, std)) + geom_point(aes(size = cook), alpha = 0.5) +
        geom_hline(yintercept = c(-2, 2), linetype = "dashed") + labs(title = "杠杆 vs 标准化残差") + THEME_STAT
  list(p1 = p1, p2 = p2, p3 = p3, p4 = p4)
}

# 9) 树状图 (聚类) — 用 ggdendro
chart_dendrogram <- function(hclust_obj, k = NULL, title = "层次聚类树状图") {
  if (!requireNamespace("ggdendro", quietly = TRUE)) {
    # 退化:base plot 转 ggplot 不容易,改返回简单提示
    return(ggplot() + annotate("text", x = 0.5, y = 0.5, label = "需 ggdendro 包") + THEME_STAT)
  }
  dd <- ggdendro::dendro_data(hclust_obj)
  ggplot(ggdendro::segment(dd)) + geom_segment(aes(x = x, y = y, xend = xend, yend = yend)) +
    labs(title = title, x = NULL, y = "距离") + THEME_STAT +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
}

# 10) 效应量图 (Cohen's d 等的柱状)
chart_effect_size <- function(df, label_col = "label", d_col = "d", title = "效应量") {
  df$mag <- cut(abs(df[[d_col]]), breaks = c(-Inf, 0.2, 0.5, 0.8, Inf),
                labels = c("可忽略", "小", "中", "大"))
  ggplot(df, aes(x = reorder(.data[[label_col]], .data[[d_col]]), y = .data[[d_col]], fill = mag)) +
    geom_col() + coord_flip() + scale_fill_brewer(palette = "RdYlBu") +
    geom_hline(yintercept = c(0.2, 0.5, 0.8), linetype = "dashed", color = "gray") +
    labs(title = title, x = NULL, y = "Cohen's d", fill = "量级") + THEME_STAT
}
