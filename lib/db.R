# lib/db.R — SQLite 数据访问层
# R 分析模块通过此文件统一访问数据库

.libPaths(c("~/R/libs", .libPaths()))
library(DBI); library(dplyr); library(tidyr)

#' 连接 SQLite 数据库
connect_db <- function(survey_id) {
  path <- sprintf("data/db/%s.db", survey_id)
  if (!file.exists(path)) stop("Database not found: ", path)
  dbConnect(RSQLite::SQLite(), path)
}

#' 读取受访者表（宽表）
read_respondents <- function(survey_id) {
  con <- connect_db(survey_id)
  on.exit(dbDisconnect(con))
  dbReadTable(con, "respondents")
}

#' 读取长格式响应表（合并受访者信息）
read_responses <- function(survey_id) {
  con <- connect_db(survey_id)
  on.exit(dbDisconnect(con))
  dbGetQuery(con, "
    SELECT r.respondent_id, rs.survey, rs.gender, rs.age_group, rs.status,
           r.variable, r.value, r.category, r.label
    FROM responses r
    JOIN respondents rs ON r.respondent_id = rs.id
    ORDER BY r.respondent_id, r.variable
  ")
}

#' 读取变量元数据
read_variables <- function(survey_id) {
  con <- connect_db(survey_id)
  on.exit(dbDisconnect(con))
  dbReadTable(con, "variables")
}

#' 直接 SQL 查询
query_db <- function(survey_id, sql) {
  con <- connect_db(survey_id)
  on.exit(dbDisconnect(con))
  dbGetQuery(con, sql)
}

#' 将长格式响应转为宽格式（pivot）
#' @param survey_id 调查 ID
#' @param variables 要 pivot 的变量名向量
#' @return data.frame 每行=1人, 每列=1变量
pivot_responses <- function(survey_id, variables=NULL) {
  con <- connect_db(survey_id)
  on.exit(dbDisconnect(con))

  if (is.null(variables)) {
    vars <- dbGetQuery(con, "SELECT DISTINCT variable FROM responses")$variable
  } else {
    vars <- variables
  }

  sql <- sprintf("
    SELECT respondent_id, variable, value
    FROM responses
    WHERE variable IN (%s)
  ", paste(sprintf("'%s'", vars), collapse=","))

  long <- dbGetQuery(con, sql)
  # pivot to wide
  wide <- tidyr::pivot_wider(long, names_from=variable, values_from=value)
  return(wide)
}
