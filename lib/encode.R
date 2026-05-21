# lib/encode.R — 调查问卷通用编码函数
# 输入: raw Excel data.frame
# 输出: cleaned data.frame (数值+因子)

library(tidyverse)
library(readxl)

#' 加载原始问卷数据
#' @param path Excel 文件路径
#' @return raw data.frame
load_survey <- function(path) {
  read_excel(path, sheet=1)
}

#' 调查一编码（大学生为主，208条×39列）
encode_survey1 <- function(df) {
  df %>% mutate(
    gender_cat  = factor(if_else(`1、您的性别:` == "男", "男", "女")),
    gender_bin  = if_else(gender_cat == "男", 1L, 0L),

    age_cat = factor(`2、您的年龄:`,
      levels = c("18岁以下", "18-20岁", "21-23岁", "24岁及以上")),
    age_num = case_when(
      `2、您的年龄:` == "18岁以下" ~ 1L,
      `2、您的年龄:` == "18-20岁" ~ 2L,
      `2、您的年龄:` == "21-23岁" ~ 3L,
      TRUE ~ 4L
    ),

    status_cat = case_when(
      str_detect(`3、您目前的身份是`, "大学生") ~ "学生",
      str_detect(`3、您目前的身份是`, "在职") ~ "在职",
      str_detect(`3、您目前的身份是`, "自由") ~ "自由职业",
      TRUE ~ "其他"
    ),

    expense_num = case_when(
      `4、 您每月可支配的生活费大约为:` == "800元以下" ~ 800,
      `4、 您每月可支配的生活费大约为:` == "801-1500元" ~ 1150,
      `4、 您每月可支配的生活费大约为:` == "1501-2500元" ~ 2000,
      `4、 您每月可支配的生活费大约为:` == "2501-3500元" ~ 3000,
      `4、 您每月可支配的生活费大约为:` == "3501元以上" ~ 4000,
      TRUE ~ NA_real_
    ),

    used_cat  = factor(if_else(str_detect(`6、您是否使用过数字消费券?`, "是"), "已使用", "未使用")),
    used_bin  = if_else(used_cat == "已使用", 1L, 0L),

    freq_num = case_when(
      str_detect(`7、您平均每月使用数字消费券的次数:`, "1-3") ~ 1L,
      str_detect(`7、您平均每月使用数字消费券的次数:`, "4-6") ~ 2L,
      str_detect(`7、您平均每月使用数字消费券的次数:`, "7-10") ~ 3L,
      str_detect(`7、您平均每月使用数字消费券的次数:`, "10次") ~ 4L,
      TRUE ~ NA_integer_
    ),

    unnecessary_bin = case_when(
      `11、您是否曾因使用消费券而购买原本不需要的商品?` == "是" ~ 1L,
      `11、您是否曾因使用消费券而购买原本不需要的商品?` == "否" ~ 0L,
      TRUE ~ NA_integer_
    ),

    extra_num = case_when(
      str_detect(`12、您每月因使用消费券而增加的消费金额大约为:`, "50元以下") ~ 25,
      str_detect(`12、您每月因使用消费券而增加的消费金额大约为:`, "51-100") ~ 75,
      str_detect(`12、您每月因使用消费券而增加的消费金额大约为:`, "101-200") ~ 150,
      str_detect(`12、您每月因使用消费券而增加的消费金额大约为:`, "201-500") ~ 350,
      str_detect(`12、您每月因使用消费券而增加的消费金额大约为:`, "501") ~ 600,
      TRUE ~ NA_real_
    ),

    saving_num = case_when(
      `14、您使用消费券时平均每次节省的金额大约为:` == "10元以下" ~ 5,
      `14、您使用消费券时平均每次节省的金额大约为:` == "11-30元" ~ 20,
      `14、您使用消费券时平均每次节省的金额大约为:` == "31-50元" ~ 40,
      `14、您使用消费券时平均每次节省的金额大约为:` == "51-100元" ~ 75,
      `14、您使用消费券时平均每次节省的金额大约为:` == "100元以上" ~ 150,
      TRUE ~ NA_real_
    ),

    impact_num = case_when(
      `24、数字消费券对您消费行为的影响程度:` == "仅购买原计划商品" ~ 1L,
      `24、数字消费券对您消费行为的影响程度:` == "基本不影响消费习惯" ~ 2L,
      `24、数字消费券对您消费行为的影响程度:` == "小幅提升消费意愿" ~ 3L,
      `24、数字消费券对您消费行为的影响程度:` == "显著增加消费支出" ~ 4L,
      `24、数字消费券对您消费行为的影响程度:` == "导致非必要消费" ~ 5L,
      TRUE ~ NA_integer_
    ),

    # Likert-5 新型券接受度
    ai_accept     = as.numeric(df[[26]]),
    meta_accept   = as.numeric(df[[27]]),
    green_accept  = as.numeric(df[[28]]),
    second_accept = as.numeric(df[[29]]),

    attention_num = case_when(
      `28、您是否关注消费券的使用规则和限制条件?` == "完全不关注" ~ 1L,
      `28、您是否关注消费券的使用规则和限制条件?` == "不太关注" ~ 2L,
      `28、您是否关注消费券的使用规则和限制条件?` == "一般" ~ 3L,
      `28、您是否关注消费券的使用规则和限制条件?` == "比较关注" ~ 4L,
      `28、您是否关注消费券的使用规则和限制条件?` == "非常关注" ~ 5L,
      TRUE ~ NA_integer_
    ),

    # 列36含弯引号，用索引
    dynamic_num = case_when(
      df[[36]] == "非常不支持" ~ 1L,
      df[[36]] == "不太支持" ~ 2L,
      df[[36]] == "一般" ~ 3L,
      df[[36]] == "比较支持" ~ 4L,
      df[[36]] == "非常支持" ~ 5L,
      TRUE ~ NA_integer_
    ),

    env_willing_bin = if_else(`30、您是否愿意使用针对环保产品的专属消费券?` == "是", 1L, 0L),

    sustainable_num = case_when(
      `27、您如何看待消费券与可持续消费之间的关系?` == "促进绿色消费" ~ 4L,
      `27、您如何看待消费券与可持续消费之间的关系?` == "可能导致过度消费" ~ 2L,
      `27、您如何看待消费券与可持续消费之间的关系?` == "无明显关联" ~ 3L,
      TRUE ~ NA_integer_
    ),

    duration_min = as.numeric(str_extract(`所用时间`, "\\d+")) / 60
  ) %>% dplyr::select(
    gender_cat, gender_bin, age_cat, age_num, status_cat,
    expense_num, used_cat, used_bin, freq_num,
    unnecessary_bin, extra_num, saving_num,
    impact_num, ai_accept, meta_accept, green_accept, second_accept,
    attention_num, dynamic_num, env_willing_bin, sustainable_num,
    duration_min
  )
}

#' 调查二编码（学生+在职混合人群，205条×29列）
encode_survey2 <- function(df) {
  df %>% mutate(
    gender_cat  = factor(if_else(`1、性别` == "男", "男", "女")),
    gender_bin  = if_else(gender_cat == "男", 1L, 0L),

    age_cat = factor(`2、年龄`,
      levels = c("16-20", "21-23", "24-26", "27岁及以上")),
    age_num = case_when(
      `2、年龄` == "16-20" ~ 1L, `2、年龄` == "21-23" ~ 2L,
      `2、年龄` == "24-26" ~ 3L, TRUE ~ 4L
    ),

    status_cat = case_when(
      str_detect(`3、您的职业类型是`, "学生") ~ "学生",
      str_detect(`3、您的职业类型是`, "在职") ~ "在职",
      str_detect(`3、您的职业类型是`, "自由") ~ "自由职业",
      TRUE ~ "其他"
    ),

    income_num = case_when(
      `4、月可支配收入` == "＜1500元" ~ 1000,
      str_detect(`4、月可支配收入`, "1501") ~ 2200,
      str_detect(`4、月可支配收入`, "3001") ~ 4000,
      str_detect(`4、月可支配收入`, "5000") ~ 6000,
      TRUE ~ NA_real_
    ),

    used_cat  = factor(if_else(str_detect(`5、是否使用过消费券`, "是"), "已使用", "未使用")),
    used_bin  = if_else(used_cat == "已使用", 1L, 0L),

    freq_num = case_when(
      str_detect(`6、月均使用次数`, "1-3") ~ 1L,
      str_detect(`6、月均使用次数`, "4-6") ~ 2L,
      str_detect(`6、月均使用次数`, "7次") ~ 3L,
      TRUE ~ NA_integer_
    ),

    impulse_bin = case_when(
      `9、是否曾因优惠购买非计划商品？` == "是" ~ 1L,
      `9、是否曾因优惠购买非计划商品？` == "否" ~ 0L,
      TRUE ~ NA_integer_
    ),

    extra_num = case_when(
      str_detect(`10、月均因券增加的消费额`, "＜50|50元") ~ 25,
      str_detect(`10、月均因券增加的消费额`, "51-100") ~ 75,
      str_detect(`10、月均因券增加的消费额`, "101-200") ~ 150,
      str_detect(`10、月均因券增加的消费额`, ">200|201") ~ 300,
      TRUE ~ NA_real_
    ),

    impact_num = case_when(
      `11、消费券对您消费行为的主要影响是` == "基本无影响" ~ 2L,
      `11、消费券对您消费行为的主要影响是` == "小幅提升消费意愿" ~ 3L,
      `11、消费券对您消费行为的主要影响是` == "显著增加消费支出" ~ 4L,
      `11、消费券对您消费行为的主要影响是` == "导致冲动消费" ~ 5L,
      TRUE ~ NA_integer_
    ),

    # 列22含弯引号, 列24-27含弯引号
    dynamic_num = case_when(
      df[[22]] == "支持" ~ 5L, df[[22]] == "无所谓" ~ 3L, df[[22]] == "不支持" ~ 1L,
      TRUE ~ NA_integer_
    ),

    env_will_bin = if_else(str_detect(`19、您是否愿意使用针对环保产品的专属消费券？`, "愿意"), 1L, 0L),

    ai_accept     = as.numeric(df[[24]]),
    meta_accept   = as.numeric(df[[25]]),
    green_accept  = as.numeric(df[[26]]),
    second_accept = as.numeric(df[[27]]),

    duration_min = as.numeric(str_extract(`所用时间`, "\\d+")) / 60
  ) %>% dplyr::select(
    gender_cat, gender_bin, age_cat, age_num, status_cat,
    income_num, used_cat, used_bin, freq_num,
    impulse_bin, extra_num, impact_num,
    dynamic_num, env_will_bin,
    ai_accept, meta_accept, green_accept, second_accept,
    duration_min
  )
}
