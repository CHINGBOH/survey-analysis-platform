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
source(file.path(ROOT, "lib", "chart_stat.R"))
source(file.path(ROOT, "lib", "chart_advanced.R"))

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
  # 新结构: obj$independent 行含 因变量/分组变量/组1/组2
  ind <- obj$independent
  if (!is.null(ind) && is.data.frame(ind)) {
    db_path <- file.path(ROOT, "data", "db", paste0(sid, ".db"))
    respondents <- NULL
    if (file.exists(db_path) && requireNamespace("DBI", quietly = TRUE) &&
        requireNamespace("RSQLite", quietly = TRUE)) {
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      respondents <- DBI::dbReadTable(con, "respondents")
      DBI::dbDisconnect(con)
    }
    if (!is.null(respondents)) {
      for (i in seq_len(min(8, nrow(ind)))) {
        row <- ind[i, ]
        vname <- as.character(row$因变量 %||% row$variable %||% NA)
        gname <- as.character(row$分组变量 %||% row$group %||% NA)
        if (is.na(vname) || is.na(gname)) next
        if (!(vname %in% names(respondents)) || !(gname %in% names(respondents))) next
        df <- data.frame(x = as.character(respondents[[gname]]),
                         y = as.numeric(respondents[[vname]]))
        df <- df[!is.na(df$x) & !is.na(df$y), ]
        if (nrow(df) < 5) next
        p_val <- suppressWarnings(as.numeric(row$p_Welch %||% row$`p值` %||% NA))
        p_lbl <- if (!is.na(p_val)) sprintf(" (p=%.3f)", p_val) else ""
        add_chart(paste0("box_", vname, "_by_", gname),
                  sprintf("%s ~ %s%s", vname, gname, p_lbl), "box",
                  chart_box(df, "x", "y",
                            title = sprintf("%s 按 %s 分组%s", vname, gname, p_lbl),
                            xlab = gname, ylab = vname))
      }
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

if (module == "anova") {
  # 新结构: obj$summaries (rbind) + obj$group_means (list)
  sm <- obj$summaries
  if (!is.null(sm) && is.data.frame(sm)) {
    db_path <- file.path(ROOT, "data", "db", paste0(sid, ".db"))
    respondents <- NULL
    if (file.exists(db_path) && requireNamespace("DBI", quietly = TRUE) &&
        requireNamespace("RSQLite", quietly = TRUE)) {
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      respondents <- DBI::dbReadTable(con, "respondents")
      DBI::dbDisconnect(con)
    }
    for (i in seq_len(min(8, nrow(sm)))) {
      row <- sm[i, ]
      vname <- as.character(row$因变量); gname <- as.character(row$分组变量)
      eta2 <- suppressWarnings(as.numeric(row$eta_squared))
      if (!is.na(eta2) && eta2 > 0.95) next  # 跳过完美共线案例
      p_val <- suppressWarnings(as.numeric(row$`p值`))
      # 1. 箱线图(从原始数据)
      if (!is.null(respondents) && vname %in% names(respondents) && gname %in% names(respondents)) {
        df <- data.frame(x = as.character(respondents[[gname]]),
                         y = as.numeric(respondents[[vname]]))
        df <- df[!is.na(df$x) & !is.na(df$y), ]
        if (nrow(df) >= 5) {
          lbl <- if (!is.na(p_val)) sprintf(" (F=%.2f, p=%.3f, η²=%.3f)",
                                            as.numeric(row$F), p_val, eta2) else ""
          add_chart(paste0("box_", vname, "_by_", gname),
                    sprintf("%s 按 %s 分组%s", vname, gname, lbl), "box",
                    chart_box(df, "x", "y",
                              title = sprintf("%s 按 %s 分组%s", vname, gname, lbl),
                              xlab = gname, ylab = vname))
        }
      }
      # 2. 组均值条形图
      key <- sprintf("%s__by__%s", vname, gname)
      gm <- obj$group_means[[key]]
      if (!is.null(gm) && is.data.frame(gm) && "组" %in% names(gm) && "均值" %in% names(gm)) {
        p_bar <- ggplot(gm, aes(x = `组`, y = `均值`, fill = `组`)) +
          geom_col(width = 0.7, show.legend = FALSE) +
          geom_text(aes(label = sprintf("%.2f", `均值`)), vjust = -0.4, size = 3) +
          scale_fill_manual(values = SAP_PALETTE) +
          labs(title = sprintf("%s 各组均值 (%s)", vname, gname),
               x = gname, y = vname) +
          theme_sap()
        add_chart(paste0("mean_", vname, "_by_", gname),
                  sprintf("%s 各组均值", vname), "bar", p_bar)
      }
    }
  }
}

if (module == "regression") {
  # 新结构: obj$linear / obj$logistic 都是 list of {coefficients, ...}
  forest_one <- function(coef_df, key, prefix, title_prefix, ci_lo_col, ci_hi_col, est_col) {
    if (is.null(coef_df) || !is.data.frame(coef_df)) return(invisible())
    cf <- coef_df[coef_df$变量 != "(Intercept)", , drop = FALSE]
    if (nrow(cf) == 0) return(invisible())
    cf$est <- suppressWarnings(as.numeric(cf[[est_col]]))
    cf$lo  <- suppressWarnings(as.numeric(cf[[ci_lo_col]]))
    cf$hi  <- suppressWarnings(as.numeric(cf[[ci_hi_col]]))
    cf <- cf[is.finite(cf$est), , drop = FALSE]
    if (nrow(cf) == 0) return(invisible())
    cf$name <- factor(cf$变量, levels = rev(cf$变量))
    ref_x <- if (prefix == "or") 1 else 0
    p <- ggplot(cf, aes(x = est, y = name)) +
      geom_vline(xintercept = ref_x, linetype = "dashed", color = "grey50") +
      geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.25, color = SAP_PALETTE[1]) +
      geom_point(size = 3.5, color = SAP_PALETTE[1]) +
      labs(title = paste0(title_prefix, ": ", key),
           x = if (prefix == "or") "OR (95% CI)" else "B 估计 (95% CI)",
           y = "") +
      theme_sap()
    add_chart(paste0(prefix, "_forest_", gsub("[^A-Za-z0-9]+", "_", key)),
              paste(title_prefix, key), "forest", p, w = 7.5, h = 5)
  }
  # 线性模型: forest of B + 95%CI
  for (key in names(obj$linear %||% list())) {
    m <- obj$linear[[key]]; if (!is.null(m$error)) next
    forest_one(m$coefficients, key, "lin", "线性回归系数森林图",
               "下95CI", "上95CI", "B估计")
  }
  # Logistic: forest of OR + 95%CI
  for (key in names(obj$logistic %||% list())) {
    m <- obj$logistic[[key]]; if (!is.null(m$error)) next
    forest_one(m$coefficients, key, "or", "Logistic OR 森林图",
               "下95CI", "上95CI", "OR比值比")
    # ROC 曲线
    cf <- m$model_summary
    if (!is.null(cf) && is.data.frame(cf) && !is.na(cf$AUC[1])) {
      # 真 ROC 需要预测分数;此处用 sens/spec 标注的等效图
      auc_v <- cf$AUC[1]; sens <- cf$灵敏度[1]; spec <- cf$特异度[1]
      roc_df <- data.frame(FPR = c(0, 1 - spec, 1), TPR = c(0, sens, 1))
      p_roc <- ggplot(roc_df, aes(x = FPR, y = TPR)) +
        geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
        geom_line(color = SAP_PALETTE[2], linewidth = 1.2) +
        geom_point(color = SAP_PALETTE[2], size = 3) +
        annotate("text", x = 0.6, y = 0.2,
                 label = sprintf("AUC = %.3f", auc_v), size = 5) +
        coord_equal() +
        labs(title = paste("Logistic ROC:", key),
             x = "1 - 特异度 (FPR)", y = "灵敏度 (TPR)") +
        theme_sap()
      add_chart(paste0("roc_", gsub("[^A-Za-z0-9]+", "_", key)),
                paste("ROC", key), "roc", p_roc, w = 6, h = 6)
    }
  }
}

# ── 因子分析: 碎石 + 载荷热力 + 双标 ─────────────────────────
if (module == "factor_analysis") {
  for (nm in names(obj$pca %||% list())) {
    pc <- obj$pca[[nm]]
    if (!is.null(pc$eigenvalues)) {
      add_chart(paste0("scree_", nm), paste("碎石图", nm), "scree",
                chart_scree(pc$eigenvalues$特征值), w = 6, h = 4)
    }
    if (!is.null(pc$loadings)) {
      add_chart(paste0("loadings_", nm), paste("载荷热力", nm), "heatmap",
                chart_heatmap(pc$loadings, title = paste("因子载荷", nm)), w = 6, h = 5)
    }
  }
}

# ── 聚类: 簇大小柱 + 树状图 + 中心热力 ───────────────────────
if (module == "cluster") {
  for (nm in names(obj$kmeans %||% list())) {
    km <- obj$kmeans[[nm]]
    if (!is.null(km$cluster_sizes)) {
      d <- km$cluster_sizes
      p <- ggplot(d, aes(factor(cluster), n, fill = factor(cluster))) +
        geom_col() + labs(title = paste("簇规模", nm), x = "簇", y = "样本数") +
        theme_sap() + theme(legend.position = "none")
      add_chart(paste0("kmeans_size_", nm), paste("KMeans 簇规模", nm), "bar", p, w = 5, h = 4)
    }
    if (!is.null(km$centers)) {
      mat <- as.matrix(km$centers[, !names(km$centers) %in% c("cluster", "size")])
      rownames(mat) <- paste0("C", km$centers$cluster)
      add_chart(paste0("kmeans_centers_", nm), paste("KMeans 中心", nm), "heatmap",
                chart_heatmap(mat, title = paste("簇中心 (标准化)", nm)), w = 6, h = 4)
    }
  }
  for (nm in names(obj$hclust %||% list())) {
    hc <- obj$hclust[[nm]]
    if (!is.null(hc$hclust)) {
      add_chart(paste0("dendro_", nm), paste("层次聚类树", nm), "dendro",
                chart_dendrogram(hc$hclust, k = hc$k), w = 7, h = 4)
    }
  }
}

# ── 信度: 项目-总相关 柱 + 删除后 α 变化 ──────────────────────
if (module == "reliability") {
  for (nm in names(obj$scales %||% list())) {
    sc <- obj$scales[[nm]]
    if (is.null(sc$item_stats)) next
    p <- ggplot(sc$item_stats, aes(reorder(变量, 校正项总), 校正项总)) +
      geom_col(fill = "#1f77b4") + coord_flip() +
      geom_hline(yintercept = 0.3, linetype = "dashed", color = "red") +
      labs(title = paste("项-总相关", nm), x = NULL, y = "校正后项-总相关") + theme_sap()
    add_chart(paste0("item_total_", nm), paste("项目分析", nm), "bar", p, w = 6, h = 4)
    p2 <- ggplot(sc$item_stats, aes(reorder(变量, 删除后α), 删除后α)) +
      geom_col(fill = "#ff7f0e") + coord_flip() +
      geom_hline(yintercept = sc$alpha_raw, linetype = "dashed", color = "red") +
      labs(title = paste("删除项后 α", nm), x = NULL,
           y = sprintf("删除后 α (当前 α=%.3f)", sc$alpha_raw)) + theme_sap()
    add_chart(paste0("alpha_drop_", nm), paste("删除项后 α", nm), "bar", p2, w = 6, h = 4)
  }
}

# ── 问卷专用: Likert 堆叠 + Top2/NPS + 缺失 + 异常 + 情感 ─────
if (module == "survey_specific") {
  # Likert 分布堆叠
  if (!is.null(obj$likert$distribution)) {
    d <- obj$likert$distribution
    p <- ggplot(d, aes(变量, 占比_pct, fill = factor(分值))) +
      geom_col() + coord_flip() +
      scale_fill_brewer(palette = "RdYlGn", name = "分值", direction = -1) +
      labs(title = "Likert 量表分布", x = NULL, y = "占比 (%)") + theme_sap()
    add_chart("likert_stack", "Likert 分布堆叠", "stacked_bar", p, w = 7, h = max(4, nrow(d)/6))
  }
  if (!is.null(obj$likert$summary)) {
    s <- obj$likert$summary
    p <- ggplot(s, aes(reorder(变量, Top2Box), Top2Box)) +
      geom_col(fill = "#2ca02c") + coord_flip() +
      geom_text(aes(label = sprintf("%.1f%%", Top2Box)), hjust = -0.2, size = 3) +
      labs(title = "Top2Box 满意度", x = NULL, y = "Top2 (%)") + theme_sap() +
      ylim(0, max(s$Top2Box) * 1.15)
    add_chart("top2box", "Top2Box", "bar", p, w = 6, h = 4)
    p2 <- ggplot(s, aes(reorder(变量, NPS), NPS, fill = NPS > 0)) +
      geom_col() + coord_flip() +
      scale_fill_manual(values = c(`TRUE` = "#2ca02c", `FALSE` = "#d62728"), guide = "none") +
      geom_hline(yintercept = 0, color = "black") +
      labs(title = "NPS 净推荐值", x = NULL, y = "NPS") + theme_sap()
    add_chart("nps", "NPS", "bar", p2, w = 6, h = 4)
  }
  # 缺失率
  if (!is.null(obj$missing)) {
    m <- obj$missing[obj$missing$缺失数 > 0, ]
    if (nrow(m) > 0) {
      p <- ggplot(m, aes(reorder(变量, 缺失率_pct), 缺失率_pct)) +
        geom_col(fill = "#d62728") + coord_flip() +
        labs(title = "缺失率", x = NULL, y = "缺失率 (%)") + theme_sap()
      add_chart("missing_rate", "缺失率", "bar", p, w = 6, h = max(3, nrow(m)/4))
    }
  }
  # 异常 Z-score
  if (!is.null(obj$outliers$zscore)) {
    z <- obj$outliers$zscore
    p <- ggplot(z, aes(reorder(变量, n异常), n异常)) +
      geom_col(fill = "#ff7f0e") + coord_flip() +
      labs(title = "异常值检测 (|Z|>3)", x = NULL, y = "异常样本数") + theme_sap()
    add_chart("outliers_z", "异常值 Z-score", "bar", p, w = 6, h = 4)
  }
  # 情感
  if (!is.null(obj$text$sentiment) && nrow(obj$text$sentiment) > 0) {
    s <- obj$text$sentiment
    long <- data.frame(
      变量 = rep(s$变量, 3),
      类型 = factor(rep(c("正面", "中性", "负面"), each = nrow(s)), levels = c("负面", "中性", "正面")),
      占比 = c(s$pos_pct, s$neutral_pct, s$neg_pct)
    )
    p <- ggplot(long, aes(变量, 占比, fill = 类型)) +
      geom_col() + coord_flip() +
      scale_fill_manual(values = c("正面" = "#2ca02c", "中性" = "#888", "负面" = "#d62728")) +
      labs(title = "开放题情感占比", x = NULL, y = "%") + theme_sap()
    add_chart("sentiment", "开放题情感", "stacked_bar", p, w = 6, h = 4)
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
