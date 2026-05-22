# Makefile — 问卷数据分析管道编排
# 用法: make all | make clean | make analyze | make report

.PHONY: all clean analyze integrate report lint explore app help

# 默认目标
all: clean analyze integrate report

help:
	@echo "Survey Analysis Pipeline"
	@echo "  make app        — 启动 Streamlit 智能分析助手 (port 8501)"
	@echo "  make explore    — 启动 Jupyter 数据探索"
	@echo "  make clean      — Excel → SQLite 清洗入库"
	@echo "  make analyze    — 运行所有统计分析模块"
	@echo "  make integrate  — 编译分析结果"
	@echo "  make report     — 生成 Quarto HTML 报告"
	@echo "  make lint       — R 脚本语法检查 (LSP)"
	@echo "  make all        — 一键全流程"

# ====== Streamlit 应用 ======
app:
	@echo "启动 Streamlit 分析助手..."
	PYTHONPATH=$(shell pwd) streamlit run app/main.py --server.port 8501

# ====== 数据探索 ======
explore:
	@echo "启动 Jupyter..."
	cd 00-explore && jupyter notebook explore.ipynb

# ====== 清洗（Python: Excel → SQLite） ======
clean:
	@echo "清洗数据 → SQLite..."
	python3 01-clean/clean_to_sqlite.py all

clean_s1:
	python3 01-clean/clean_to_sqlite.py survey1

clean_s2:
	python3 01-clean/clean_to_sqlite.py survey2

# ====== 分析模块（每个独立运行） ======
ANALYZE_MODULES = descriptives crosstabs ttest anova correlation reliability factor_analysis regression mediation moderation cluster power_bootstrap

analyze: $(ANALYZE_MODULES)

$(ANALYZE_MODULES):
	@echo "=== $@ ==="
	Rscript 02-analyze/$@.R

# ====== 整合 ======
integrate:
	@echo "编译结果..."
	Rscript 03-integrate/compile.R

# ====== 报告 ======
report:
	@echo "渲染 Quarto 报告..."
	cd 04-report && quarto render report.qmd --to html
	@echo "报告: output/reports/survey_analysis_report.html"

# ====== LSP 语法检查 ======
lint:
	@echo "LSP 语法检查..."
	@for f in 02-analyze/*.R lib/*.R; do \
		echo "Checking $$f..."; \
		Rscript -e "tryCatch({parse(file='$$f'); cat('  OK\n')}, error=function(e) cat('  ERROR:', e\$message, '\n'))"; \
	done

# ====== 查看数据库 ======
db_info:
	@echo "=== survey1.db ==="
	@sqlite3 data/db/survey1.db "SELECT COUNT(*) AS respondents FROM respondents; SELECT COUNT(*) AS responses FROM responses;"
	@echo "=== survey2.db ==="
	@sqlite3 data/db/survey2.db "SELECT COUNT(*) AS respondents FROM respondents; SELECT COUNT(*) AS responses FROM responses;"

# ====== 清理 ======
clean_output:
	rm -f output/results/*.rds
	rm -f output/reports/*.html
