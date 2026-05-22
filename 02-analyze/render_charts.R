#!/usr/bin/env Rscript
# 02-analyze/render_charts.R — 把模块 RDS 自动渲染为图表 PNG
# 用法: Rscript 02-analyze/render_charts.R <module> <survey_id>
#   e.g. Rscript 02-analyze/render_charts.R descriptives survey1
#
# 输出:
#   output/charts/<module>_<sid>/*.png
#   output/charts/<module>_<sid>/manifest.json — 每张图的 path + title + type

suppressPackageStartupMessages({
  .libPaths(c("~/R/libs", .libPaths()))
  library(jsonlite)
})

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

# Resolve project root regardless of invocation method
.script_dir <- tryCatch({
  args0 <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args0[grep("^--file=", args0)])
  if (length(file_arg) > 0) normalizePath(dirname(file_arg)) else getwd()
}, error = function(e) getwd())
ROOT <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
if (!dir.exists(ROOT)) ROOT <- getwd()
source(file.path(ROOT, "lib", "charts.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: render_charts.R <module> <survey_id>")
module <- args[1]
sid <- args[2]
suffix <- if (sid == "survey1") "s1" else if (sid == "survey2") "s2" else sid

rds_path <- file.path(ROOT, "output", "results", sprintf("%s_%s.rds", module, suffix))
if (!file.exists(rds_path)) stop(sprintf("RDS 不存在: %s; 请先运行模块", rds_path))

out_dir <- file.path(ROOT, "output", "charts", sprintf("%s_%s", module, suffix))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
# 清理旧图
old <- list.files(out_dir, pattern = "\\.(png|json)$", full.names = TRUE)
file.remove(old)

obj <- readRDS(rds_path)
manifest <- list()
add_chart <- function(name, title, type, p, w = 6.5, h = 4.5) {
  path <- file.path(out_dir, paste0(name, ".png"))
  tryCatch({
    save_chart(p, path, w = w, h = h)
    manifest[[length(manifest) + 1]] <<- list(
      name = name, title = title, type = type,
      file = sprintf("output/charts/%s_%s/%s.png", module, suffix, name)
    )
  }, error = function(e) {
    message(sprintf("跳过 %s: %s", name, conditionMessage(e)))
  })
}

# ── 路由: 不同模块渲染不同图 ──────────────────────────────────
if (module == "descriptives") {
  # 1. 各分类变量频数饼图(前 6 个)
  if (!is.null(obj$frequencies)) {
    cats <- names(obj$frequencies)
    for (cat in head(cats, 6)) {
      df <- obj$frequencies[[cat]]
      if (is.null(df) || nrow(df) == 0) next
      # 跳过 *_bin 的二进制版本(它的 labelled 版本更易读)
      if (grepl("_bin$", cat) && sub("_bin$", "", cat) %in% cats) next
      title <- sprintf("%s 分布", cat)
      if (nrow(df) <= 6) {
        add_chart(paste0("freq_pie_", cat), title, "pie", chart_pie(df, title = title))
      } else {
        add_chart(paste0("freq_bar_", cat), title, "bar",
                  chart_bar(df, title = title, ylab = "频数", horizontal = nrow(df) > 8))
      }
    }
  }

  # 2. 数值变量直方图 + Q-Q(前 6 个)
  if (!is.null(obj$descriptives)) {
    desc <- obj$descriptives
    num_vars <- desc$变量
    # 需要回拿原始数据画图 — 从 SQLite 读
    db_path <- file.path(ROOT, "data", "db", paste0(sid, ".db"))
    if (file.exists(db_path) && requireNamespace("DBI", quietly = TRUE) &&
        requireNamespace("RSQLite", quietly = TRUE)) {
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      respondents <- DBI::dbReadTable(con, "respondents")
      DBI::dbDisconnect(con)
      for (v in head(num_vars, 6)) {
        if (!v %in% names(respondents)) next
        vec <- suppressWarnings(as.numeric(respondents[[v]]))
        if (sum(!is.na(vec)) < 3) next
        add_chart(paste0("hist_", v), sprintf("%s 直方图", v), "hist",
                  chart_hist(vec, title = sprintf("%s 分布", v), xlab = v))
        add_chart(paste0("qq_", v), sprintf("%s Q-Q 图", v), "qq",
                  chart_qq(vec, title = sprintf("%s 正态性检验", v)))
      }
    }
  }
}

if (module == "crosstabs") {
  # 列联表 → 堆叠/分组柱状图。RDS 结构: list of <pair> = list(crosstab, measures, title)
  pair_names <- names(obj)
  for (key in head(pair_names, 6)) {
    entry <- obj[[key]]
    tbl <- if (is.list(entry) && !is.null(entry$crosstab)) entry$crosstab else entry
    if (is.null(tbl)) next
    title <- if (is.list(entry) && !is.null(entry$title)) entry$title else paste("交叉表:", key)
    df_long <- as.data.frame(as.table(as.matrix(tbl)))
    names(df_long) <- c("row", "col", "freq")
    p <- ggplot(df_long, aes(x = row, y = freq, fill = col)) +
      geom_col(position = position_dodge(0.8), width = 0.7) +
      geom_text(aes(label = freq), position = position_dodge(0.8), vjust = -0.3, size = 3) +
      scale_fill_manual(values = SAP_PALETTE) +
      labs(title = title, x = "", y = "频数", fill = "") +
      theme_sap()
    add_chart(paste0("cross_", gsub("[^A-Za-z0-9]+", "_", key)), title, "bar", p)
  }
}

if (module == "ttest") {
  # t 检验 → 箱线图比较 + 均值差异条
  if (!is.null(obj$results) && is.data.frame(obj$results)) {
    for (i in seq_len(min(6, nrow(obj$results)))) {
      row <- obj$results[i, ]
      vname <- row$变量 %||% row$variable %||% row[[1]]
      gname <- row$分组 %||% row$group %||% NA
      if (is.na(vname) || is.na(gname)) next
      # 读取原始数据
      db_path <- file.path(ROOT, "data", "db", paste0(sid, ".db"))
      if (!file.exists(db_path)) next
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      respondents <- DBI::dbReadTable(con, "respondents")
      DBI::dbDisconnect(con)
      if (!(vname %in% names(respondents)) || !(gname %in% names(respondents))) next
      df <- data.frame(x = as.character(respondents[[gname]]),
                       y = as.numeric(respondents[[vname]]))
      df <- df[!is.na(df$x) & !is.na(df$y), ]
      if (nrow(df) < 5) next
      add_chart(paste0("box_", vname, "_by_", gname),
                sprintf("%s ~ %s", vname, gname), "box",
                chart_box(df, "x", "y", title = sprintf("%s 按 %s 分组", vname, gname),
                          xlab = gname, ylab = vname))
    }
  }
}

if (module == "correlation") {
  # 相关矩阵 → 热力图
  if (!is.null(obj$pearson)) {
    mat <- obj$pearson
    df_long <- as.data.frame(as.table(as.matrix(mat)))
    names(df_long) <- c("v1", "v2", "r")
    p <- ggplot(df_long, aes(x = v1, y = v2, fill = r)) +
      geom_tile(color = "white") +
      geom_text(aes(label = sprintf("%.2f", r)), size = 3) +
      scale_fill_gradient2(low = "#4C78A8", mid = "white", high = "#E45756",
                           midpoint = 0, limits = c(-1, 1)) +
      labs(title = "Pearson 相关矩阵", x = "", y = "", fill = "r") +
      theme_sap() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    add_chart("corr_pearson", "Pearson 相关矩阵", "heatmap", p, w = 7.5, h = 6.5)
  }
}

if (module == "regression") {
  # 回归 → 系数 forest plot
  if (!is.null(obj$linear) && is.data.frame(obj$linear)) {
    df <- obj$linear
    coef_col <- intersect(c("Estimate", "beta", "估计"), names(df))[1]
    se_col <- intersect(c("Std.Error", "se", "标准误"), names(df))[1]
    name_col <- intersect(c("term", "变量", "Variable"), names(df))[1]
    if (!is.na(coef_col) && !is.na(name_col)) {
      df$est <- df[[coef_col]]
      df$lo <- if (!is.na(se_col)) df$est - 1.96 * df[[se_col]] else df$est
      df$hi <- if (!is.na(se_col)) df$est + 1.96 * df[[se_col]] else df$est
      df$name <- factor(df[[name_col]], levels = df[[name_col]])
      p <- ggplot(df, aes(x = est, y = name)) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
        geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.2, color = "#4C78A8") +
        geom_point(size = 3, color = "#4C78A8") +
        labs(title = "回归系数(95% CI)", x = "估计值", y = "") +
        theme_sap()
      add_chart("coef_forest", "回归系数森林图", "forest", p)
    }
  }
}

# 兜底: 没有任何图就提示
if (length(manifest) == 0) {
  cat(sprintf("[render_charts] %s@%s 没有可渲染的图(可能模块还未支持)\n", module, sid))
}

# 写 manifest
manifest_path <- file.path(out_dir, "manifest.json")
write(toJSON(list(module = module, survey_id = sid, charts = manifest),
             auto_unbox = TRUE, pretty = TRUE), manifest_path)

cat(sprintf("[render_charts] 完成: %d 张图 → %s\n", length(manifest), out_dir))
