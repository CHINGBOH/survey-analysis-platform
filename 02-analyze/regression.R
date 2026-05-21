#!/usr/bin/env Rscript
source("lib/db.R"); source("lib/utils.R"); library(car); library(lmtest); library(pROC); module_header("回归分析")
for (sid in c("survey1","survey2")) {
  df <- read_respondents(sid)
  # 线性回归
  lm_df <- df %>% dplyr::select(impact_num, extra_spend, saving_amt) %>% na.omit()
  if (nrow(lm_df)>=20) {
    lm1 <- lm(impact_num ~ ., data=lm_df)
    lr <- list(r2=summary(lm1)$r.squared, adj_r2=summary(lm1)$adj.r.squared, coef=coef(summary(lm1)), vif=car::vif(lm1), dw=dwtest(lm1)$statistic)
  } else { lr <- list(error="样本不足") }
  # Logistic
  logit_df <- df %>% dplyr::select(used_bin, gender_bin, impact_num) %>% na.omit()
  if (nrow(logit_df)>=20 && length(unique(logit_df$used_bin))==2) {
    logit1 <- glm(used_bin~., data=logit_df, family=binomial())
    pred <- predict(logit1, type="response")
    roc_obj <- roc(logit_df$used_bin, pred)
    cb <- coords(roc_obj, "best", ret=c("threshold","sensitivity","specificity"))
    nag <- (1-exp((logit1$deviance-logit1$null.deviance)/nrow(logit_df)))/(1-exp(-logit1$null.deviance/nrow(logit_df)))
    lg <- list(or=exp(coef(logit1)), nagelkerke=nag, auc=auc(roc_obj), sensitivity=cb$sensitivity, specificity=cb$specificity, youden=cb$sensitivity+cb$specificity-1)
  } else { lg <- list(error="样本不足") }
  saveRDS(list(linear=lr, logistic=lg), sprintf("output/results/regression_%s.rds", if(sid=="survey1")"s1" else "s2"))
}; message("回归分析完成")
