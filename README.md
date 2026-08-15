<div align="center">

# 📋 Survey Analysis Platform

**模块化 SPSS 风格问卷统计分析平台 — R + Python + Streamlit + Quarto + LLM Agent**  
*A modular SPSS-style statistical analysis platform for survey data science*

<p>
<img alt="Python" src="https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white">
<img alt="R" src="https://img.shields.io/badge/R-4.x-276DC3?style=for-the-badge&logo=r&logoColor=white">
<img alt="Streamlit" src="https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white">
<img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white">
<img alt="Quarto" src="https://img.shields.io/badge/Quarto-Publishing-4A90E2?style=for-the-badge">
</p>

<p>
<img alt="status" src="https://img.shields.io/badge/status-active-success?style=flat-square">
<img alt="license" src="https://img.shields.io/badge/license-MIT-green?style=flat-square">
</p>

</div>

---

## 📖 简介 · About

**Survey Analysis Platform** 是一套面向问卷调查、社会科学实证与商业洞察的工业级统计分析系统。系统结合 **R 语言在经典计量与 SPSS 统计检验上的严谨性**（信效度分析、方差分析 ANOVA、多元回归、中介与调节效应）与 **Python 全栈 / LLM Agent 的交互与工程自动化能力**，实现“探索 → 清洗 → 统计检验 → 整合 → Quarto 自动化报告”全流水线。

---

## 🏛️ 核心目录架构 · Repository Layout

```text
survey-analysis-platform/
├── pipeline/             # 🔄 六阶段统计流水线 (00探索 -> 01清洗 -> 02分析 -> 03整合 -> 04报告)
├── app/                  # 🖥️ Streamlit 统计分析工作台与 FastAPI 后端服务
├── web/                  # 🎨 Next.js / React 交互式前端界面
├── agent/                # 🤖 LLM 统计 Copilot 智能体与工具注册
├── lib/                  # 📐 R & Python 核心统计学算法与 SPSS 格式化输出库
├── docs/                 # 📚 统计检验手册、系统架构与 API 说明
├── main.py               # ⚡ 顶级主入口 (命令行调度与服务拉起)
├── requirements.txt      # 📦 统一依赖清单
└── README.md             # 🌟 唯一项目门面
```

---

## 🚀 快速开始 · Quickstart

### 1. 安装依赖
```bash
pip install -r requirements.txt
```

### 2. 启动服务或工作台
```bash
# 启动平台控制台
python main.py

# 启动 Streamlit 可视化交互大屏
streamlit run app/streamlit_app.py

# 启动 FastAPI 统计计算服务
uvicorn app.api.server:app --port 8000
```

---

## 🧪 核心统计功能矩阵 · Statistical Features

- **经典描述与交叉检验**：卡方检验、独立样本 T 检验、单因素与双因素 ANOVA；
- **测量模型评估**：Cronbach's $\alpha$ 信度、探索性因子分析 (EFA)、验证性因子分析 (CFA)；
- **结构方程与高级回归**：多元线性回归、Logistic 回归、Bootstrap 中介与调节效应模型；
- **Quarto 报告自动化**：一键编译输出 publication-grade HTML / PDF 统计学学术与咨询分析报告。
