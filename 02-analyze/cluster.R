#!/usr/bin/env Rscript
source("lib/db.R"); source("lib/utils.R"); library(MASS); module_header("聚类分析")
for (sid in c("survey1","survey2")) {
  df <- read_respondents(sid)
  kv <- df %>% dplyr::select(impact_num, extra_spend, ai_accept, meta_accept, green_accept) %>% na.omit() %>% scale()
  if (nrow(kv)<30) { saveRDS(list(error="样本不足"), sprintf("output/results/cluster_%s.rds", if(sid=="survey1")"s1" else "s2")); next }
  set.seed(42); km <- kmeans(kv, centers=3, nstart=25)
  # 判别验证
  lda_df <- data.frame(kv, cluster=factor(km$cluster))
  lda_cv <- tryCatch({ l <- lda(cluster~., data=lda_df, CV=TRUE); mean(l$class==lda_df$cluster) }, error=function(e) NA)
  r <- list(kmeans=list(sizes=as.numeric(table(km$cluster)), centers=km$centers), lda_accuracy=lda_cv)
  saveRDS(r, sprintf("output/results/cluster_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("聚类分析完成")
