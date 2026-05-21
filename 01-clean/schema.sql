-- schema.sql — 问卷调查数据库 schema
-- 设计原则：宽表存受访者 + 长表存多选/Likert + 元数据驱动报告

-- 受访者主表（宽表：每行=1人，每列=1个编码后变量）
CREATE TABLE IF NOT EXISTS respondents (
    id            INTEGER PRIMARY KEY,
    survey        TEXT NOT NULL,           -- 'survey1' | 'survey2'
    -- 人口学
    gender        TEXT,                     -- '男'|'女'
    gender_bin    INTEGER,                 -- 1=男 0=女
    age_group     TEXT,                     -- 年龄段原文
    age_num       INTEGER,                 -- 1-4 有序编码
    status        TEXT,                     -- '学生'|'在职'|'自由职业'|'其他'
    -- 经济
    income_num    REAL,                     -- 月收入/生活费(元)
    -- 消费券行为
    used_voucher  TEXT,                     -- '已使用'|'未使用'
    used_bin      INTEGER,                 -- 1=使用 0=未使用
    freq_num      INTEGER,                 -- 使用频率 1-4
    extra_spend   REAL,                     -- 月均额外消费(元)
    saving_amt    REAL,                     -- 每次节省(元)
    impulse_bin   INTEGER,                 -- 是否冲动购买
    -- 影响与态度
    impact_num    INTEGER,                 -- 影响程度 1-5
    attention_num INTEGER,                 -- 规则关注度 1-5
    dynamic_num   INTEGER,                 -- 动态面额支持 1-5
    sustainable_num INTEGER,              -- 可持续认知 1-4
    env_willing   INTEGER,                 -- 环保意愿 0/1
    -- Likert 量表
    ai_accept     INTEGER,                 -- AI智能推荐券 1-5
    meta_accept   INTEGER,                 -- 元宇宙虚拟商品券 1-5
    green_accept  INTEGER,                 -- 低碳环保商品券 1-5
    second_accept INTEGER,                 -- 二手商品交易补贴券 1-5
    -- 质量控制
    duration_min  REAL,                    -- 答题用时(分钟)
    is_speeder    INTEGER DEFAULT 0        -- 秒答标记
);

-- 长格式响应表（多选、Likert 量表题，每行=1人×1题的响应）
CREATE TABLE IF NOT EXISTS responses (
    respondent_id INTEGER NOT NULL,
    variable      TEXT NOT NULL,            -- 变量名: 'ai_accept', 'vtype_ecommerce', etc.
    value         REAL,                     -- 数值（Likert 1-5, 多选 0/1）
    category      TEXT,                     -- 'likert' | 'multiselect' | 'numeric'
    label         TEXT,                     -- 中文标签
    FOREIGN KEY (respondent_id) REFERENCES respondents(id),
    PRIMARY KEY (respondent_id, variable)
);

-- 变量元数据（驱动报告生成）
CREATE TABLE IF NOT EXISTS variables (
    name         TEXT PRIMARY KEY,          -- 变量名
    label_cn     TEXT,                      -- 中文标签
    type         TEXT,                      -- 'nominal'|'ordinal'|'scale'
    category     TEXT,                      -- 'demographic'|'behavior'|'attitude'|'quality'
    value_labels TEXT,                      -- JSON: {"1":"男","0":"女"} 或 NULL
    survey       TEXT,                      -- 所属调查 'survey1'|'survey2'|'both'
    spss_measure TEXT                       -- SPSS 测量级别: 'nominal'|'ordinal'|'scale'
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_resp_survey ON respondents(survey);
CREATE INDEX IF NOT EXISTS idx_resp_var ON responses(variable);
CREATE INDEX IF NOT EXISTS idx_var_survey ON variables(survey);
