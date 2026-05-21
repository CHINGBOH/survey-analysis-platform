#!/usr/bin/env python3
"""
01-clean/clean_to_sqlite.py
Excel → 编码 → 校验 → SQLite 入库
用法: python3 01-clean/clean_to_sqlite.py [survey1|survey2|all]
"""
import sys, sqlite3, json, re
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_RAW = ROOT / "data/raw"
DB_DIR   = ROOT / "data/db"
SCHEMA   = ROOT / "01-clean/schema.sql"
DB_DIR.mkdir(parents=True, exist_ok=True)

# ============== 通用编码函数 ==============

def safe_int(s):
    """安全转整数"""
    try: return int(float(s))
    except: return None

def bin_from_text(val, true_pattern):
    """文本→0/1"""
    if pd.isna(val): return None
    return 1 if true_pattern in str(val) else 0

def ordinal_map(val, mapping):
    """文本→有序数值"""
    if pd.isna(val): return None
    for text, num in mapping.items():
        if text in str(val): return num
    return None

def mid_value(val, ranges):
    """区间文本→中值"""
    if pd.isna(val): return None
    for pat, mid in ranges.items():
        if re.search(pat, str(val)): return mid
    return None

def split_multiselect(series, sep="┋"):
    """多选文本→{变量:0/1} dict"""
    all_opts = set()
    for v in series.dropna():
        for opt in str(v).split(sep):
            opt = opt.strip()
            if opt and opt != "(跳过)":
                all_opts.add(opt)
    return all_opts

# ============== 调查一编码 ==============

def clean_survey1():
    df = pd.read_excel(DATA_RAW / "问卷数据_完整版_209条.xlsx")
    print(f"调查一: {df.shape[0]} × {df.shape[1]}")

    rows = []
    responses = []
    for _, row in df.iterrows():
        r = {}
        r['survey'] = 'survey1'
        # 人口学
        gender = str(row.iloc[4])
        r['gender'] = '男' if gender == '男' else '女'
        r['gender_bin'] = 1 if gender == '男' else 0

        age = str(row.iloc[5])
        r['age_group'] = age
        r['age_num'] = {'18岁以下':1,'18-20岁':2,'21-23岁':3}.get(age,4)

        status = str(row.iloc[6])
        if '大学生' in status: r['status'] = '学生'
        elif '在职' in status: r['status'] = '在职'
        elif '自由' in status: r['status'] = '自由职业'
        else: r['status'] = '其他'

        # 经济
        expense = str(row.iloc[7])
        r['income_num'] = mid_value(expense, {'800元以下':800,'801-1500':1150,'1501-2500':2000,'2501-3500':3000,'3501以上':4000})

        # 消费券行为
        used = str(row.iloc[9])
        r['used_voucher'] = '已使用' if used == '是' else '未使用'
        r['used_bin'] = 1 if used == '是' else 0

        freq = str(row.iloc[10])
        r['freq_num'] = ordinal_map(freq, {'1-3':1,'4-6':2,'7-10':3,'10次':4})

        impulse = str(row.iloc[14])
        r['impulse_bin'] = 1 if impulse == '是' else (0 if impulse == '否' else None)

        extra = str(row.iloc[15])
        r['extra_spend'] = mid_value(extra, {'50元以下':25,'51-100':75,'101-200':150,'201-500':350,'501':600})

        saving = str(row.iloc[17])
        r['saving_amt'] = mid_value(saving, {'10元以下':5,'11-30':20,'31-50':40,'51-100':75,'100元以上':150})

        # 影响与态度
        impact = str(row.iloc[30])
        r['impact_num'] = {'仅购买原计划商品':1,'基本不影响消费习惯':2,'小幅提升消费意愿':3,'显著增加消费支出':4,'导致非必要消费':5}.get(impact)

        # Likert 接受度 (cols 25-28, 1-indexed: 26-29)
        for i, vname in enumerate(['ai_accept','meta_accept','green_accept','second_accept'], 26):
            val = safe_int(row.iloc[i-1])  # pandas 0-indexed
            if val is not None:
                r[vname] = val
                responses.append({'variable': vname, 'value': val, 'category': 'likert',
                    'label': {'ai_accept':'AI智能推荐券','meta_accept':'元宇宙虚拟商品券','green_accept':'低碳环保商品券','second_accept':'二手商品交易补贴券'}[vname]})

        # 规则关注 (col 34, 0-indexed: 33)
        attn = str(row.iloc[34])
        r['attention_num'] = {'完全不关注':1,'不太关注':2,'一般':3,'比较关注':4,'非常关注':5}.get(attn)

        # 动态面额 (col 35, 0-indexed: 34)
        dyn = str(row.iloc[35])
        r['dynamic_num'] = {'非常不支持':1,'不太支持':2,'一般':3,'比较支持':4,'非常支持':5}.get(dyn)

        # 可持续 (col 33, 0-indexed: 32)
        sus = str(row.iloc[33])
        r['sustainable_num'] = {'促进绿色消费':4,'可能导致过度消费':2,'无明显关联':3}.get(sus)

        # 环保意愿 (col 36, 0-indexed: 35)
        env = str(row.iloc[36])
        r['env_willing'] = 1 if env == '是' else 0

        # 质量控制
        dur = str(row.iloc[2])
        dur_match = re.search(r'(\d+)', dur)
        r['duration_min'] = int(dur_match.group(1))/60 if dur_match else None
        r['is_speeder'] = 1 if r['duration_min'] and r['duration_min'] < 0.5 else 0

        rows.append(r)

    return rows, responses

# ============== 调查二编码 ==============

def clean_survey2():
    df = pd.read_excel(DATA_RAW / "问卷数据_精简版_206条.xlsx")
    print(f"调查二: {df.shape[0]} × {df.shape[1]}")

    rows = []
    responses = []
    for _, row in df.iterrows():
        r = {}
        r['survey'] = 'survey2'

        gender = str(row.iloc[4])
        r['gender'] = '男' if gender == '男' else '女'
        r['gender_bin'] = 1 if gender == '男' else 0

        age = str(row.iloc[5])
        r['age_group'] = age
        r['age_num'] = {'16-20':1,'21-23':2,'24-26':3}.get(age,4)

        status = str(row.iloc[6])
        if '学生' in status: r['status'] = '学生'
        elif '在职' in status: r['status'] = '在职'
        elif '自由' in status: r['status'] = '自由职业'
        else: r['status'] = '其他'

        income = str(row.iloc[7])
        r['income_num'] = mid_value(income, {'＜1500|1500元以下':1000,'1501':2200,'3001':4000,'5000':6000})

        used = str(row.iloc[8])
        r['used_voucher'] = '已使用' if '是' in used else '未使用'
        r['used_bin'] = 1 if '是' in used else 0

        freq = str(row.iloc[9])
        r['freq_num'] = ordinal_map(freq, {'1-3':1,'4-6':2,'7次':3})

        impulse = str(row.iloc[12])
        r['impulse_bin'] = 1 if impulse == '是' else (0 if impulse == '否' else None)

        extra = str(row.iloc[13])
        r['extra_spend'] = mid_value(extra, {'＜50|50元':25,'51-100':75,'101-200':150,'>200|201':300})

        impact = str(row.iloc[14])
        r['impact_num'] = {'基本无影响':2,'小幅提升消费意愿':3,'显著增加消费支出':4,'导致冲动消费':5}.get(impact)

        dyn = str(row.iloc[21])
        r['dynamic_num'] = {'支持':5,'无所谓':3,'不支持':1}.get(dyn)

        env = str(row.iloc[22])
        r['env_willing'] = 1 if '愿意' in env else 0

        # Likert cols 23-26 (0-indexed)
        for i, vname in enumerate(['ai_accept','meta_accept','green_accept','second_accept'], 23):
            val = safe_int(row.iloc[i])
            if val is not None:
                r[vname] = val
                responses.append({'variable': vname, 'value': val, 'category': 'likert',
                    'label': {'ai_accept':'AI智能推荐券','meta_accept':'元宇宙虚拟商品券','green_accept':'低碳环保商品券','second_accept':'二手商品交易补贴券'}[vname]})

        dur = str(row.iloc[2])
        dur_match = re.search(r'(\d+)', dur)
        r['duration_min'] = int(dur_match.group(1))/60 if dur_match else None
        r['is_speeder'] = 1 if r['duration_min'] and r['duration_min'] < 0.5 else 0

        rows.append(r)

    return rows, responses

# ============== SQLite 写入 ==============

def write_to_sqlite(db_path, rows, responses, survey_id):
    conn = sqlite3.connect(db_path)
    # 创建表
    with open(SCHEMA) as f:
        conn.executescript(f.read())

    # 插入受访者
    df_r = pd.DataFrame(rows)
    df_r.to_sql('respondents', conn, if_exists='append', index=False)

    # 插入长格式响应（关联 respondent_id）
    last_id = conn.execute("SELECT MAX(id) FROM respondents").fetchone()[0]
    first_id = last_id - len(rows) + 1

    resp_with_id = []
    for i, resp in enumerate(responses):
        resp['respondent_id'] = first_id + i
        resp_with_id.append(resp)
    df_resp = pd.DataFrame(resp_with_id)
    df_resp.to_sql('responses', conn, if_exists='append', index=False)

    # 插入变量元数据
    var_meta = [
        # 人口学
        ('gender','性别','nominal','demographic','{"男":1,"女":0}',survey_id,'nominal'),
        ('gender_bin','性别(数值)','nominal','demographic','{"1":"男","0":"女"}',survey_id,'nominal'),
        ('age_group','年龄段','ordinal','demographic',None,survey_id,'ordinal'),
        ('age_num','年龄(有序)','ordinal','demographic','{"1":"最年轻","4":"最年长"}',survey_id,'ordinal'),
        ('status','身份','nominal','demographic',None,survey_id,'nominal'),
        # 经济
        ('income_num','月收入/生活费(元)','scale','demographic',None,survey_id,'scale'),
        # 行为
        ('used_voucher','是否使用消费券','nominal','behavior',None,survey_id,'nominal'),
        ('used_bin','使用券(0/1)','nominal','behavior','{"1":"已使用","0":"未使用"}',survey_id,'nominal'),
        ('freq_num','使用频率','ordinal','behavior','{"1":"1-3次","2":"4-6次","3":"7-10次","4":"10次以上"}',survey_id,'ordinal'),
        ('impulse_bin','冲动购买(0/1)','nominal','behavior','{"1":"是","0":"否"}',survey_id,'nominal'),
        ('extra_spend','月均额外消费(元)','scale','behavior',None,survey_id,'scale'),
        ('saving_amt','每次节省(元)','scale','behavior',None,survey_id,'scale'),
        # 态度
        ('impact_num','影响程度','ordinal','attitude','{"1":"保守型","5":"导致浪费"}',survey_id,'ordinal'),
        ('attention_num','规则关注度','ordinal','attitude','{"1":"完全不关注","5":"非常关注"}',survey_id,'ordinal'),
        ('dynamic_num','动态面额支持','ordinal','attitude','{"1":"非常不支持","5":"非常支持"}',survey_id,'ordinal'),
        ('sustainable_num','可持续认知','ordinal','attitude','{"1":"对立","4":"促进"}',survey_id,'ordinal'),
        ('env_willing','环保券意愿','nominal','attitude','{"1":"愿意","0":"不愿意"}',survey_id,'nominal'),
        # Likert (长格式)
        ('ai_accept','AI智能推荐券接受度','scale','attitude','{"1":"完全不接受","5":"完全接受"}',survey_id,'scale'),
        ('meta_accept','元宇宙虚拟商品券接受度','scale','attitude','{"1":"完全不接受","5":"完全接受"}',survey_id,'scale'),
        ('green_accept','低碳环保商品券接受度','scale','attitude','{"1":"完全不接受","5":"完全接受"}',survey_id,'scale'),
        ('second_accept','二手商品交易补贴券接受度','scale','attitude','{"1":"完全不接受","5":"完全接受"}',survey_id,'scale'),
        # 质量
        ('duration_min','答题用时(分钟)','scale','quality',None,survey_id,'scale'),
        ('is_speeder','秒答标记','nominal','quality','{"1":"<30秒","0":"正常"}',survey_id,'nominal'),
    ]
    conn.executemany(
        "INSERT OR REPLACE INTO variables (name,label_cn,type,category,value_labels,survey,spss_measure) VALUES (?,?,?,?,?,?,?)",
        var_meta
    )

    # 校验
    n = conn.execute("SELECT COUNT(*) FROM respondents WHERE survey=?", (survey_id,)).fetchone()[0]
    n_resp = conn.execute("SELECT COUNT(DISTINCT respondent_id) FROM responses r JOIN respondents rs ON r.respondent_id=rs.id WHERE rs.survey=?", (survey_id,)).fetchone()[0]
    n_var = conn.execute("SELECT COUNT(*) FROM variables WHERE survey=?", (survey_id,)).fetchone()[0]

    conn.commit(); conn.close()
    print(f"  respondents: {n}, responses: {n_resp}, variables: {n_var}")
    return n

# ============== 入口 ==============

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"

    for survey_id, cleaner in [("survey1", clean_survey1), ("survey2", clean_survey2)]:
        if target not in (survey_id, "all"): continue
        print(f"\n=== {survey_id} ===")
        rows, responses = cleaner()
        db_path = DB_DIR / f"{survey_id}.db"
        if db_path.exists(): db_path.unlink()
        n = write_to_sqlite(str(db_path), rows, responses, survey_id)
        print(f"Done: {db_path} ({n} respondents)")

    print("\n✓ 全部清洗入库完成")
