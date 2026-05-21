#!/usr/bin/env Rscript
source("lib/db.R"); source("lib/utils.R"); module_header("调节效应")
for (sid in c("survey1","survey2")) {
  df <- read_respondents(sid)
  md <- df %>% dplyr::select(impact_num, extra_spend, gender_bin) %>% na.omit()
  if (nrow(md)<20) { saveRDS(list(error="样本不足"), sprintf("output/results/moderation_%s.rds", if(sid=="survey1")"s1" else "s2")); next }
  md$ic <- scale(md$impact_num, scale=F); md$gc <- md$gender_bin - mean(md$gender_bin)
  ml <- lm(extra_spend ~ ic * gc, data=md)
  mf <- lm(extra_spend ~ impact_num, data=md[md$gender_bin==0,])
  mm <- lm(extra_spend ~ impact_num, data=md[md$gender_bin==1,])
  r <- list(interaction_p=summary(ml)$coefficients[4,4], coef=coef(summary(ml)), simple_slopes=list(female=c(b=coef(mf)[2],p=summary(mf)$coefficients[2,4]), male=c(b=coef(mm)[2],p=summary(mm)$coefficients[2,4])))
  saveRDS(r, sprintf("output/results/moderation_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("调节效应完成")
