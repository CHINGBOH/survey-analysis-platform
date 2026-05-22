#!/usr/bin/env Rscript
source("lib/spss_tables.R"); source("lib/db.R"); source("lib/utils.R")
library(car); module_header("ANOVA")

for (survey_id in target_surveys()) {
  df <- read_respondents(survey_id)
  aov1 <- aov(impact_num ~ age_group, data=df)
  aov_r <- anova_table(aov1)
  tukey <- TukeyHSD(aov1)
  kw <- kruskal.test(impact_num ~ age_group, data=df)
  man_r <- NULL
  if (survey_id=="survey1") {
    man_df <- df %>% dplyr::select(impact_num, ai_accept, gender) %>% na.omit()
    man <- manova(cbind(impact_num, ai_accept) ~ gender, data=man_df)
    man_r <- list(pillai=summary(man,test="Pillai"), wilks=summary(man,test="Wilks"))
  }
  result <- list(anova=aov_r, tukey=tukey, kruskal=list(chi2=kw$statistic,p=kw$p.value), manova=man_r)
  saveRDS(result, sprintf("output/results/anova_%s.rds", if(survey_id=="survey1")"s1" else "s2"))
}
message("ANOVA完成")
