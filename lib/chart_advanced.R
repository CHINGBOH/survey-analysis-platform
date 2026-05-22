# lib/chart_advanced.R — 高级可视化 (热力图/雷达/桑基/旭日/漏斗/瀑布/词云/网络/平行坐标/地图)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({ library(ggplot2); library(scales) })

THEME_ADV <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"))

# 1) 热力图 (相关矩阵或一般矩阵)
chart_heatmap <- function(mat, title = "热力图", limits = NULL, show_values = TRUE) {
  if (is.null(rownames(mat))) rownames(mat) <- as.character(seq_len(nrow(mat)))
  if (is.null(colnames(mat))) colnames(mat) <- as.character(seq_len(ncol(mat)))
  df <- expand.grid(行 = rownames(mat), 列 = colnames(mat))
  df$值 <- as.vector(mat)
  if (is.null(limits)) limits <- range(df$值, na.rm = TRUE)
  p <- ggplot(df, aes(列, 行, fill = 值)) +
    geom_tile(color = "white") +
    scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
                        midpoint = mean(limits), limits = limits) +
    labs(title = title, x = NULL, y = NULL) + THEME_ADV +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  if (show_values && nrow(mat) <= 20) p <- p + geom_text(aes(label = round(值, 2)), size = 3)
  p
}

# 2) 雷达图 (基于 ggplot polar)
chart_radar <- function(df, group_col = NULL, title = "雷达图") {
  # df: long format with cols: 维度, 值, [组]
  if (is.null(group_col)) {
    df$组 <- "整体"
    group_col <- "组"
  }
  ggplot(df, aes(x = 维度, y = 值, group = .data[[group_col]], color = .data[[group_col]], fill = .data[[group_col]])) +
    geom_polygon(alpha = 0.2) + geom_line(linewidth = 0.8) + geom_point(size = 2) +
    coord_polar() + labs(title = title, x = NULL, y = NULL) + THEME_ADV
}

# 3) 桑基图 (Sankey) — networkD3 输出 HTML;ggplot fallback 用 ggalluvial
chart_sankey <- function(df, source_col = "source", target_col = "target", value_col = "value",
                         title = "桑基图") {
  if (requireNamespace("ggalluvial", quietly = TRUE)) {
    return(ggplot(df, aes(axis1 = .data[[source_col]], axis2 = .data[[target_col]], y = .data[[value_col]])) +
             ggalluvial::geom_alluvium(aes(fill = .data[[source_col]]), alpha = 0.7) +
             ggalluvial::geom_stratum() +
             ggplot2::geom_text(stat = "stratum", aes(label = after_stat(stratum))) +
             labs(title = title) + THEME_ADV)
  }
  # 退化:简单堆叠柱
  ggplot(df, aes(.data[[source_col]], .data[[value_col]], fill = .data[[target_col]])) +
    geom_col() + coord_flip() + labs(title = title) + THEME_ADV
}

# 4) 旭日图 (Sunburst) — 简易实现:基于 coord_polar + 多环
chart_sunburst <- function(df, levels = c("L1", "L2"), value_col = "value", title = "旭日图") {
  # 退化为饼图 (按 L1)
  agg <- aggregate(df[[value_col]], list(L = df[[levels[1]]]), sum)
  names(agg) <- c("L", "v")
  ggplot(agg, aes(x = 2, y = v, fill = L)) + geom_col(width = 1) + coord_polar(theta = "y") +
    xlim(0.5, 2.5) + labs(title = paste(title, "(简化为环形)")) + THEME_ADV
}

# 5) 漏斗图
chart_funnel <- function(df, stage_col = "stage", value_col = "value", title = "漏斗图") {
  df <- df[order(-df[[value_col]]), ]
  df[[stage_col]] <- factor(df[[stage_col]], levels = df[[stage_col]])
  ggplot(df, aes(x = .data[[stage_col]], y = .data[[value_col]])) +
    geom_col(fill = "#1f77b4", alpha = 0.85, width = 0.7) +
    geom_text(aes(label = .data[[value_col]]), vjust = -0.5, size = 4) +
    coord_flip() + labs(title = title) + THEME_ADV
}

# 6) 瀑布图
chart_waterfall <- function(df, label_col = "label", value_col = "value", title = "瀑布图") {
  df$id <- seq_len(nrow(df))
  df$end <- cumsum(df[[value_col]])
  df$start <- c(0, head(df$end, -1))
  df$type <- ifelse(df[[value_col]] >= 0, "增", "减")
  df[[label_col]] <- factor(df[[label_col]], levels = df[[label_col]])
  ggplot(df, aes(x = .data[[label_col]], fill = type)) +
    geom_rect(aes(xmin = id - 0.4, xmax = id + 0.4, ymin = start, ymax = end)) +
    scale_fill_manual(values = c("增" = "#2ca02c", "减" = "#d62728")) +
    labs(title = title, x = NULL, y = "累计值") + THEME_ADV
}

# 7) 词云 (输出 PNG 用 wordcloud2 不便,改用 ggwordcloud)
chart_wordcloud <- function(freq_df, word_col = "词", n_col = "频次", title = "词云", max_n = 80) {
  if (!requireNamespace("ggwordcloud", quietly = TRUE)) {
    # 退化:Top 20 柱状
    top <- head(freq_df[order(-freq_df[[n_col]]), ], 20)
    return(ggplot(top, aes(reorder(.data[[word_col]], .data[[n_col]]), .data[[n_col]])) +
             geom_col(fill = "#1f77b4") + coord_flip() +
             labs(title = paste(title, "(退化为 Top20)"), x = NULL, y = "频次") + THEME_ADV)
  }
  top <- head(freq_df[order(-freq_df[[n_col]]), ], max_n)
  ggplot(top, aes(label = .data[[word_col]], size = .data[[n_col]], color = .data[[n_col]])) +
    ggwordcloud::geom_text_wordcloud_area() + scale_size_area(max_size = 16) +
    scale_color_gradient(low = "#1f77b4", high = "#d62728") +
    labs(title = title) + theme_minimal()
}

# 8) 网络图 (简单 — 节点 + 边)
chart_network <- function(nodes, edges, title = "网络图") {
  if (!requireNamespace("ggraph", quietly = TRUE) || !requireNamespace("igraph", quietly = TRUE)) {
    return(ggplot() + annotate("text", x = 0.5, y = 0.5, label = "需 ggraph/igraph 包") + THEME_ADV)
  }
  g <- igraph::graph_from_data_frame(edges, vertices = nodes, directed = FALSE)
  ggraph::ggraph(g, layout = "fr") + ggraph::geom_edge_link(alpha = 0.5) +
    ggraph::geom_node_point(size = 5, color = "#1f77b4") +
    ggraph::geom_node_text(aes(label = name), repel = TRUE) +
    labs(title = title) + theme_void()
}

# 9) 平行坐标
chart_parallel <- function(df, group_col = NULL, title = "平行坐标") {
  if (!requireNamespace("GGally", quietly = TRUE)) {
    return(ggplot() + annotate("text", x = 0.5, y = 0.5, label = "需 GGally 包") + THEME_ADV)
  }
  vars <- names(df)[sapply(df, is.numeric)]
  if (is.null(group_col)) {
    GGally::ggparcoord(df, columns = match(vars, names(df)), scale = "uniminmax", alphaLines = 0.3) +
      labs(title = title) + THEME_ADV
  } else {
    GGally::ggparcoord(df, columns = match(vars, names(df)), groupColumn = group_col,
                       scale = "uniminmax", alphaLines = 0.5) +
      labs(title = title) + THEME_ADV
  }
}

# 10) 简易省级地图 (中国;需用户提供 GeoJSON,这里给简化占位)
chart_china_map <- function(df, province_col = "province", value_col = "value", title = "中国地图") {
  # 没有 GeoJSON 时退化为柱状
  ggplot(df, aes(reorder(.data[[province_col]], .data[[value_col]]), .data[[value_col]])) +
    geom_col(fill = "#1f77b4") + coord_flip() +
    labs(title = paste(title, "(无 GeoJSON 时退化)"), x = NULL, y = "值") + THEME_ADV
}
