# lib/charts.R — 基础图表库(ggplot2),给所有分析模块共用
# 设计原则:
# - 每个函数返回 ggplot 对象,调用方可继续 + 主题/标签
# - 统一中文友好字体配置(showtext + 内嵌)
# - 颜色统一,SPSS 风格 + 现代审美
# - 输入接受 data.frame / numeric vector,简单常见模式
#
# 导出:
#   chart_bar / chart_pie / chart_line / chart_scatter
#   chart_box / chart_hist / chart_qq / chart_density
#   save_chart(p, path, w, h) — 统一保存(PNG)

suppressPackageStartupMessages({
  .libPaths(c("~/R/libs", .libPaths()))
  library(ggplot2)
  library(scales)
})

# ── 中文字体(若可用)────────────────────────────────────────────
.setup_font <- function() {
  if (!requireNamespace("showtext", quietly = TRUE)) return(invisible(NULL))
  showtext::showtext_auto(enable = TRUE)
  # 优先用系统中已有的中文字体
  if (requireNamespace("sysfonts", quietly = TRUE)) {
    candidates <- c("Noto Sans CJK SC", "Source Han Sans CN", "WenQuanYi Micro Hei",
                    "Microsoft YaHei", "PingFang SC", "SimHei")
    sys_fonts <- tryCatch(sysfonts::font_families(), error = function(e) character(0))
    for (fam in candidates) {
      if (fam %in% sys_fonts) {
        sysfonts::font_add(family = "cjk", regular = fam)
        return(invisible("cjk"))
      }
    }
  }
  invisible(NULL)
}
.setup_font()

# ── 统一主题 ────────────────────────────────────────────────────
SAP_PALETTE <- c("#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2",
                 "#EECA3B", "#B279A2", "#FF9DA6", "#9D755D", "#BAB0AC")

theme_sap <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 2),
      plot.subtitle = element_text(color = "grey30", size = base_size - 1),
      axis.title = element_text(color = "grey20"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      legend.position = "right",
      legend.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold")
    )
}

# ── 内部: 数据归一化 ────────────────────────────────────────────
.as_freq_df <- function(x, label = "类别") {
  # 接受 vector / data.frame(类别+频数)
  if (is.data.frame(x)) {
    df <- x
    # 自动找类别列(字符/因子) + 频数列(数值)
    cat_col <- names(df)[sapply(df, function(c) is.character(c) || is.factor(c))][1]
    num_col <- names(df)[sapply(df, is.numeric)][1]
    if (is.na(cat_col)) cat_col <- names(df)[1]
    if (is.na(num_col)) num_col <- names(df)[2]
    return(data.frame(label = as.character(df[[cat_col]]),
                      value = as.numeric(df[[num_col]])))
  }
  if (is.null(names(x))) {
    tab <- table(x, useNA = "no")
  } else {
    tab <- x
  }
  data.frame(label = names(tab), value = as.numeric(tab))
}

# ── chart_bar: 柱状图(支持频数/百分比)──────────────────────────
chart_bar <- function(data, title = "", subtitle = "", xlab = "", ylab = "频数",
                      horizontal = FALSE, sort_desc = TRUE, show_value = TRUE) {
  df <- .as_freq_df(data)
  if (sort_desc) df$label <- factor(df$label, levels = df$label[order(-df$value)])
  p <- ggplot(df, aes(x = label, y = value, fill = label)) +
    geom_col(width = 0.7, show.legend = FALSE) +
    scale_fill_manual(values = rep(SAP_PALETTE, length.out = nrow(df))) +
    labs(title = title, subtitle = subtitle, x = xlab, y = ylab) +
    theme_sap()
  if (show_value) p <- p + geom_text(aes(label = value), vjust = -0.3, size = 3.5)
  if (horizontal) p <- p + coord_flip()
  p
}

# ── chart_pie: 饼图(实际是 bar+coord_polar)────────────────────
chart_pie <- function(data, title = "", subtitle = "") {
  df <- .as_freq_df(data)
  df$pct <- df$value / sum(df$value) * 100
  df$label2 <- sprintf("%s\n%.1f%%", df$label, df$pct)
  ggplot(df, aes(x = "", y = value, fill = label)) +
    geom_col(width = 1, color = "white") +
    coord_polar(theta = "y") +
    scale_fill_manual(values = rep(SAP_PALETTE, length.out = nrow(df))) +
    geom_text(aes(label = label2),
              position = position_stack(vjust = 0.5), size = 3.2, color = "white") +
    labs(title = title, subtitle = subtitle, x = NULL, y = NULL, fill = "") +
    theme_void(base_size = 12) +
    theme(plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
          plot.subtitle = element_text(color = "grey30", hjust = 0.5),
          legend.position = "right")
}

# ── chart_line: 折线图 ──────────────────────────────────────────
chart_line <- function(data, x, y, group = NULL, title = "", xlab = x, ylab = y) {
  aes_args <- list(x = sym(x), y = sym(y))
  if (!is.null(group)) aes_args$color <- sym(group)
  p <- ggplot(data, do.call(aes, aes_args)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_color_manual(values = SAP_PALETTE) +
    labs(title = title, x = xlab, y = ylab) +
    theme_sap()
  p
}

# ── chart_scatter: 散点图(可加回归线)──────────────────────────
chart_scatter <- function(data, x, y, color = NULL, smooth = TRUE,
                          title = "", xlab = x, ylab = y) {
  aes_args <- list(x = sym(x), y = sym(y))
  if (!is.null(color)) aes_args$color <- sym(color)
  p <- ggplot(data, do.call(aes, aes_args)) +
    geom_point(alpha = 0.6, size = 2) +
    scale_color_manual(values = SAP_PALETTE) +
    labs(title = title, x = xlab, y = ylab) +
    theme_sap()
  if (smooth) p <- p + geom_smooth(method = "lm", se = TRUE, color = "#E45756", linewidth = 0.8)
  p
}

# ── chart_box: 箱线图(分组对比)────────────────────────────────
chart_box <- function(data, x, y, title = "", xlab = x, ylab = y) {
  ggplot(data, aes(x = .data[[x]], y = .data[[y]], fill = .data[[x]])) +
    geom_boxplot(width = 0.6, outlier.alpha = 0.5, show.legend = FALSE) +
    scale_fill_manual(values = SAP_PALETTE) +
    labs(title = title, x = xlab, y = ylab) +
    theme_sap()
}

# ── chart_hist: 直方图(+均值线)────────────────────────────────
chart_hist <- function(data, x, bins = 30, title = "", xlab = x, ylab = "频数") {
  vec <- if (is.data.frame(data)) data[[x]] else data
  vec <- vec[!is.na(vec)]
  mean_val <- mean(vec); median_val <- median(vec)
  df <- data.frame(v = vec)
  ggplot(df, aes(x = v)) +
    geom_histogram(bins = bins, fill = "#4C78A8", color = "white", alpha = 0.85) +
    geom_vline(xintercept = mean_val, color = "#E45756", linetype = "dashed", linewidth = 0.8) +
    geom_vline(xintercept = median_val, color = "#54A24B", linetype = "dotted", linewidth = 0.8) +
    annotate("text", x = mean_val, y = Inf, label = sprintf("均值=%.2f", mean_val),
             vjust = 1.5, hjust = -0.1, color = "#E45756", size = 3.3) +
    labs(title = title, x = xlab, y = ylab) +
    theme_sap()
}

# ── chart_qq: Q-Q 图(正态性判别)──────────────────────────────
chart_qq <- function(data, x = NULL, title = "Q-Q 图(正态性检验)", xlab = "理论分位数", ylab = "样本分位数") {
  vec <- if (is.data.frame(data)) data[[x]] else data
  vec <- vec[!is.na(vec)]
  df <- data.frame(v = vec)
  ggplot(df, aes(sample = v)) +
    stat_qq(color = "#4C78A8", alpha = 0.7) +
    stat_qq_line(color = "#E45756", linewidth = 0.8) +
    labs(title = title, x = xlab, y = ylab) +
    theme_sap()
}

# ── chart_density: 密度图 ──────────────────────────────────────
chart_density <- function(data, x = NULL, title = "", xlab = "") {
  vec <- if (is.data.frame(data)) data[[x]] else data
  vec <- vec[!is.na(vec)]
  df <- data.frame(v = vec)
  ggplot(df, aes(x = v)) +
    geom_density(fill = "#4C78A8", alpha = 0.5, color = "#4C78A8") +
    labs(title = title, x = xlab, y = "密度") +
    theme_sap()
}

# ── save_chart: 统一保存 ────────────────────────────────────────
save_chart <- function(p, path, w = 6.5, h = 4.5, dpi = 120) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggsave(path, plot = p, width = w, height = h, dpi = dpi, bg = "white")
  invisible(path)
}
