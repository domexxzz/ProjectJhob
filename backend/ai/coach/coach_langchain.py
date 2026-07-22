#!/usr/bin/env python3
import sys
import io
import os
import json
from pathlib import Path

# Support UTF-8 on Windows
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

HERE = Path(__file__).parent

def load_persona() -> str:
    return (HERE / "persona.md").read_text(encoding="utf-8")

def thb(satang: int) -> str:
    return f"{satang / 100:,.0f} บาท"

def build_context_block(ctx: dict) -> str:
    lines = [
        f"- รายได้ต่อเดือน: {thb(ctx['monthly_income'])}",
        f"- ใช้ไปเดือนนี้: {thb(ctx['this_month_spent'])} "
        f"(เหลือ {thb(ctx['monthly_income'] - ctx['this_month_spent'])})",
    ]
    if ctx.get("budget_remaining"):
        br = ", ".join(
            f"{k} {'+' if v >= 0 else ''}{thb(v)}" for k, v in ctx["budget_remaining"].items()
        )
        lines.append(f"- งบคงเหลือรายหมวด: {br}")
    if ctx.get("top_expenses"):
        te = ", ".join(f"{e['category']} {thb(e['amount'])}" for e in ctx["top_expenses"])
        lines.append(f"- หมวดที่ใช้เยอะ: {te}")
    if ctx.get("goals"):
        gs = ", ".join(f"{g['name']} {g['progress_pct']}%" for g in ctx["goals"])
        lines.append(f"- เป้าหมาย: {gs}")
    if ctx.get("streak_days") is not None:
        lines.append(f"- streak: {ctx['streak_days']} วัน")
    return "\n".join(lines)

def run_langchain(ctx: dict, question: str, dry_run: bool = False):
    try:
        from langchain_core.prompts import ChatPromptTemplate
        from langchain_openai import ChatOpenAI
    except ImportError:
        print("[Warning] LangChain packages not fully installed. Running mock LangChain spike using direct emulation.")
        system_prompt = load_persona() + "\n\n## ข้อมูลผู้ใช้ (real-time context)\n" + build_context_block(ctx)
        print("=" * 60)
        print("SYSTEM PROMPT (LangChain Emulator)")
        print("=" * 60)
        print(system_prompt)
        print("\n" + "=" * 60)
        print("USER:", question)
        print("=" * 60)
        print("\n[Mock LangChain] Hello world spike completed. (Install langchain & langchain-openai to run real model call).")
        return

    system_prompt = load_persona() + "\n\n## ข้อมูลผู้ใช้ (real-time context)\n" + build_context_block(ctx)
    prompt = ChatPromptTemplate.from_messages([
        ("system", system_prompt),
        ("human", "{question}")
    ])
    
    if dry_run or not os.environ.get("OPENAI_API_KEY"):
        print("=" * 60)
        print("SYSTEM PROMPT (LangChain ChatPromptTemplate)")
        print("=" * 60)
        print(system_prompt)
        print("\n" + "=" * 60)
        print("USER:", question)
        print("=" * 60)
        if not os.environ.get("OPENAI_API_KEY"):
            print("\n[dry-run] ไม่พบ OPENAI_API_KEY — พิมพ์เพื่อตรวจโครงสร้าง LangChain Prompt เรียบร้อย")
        return
        
    model = ChatOpenAI(model="gpt-3.5-turbo", temperature=0.6)
    chain = prompt | model
    response = chain.invoke({"question": question})
    print("\n--- พี่เงิน (LangChain Response) ---")
    print(response.content)

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--context", default=str(HERE / "sample_context.json"))
    ap.add_argument("--question", default="เดือนนี้ใช้เงินเป็นยังไงบ้าง?")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    try:
        from dotenv import load_dotenv
        load_dotenv(HERE.parent / ".env")
    except ImportError:
        pass

    ctx = json.loads(Path(args.context).read_text(encoding="utf-8"))
    run_langchain(ctx, args.question, args.dry_run)

if __name__ == "__main__":
    main()
