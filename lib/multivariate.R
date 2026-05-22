# lib/multivariate.R — SPSS 等价多元统计 (Factor / PCA / Cluster / Discriminant / Reliability / Item)
.libPaths(c("~/R/libs", .libPaths()))
suppressPackageStartupMessages({
  library(psych); library(MASS)
})

.fmt <- function(x, d = 4) ifelse(is.na(x), NA_real_, round(x, d))

# === KMO + Bartlett (前置检验) =============================================
kmo_bartlett <- function(df) {
  df <- na.omit(df)
  if (ncol(df) < 2 || nrow(df) < ncol(df) + 1) {
    return(list(error = "样本/变量数不足"))
  }
  k <- tryCatch(psych::KMO(df), error = function(e) NULL)
  bt <- tryCatch(psych::cortest.bartlett(cor(df), n = nrow(df)), error = function(e) NULL)
  list(
    kmo_overall = if (!is.null(k)) .fmt(k$MSA) else NA_real_,
    kmo_item    = if (!is.null(k)) data.frame(变量 = names(k$MSAi), MSA = .fmt(k$MSAi), row.names = NULL) else NULL,
    bartlett_chi2 = if (!is.null(bt)) .fmt(bt$chisq, 3) else NA_real_,
    bartlett_df   = if (!is.null(bt)) bt$df else NA_integer_,
    bartlett_p    = if (!is.null(bt)) .fmt(bt$p.value, 6) else NA_real_,
    interp = if (!is.null(k)) {
      if (k$MSA >= 0.9) "极佳" else if (k$MSA >= 0.8) "很好" else if (k$MSA >= 0.7) "中等" else if (k$MSA >= 0.6) "尚可" else "不适合"
    } else NA_character_
  )
}

# === PCA (主成分分析) ======================================================
pca_analysis <- function(df, n_factors = NULL, rotate = "varimax") {
  df <- na.omit(df)
  if (ncol(df) < 2 || nrow(df) < 10) return(list(error = "样本不足"))
  p_full <- tryCatch(psych::principal(df, nfactors = ncol(df), rotate = "none"),
                     error = function(e) return(list(error = e$message)))
  if (!is.null(p_full$error)) return(p_full)
  eig <- p_full$values
  if (is.null(n_factors)) n_factors <- max(1, sum(eig > 1))
  n_factors <- min(n_factors, ncol(df) - 1)
  p_rot <- psych::principal(df, nfactors = n_factors, rotate = rotate)
  list(
    eigenvalues = data.frame(成分 = seq_along(eig), 特征值 = .fmt(eig),
                             方差解释_pct = .fmt(eig / sum(eig) * 100, 2),
                             累计_pct = .fmt(cumsum(eig) / sum(eig) * 100, 2)),
    n_factors = n_factors,
    rotation = rotate,
    variance_explained = .fmt(p_rot$Vaccounted, 4),
    loadings = round(unclass(p_rot$loadings), 4),
    communality = data.frame(变量 = names(p_rot$communality), 共同度 = .fmt(p_rot$communality), row.names = NULL)
  )
}

# === EFA (探索性因子分析,主轴法) ===========================================
efa_analysis <- function(df, n_factors = NULL, rotate = "varimax", fm = "pa") {
  df <- na.omit(df)
  if (ncol(df) < 3 || nrow(df) < 30) return(list(error = "EFA 需 ≥3 变量 且 n≥30"))
  if (is.null(n_factors)) {
    p_full <- tryCatch(psych::principal(df, nfactors = ncol(df), rotate = "none"), error = function(e) NULL)
    n_factors <- if (!is.null(p_full)) max(1, sum(p_full$values > 1)) else 2
  }
  n_factors <- min(n_factors, ncol(df) - 1)
  fa <- tryCatch(psych::fa(df, nfactors = n_factors, rotate = rotate, fm = fm),
                 error = function(e) return(list(error = e$message)))
  if (!is.null(fa$error)) return(fa)
  list(
    method = fm, rotation = rotate, n_factors = n_factors,
    loadings = round(unclass(fa$loadings), 4),
    communality = data.frame(变量 = names(fa$communality), 共同度 = .fmt(fa$communality), row.names = NULL),
    variance = .fmt(fa$Vaccounted, 4),
    fit = list(TLI = .fmt(fa$TLI), RMSEA = .fmt(fa$RMSEA[1] %||% NA),
               BIC = .fmt(fa$BIC, 2), chi2 = .fmt(fa$STATISTIC, 3),
               chi2_df = fa$dof, chi2_p = .fmt(fa$PVAL, 6))
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# === KMeans 聚类 ============================================================
kmeans_cluster <- function(df, k = 3, scale = TRUE, nstart = 25) {
  df <- na.omit(df)
  if (nrow(df) < 30 || ncol(df) < 2) return(list(error = "样本/变量不足"))
  X <- if (scale) scale(df) else as.matrix(df)
  set.seed(42)
  km <- tryCatch(kmeans(X, centers = k, nstart = nstart), error = function(e) return(list(error = e$message)))
  if (!is.null(km$error)) return(km)
  centers <- as.data.frame(round(km$centers, 4))
  centers$cluster <- seq_len(nrow(centers))
  centers$size <- as.numeric(table(km$cluster))
  # LDA cross-validation
  lda_acc <- tryCatch({
    ld <- MASS::lda(cluster ~ ., data = data.frame(X, cluster = factor(km$cluster)), CV = TRUE)
    mean(ld$class == factor(km$cluster))
  }, error = function(e) NA_real_)
  # Silhouette
  sil <- NA_real_
  if (requireNamespace("cluster", quietly = TRUE)) {
    s <- tryCatch(cluster::silhouette(km$cluster, dist(X)), error = function(e) NULL)
    if (!is.null(s)) sil <- mean(s[, 3])
  }
  list(
    k = k, n = nrow(X),
    centers = centers,
    cluster_sizes = as.data.frame(table(cluster = km$cluster), responseName = "n"),
    tot_withinss = .fmt(km$tot.withinss, 2),
    betweenss = .fmt(km$betweenss, 2),
    betweenss_totss = .fmt(km$betweenss / km$totss, 4),
    silhouette = .fmt(sil),
    lda_accuracy = .fmt(lda_acc),
    cluster_assignment = km$cluster
  )
}

# === 层次聚类 ===============================================================
hclust_cluster <- function(df, k = 3, method = "ward.D2", scale = TRUE) {
  df <- na.omit(df)
  if (nrow(df) < 10) return(list(error = "样本不足"))
  X <- if (scale) scale(df) else as.matrix(df)
  d <- dist(X)
  hc <- hclust(d, method = method)
  cl <- cutree(hc, k = k)
  list(
    k = k, method = method, n = nrow(X),
    cluster_sizes = as.data.frame(table(cluster = cl), responseName = "n"),
    heights_top10 = .fmt(rev(sort(hc$height))[1:10], 3),
    cluster_assignment = cl,
    hclust = hc
  )
}

# === 判别分析 (Discriminant) ================================================
discriminant_analysis <- function(df, group_var, predictors) {
  df <- na.omit(df[, c(group_var, predictors), drop = FALSE])
  if (nrow(df) < 30 || length(unique(df[[group_var]])) < 2) return(list(error = "样本/组数不足"))
  df[[group_var]] <- factor(df[[group_var]])
  fm <- as.formula(paste(group_var, "~", paste(predictors, collapse = " + ")))
  lda_fit <- tryCatch(MASS::lda(fm, data = df), error = function(e) return(list(error = e$message)))
  if (!is.null(lda_fit$error)) return(lda_fit)
  lda_cv <- tryCatch(MASS::lda(fm, data = df, CV = TRUE), error = function(e) NULL)
  cm <- if (!is.null(lda_cv)) table(实际 = df[[group_var]], 预测 = lda_cv$class) else NULL
  acc <- if (!is.null(cm)) sum(diag(cm)) / sum(cm) else NA_real_
  list(
    group = group_var, predictors = predictors, n = nrow(df),
    prior = .fmt(lda_fit$prior, 4),
    group_means = round(lda_fit$means, 4),
    scaling = round(lda_fit$scaling, 4),
    svd = .fmt(lda_fit$svd),
    confusion_cv = cm,
    accuracy_cv = .fmt(acc)
  )
}

# === 信度 (Cronbach α + Split-half + Item-total) ============================
reliability_analysis <- function(df, items = NULL) {
  if (is.null(items)) items <- names(df)[vapply(df, is.numeric, logical(1))]
  X <- na.omit(df[, items, drop = FALSE])
  if (ncol(X) < 2 || nrow(X) < 5) return(list(error = "项数/样本不足"))
  a <- tryCatch(psych::alpha(X, warnings = FALSE), error = function(e) return(list(error = e$message)))
  if (!is.null(a$error)) return(a)
  sp <- tryCatch(psych::splitHalf(X), error = function(e) NULL)
  list(
    n_items = ncol(X), n = nrow(X),
    alpha_raw = .fmt(a$total$raw_alpha),
    alpha_std = .fmt(a$total$std.alpha),
    guttman_L6 = .fmt(a$total$G6),
    avg_inter_item = .fmt(a$total$average_r),
    split_half_sb = if (!is.null(sp)) .fmt(sp$spearman.brown) else NA_real_,
    split_half_min = if (!is.null(sp)) .fmt(sp$minrb) else NA_real_,
    item_stats = data.frame(
      变量 = rownames(a$item.stats),
      均值 = .fmt(a$item.stats$mean),
      SD = .fmt(a$item.stats$sd),
      项总相关 = .fmt(a$item.stats$r.cor),
      校正项总 = .fmt(a$item.stats$r.drop),
      删除后α = .fmt(a$alpha.drop$raw_alpha),
      row.names = NULL
    ),
    interp = {
      x <- a$total$raw_alpha
      if (is.na(x)) NA_character_
      else if (x >= 0.9) "极佳"
      else if (x >= 0.8) "良好"
      else if (x >= 0.7) "可接受"
      else if (x >= 0.6) "勉强"
      else "差,建议修订"
    }
  )
}
