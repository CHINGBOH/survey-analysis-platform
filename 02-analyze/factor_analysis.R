#!/usr/bin/env Rscript
# 02-analyze/factor_analysis.R — 直接从宽表读
.libPaths(c("~/R/libs", .libPaths()))
library(DBI); library(RSQLite); library(psych); source("lib/utils.R"); module_header("因子分析")

for (survey_id in c("survey1","survey2")) {
  con <- dbConnect(RSQLite::SQLite(), sprintf("data/db/%s.db", survey_id))
  likert <- dbGetQuery(con, sprintf("SELECT ai_accept, meta_accept, green_accept, second_accept FROM respondents WHERE survey='%s'", survey_id))
  dbDisconnect(con)
  likert <- na.omit(likert)
  if (nrow(likert) < 10) { saveRDS(list(error="样本不足"), sprintf("output/results/factor_analysis_%s.rds", if(survey_id=="survey1")"s1" else "s2")); next }
  kmo <- KMO(likert); bt <- cortest.bartlett(cor(likert), n=nrow(likert))
  pca <- principal(likert, nfactors=ncol(likert), rotate="none")
  pca_v <- principal(likert, nfactors=2, rotate="varimax")
  r <- list(kmo=kmo$MSA, bartlett_chi2=bt$chisq, bartlett_df=bt$df,
    eigenvalues=pca$values, var_explained=pca$Vaccounted,
    loadings_varimax=unclass(pca_v$loadings), communality=pca$communality)
  saveRDS(r, sprintf("output/results/factor_analysis_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("因子分析完成")
