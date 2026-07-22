#!/usr/bin/env python3
"""พี่เงิน — AI Finance Coach spike (Sprint 1, P3).

ประกอบ system prompt จาก persona + context injection (ข้อมูลจริงของผู้ใช้) แล้วถาม LLM.
  --dry-run : พิมพ์ prompt ที่ประกอบได้ (ไม่ต้องมี API key / ไม่ต้องลง openai)
"""
import argparse
import json
import os
import sys
from pathlib import Path

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


def build_messages(ctx: dict, question: str) -> list:
    system = load_persona() + "\n\n## ข้อมูลผู้ใช้ (real-time context)\n" + build_context_block(ctx)
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": question},
    ]


def call_openai(messages: list, model: str) -> str:
    try:
        from openai import OpenAI
    except ImportError:
        sys.exit("ยังไม่ได้ลง openai → pip install -r ../requirements.txt")
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        sys.exit("ตั้ง OPENAI_API_KEY ก่อน (ดู ai/.env.example) หรือใช้ --dry-run")
    client = OpenAI(api_key=api_key)
    resp = client.chat.completions.create(
        model=model, messages=messages, temperature=0.6, max_tokens=350
    )
    return resp.choices[0].message.content


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--context", default=str(HERE / "sample_context.json"))
    ap.add_argument("--question", default="เดือนนี้ใช้เงินเป็นยังไงบ้าง?")
    ap.add_argument("--model", default="gpt-3.5-turbo", help="prod fallback = gpt-4")
    ap.add_argument("--dry-run", action="store_true", help="พิมพ์ prompt ไม่เรียก API")
    args = ap.parse_args()

    try:
        from dotenv import load_dotenv  # ออปชัน

        load_dotenv(HERE.parent / ".env")
    except ImportError:
        pass

    ctx = json.loads(Path(args.context).read_text(encoding="utf-8"))
    messages = build_messages(ctx, args.question)

    if args.dry_run:
        print("=" * 60)
        print("SYSTEM PROMPT")
        print("=" * 60)
        print(messages[0]["content"])
        print("\n" + "=" * 60)
        print("USER:", messages[1]["content"])
        print("=" * 60)
        print("\n[dry-run] ไม่เรียก API — ใส่ OPENAI_API_KEY แล้วรันใหม่ (ไม่ใส่ --dry-run) เพื่อทดสอบจริง")
        return

    print(call_openai(messages, args.model))


if __name__ == "__main__":
    main()
