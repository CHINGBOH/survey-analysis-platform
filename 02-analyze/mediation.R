#!/usr/bin/env Rscript
source("lib/db.R"); source("lib/utils.R"); library(boot); module_header("中介效应")
for (sid in target_surveys()) {
  df <- read_respondents(sid)
  med_df <- df %>% mutate(
    accept_mean = rowMeans(cbind(ai_accept,meta_accept,green_accept,second_accept),na.rm=T)
  ) %>% dplyr::select(impact_num, accept_mean, extra_spend) %>% na.omit()
  if (nrow(med_df)<20) { saveRDS(list(error="样本不足"), sprintf("output/results/mediation_%s.rds", if(sid=="survey1")"s1" else "s2")); next }
  m1 <- lm(extra_spend ~ impact_num, data=med_df)
  m2 <- lm(accept_mean ~ impact_num, data=med_df)
  m3 <- lm(extra_spend ~ impact_num + accept_mean, data=med_df)
  a <- coef(m2)[2]; b <- coef(m3)[3]; ind <- a*b
  sobel_z <- ind / sqrt(a^2*summary(m3)$coefficients[3,2]^2 + b^2*summary(m2)$coefficients[2,2]^2)
  boot_fn <- function(d,i) { dd<-d[i,]; coef(lm(accept_mean~impact_num,dd))[2]*coef(lm(extra_spend~impact_num+accept_mean,dd))[3] }
  bs <- boot(med_df, boot_fn, R=5000); bci <- boot.ci(bs, type="perc")
  r <- list(baron_kenny=list(c=coef(m1)[2],a=a,b=b,cp=coef(m3)[2]), sobel=list(ind=ind,z=sobel_z,p=2*(1-pnorm(abs(sobel_z)))), bootstrap=list(ci_l=bci$percent[4],ci_u=bci$percent[5]))
  saveRDS(r, sprintf("output/results/mediation_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("中介效应完成")
