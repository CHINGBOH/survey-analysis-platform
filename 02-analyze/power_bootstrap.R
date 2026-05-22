#!/usr/bin/env Rscript
source("lib/db.R"); source("lib/utils.R"); library(boot); module_header("Bootstrap + Power")
for (sid in target_surveys()) {
  df <- read_respondents(sid)
  # Bootstrap 均值
  imp <- df$impact_num[!is.na(df$impact_num)]
  bs <- boot(imp, function(d,i) mean(d[i]), R=5000)
  bci <- boot.ci(bs, type=c("perc","bca"))
  # Power
  power_val <- tryCatch({
    n1 <- sum(df$gender_bin==1,na.rm=T); n2 <- sum(df$gender_bin==0,na.rm=T)
    d_obs <- abs(mean(df$impact_num[df$gender_bin==1],na.rm=T)-mean(df$impact_num[df$gender_bin==0],na.rm=T))/sd(df$impact_num,na.rm=T)
    pwr::pwr.t2n.test(n1=n1,n2=n2,d=d_obs,sig.level=0.05)$power
  }, error=function(e) NA)
  r <- list(bootstrap=list(mean=mean(bs$t),ci_l=bci$percent[4],ci_u=bci$percent[5]), power=power_val)
  saveRDS(r, sprintf("output/results/power_bootstrap_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("Bootstrap+Power完成")
