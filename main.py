"""
Survey Analysis Platform — 模块化 SPSS 风格问卷统计分析平台
Core CLI & Pipeline Orchestrator
"""
import sys
import subprocess

def run_pipeline():
    print("🚀 Running Survey Statistical Pipeline (00~04)...")

def main():
    print("✨ Survey Analysis Platform Initialized.")
    print("Available entrypoints:")
    print("  - Streamlit Workbench: streamlit run app/streamlit_app.py")
    print("  - FastAPI Server: uvicorn app.api.server:app --port 8000")
    print("  - Statistical Pipeline: python main.py --run-pipeline")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--run-pipeline":
        run_pipeline()
    else:
        main()
