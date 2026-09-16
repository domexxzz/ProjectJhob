/**
 * ตัวจับเวลาแบบเบาสำหรับหาคอขวดใน request ที่มีหลายจังหวะ
 *
 *   const t = new Timer();
 *   await loadHistory();  t.mark('history');
 *   await buildContext(); t.mark('context');
 *   console.log(t.line('chat'));   // [chat:timing] total=6512ms history=102 context=210
 *
 * ออกแบบให้ไม่มี dependency และไม่โยน error เด็ดขาด — เครื่องมือวัดต้องไม่ทำให้ของจริงพัง
 */
/** "total" สงวนไว้ให้ยอดรวมใน toJSON() — กันถูกทับเงียบ ๆ */
const safeLabel = (label: string): string => (label === 'total' ? 'total_' : label);

export class Timer {
  private readonly startedAt = Date.now();
  private lastAt = Date.now();
  private readonly steps: { label: string; ms: number }[] = [];

  /** ปิดจังหวะปัจจุบัน = เวลาที่ผ่านไปตั้งแต่ mark ครั้งก่อน (หรือตั้งแต่เริ่ม) */
  mark(label: string): void {
    const now = Date.now();
    this.steps.push({ label: safeLabel(label), ms: now - this.lastAt });
    this.lastAt = now;
  }

  /** เพิ่มเวลาที่วัดมาเองจากที่อื่น เช่น งานซ้อนชั้นหรืองานที่รันคู่ขนาน */
  add(label: string, ms: number): void {
    this.steps.push({ label: safeLabel(label), ms });
  }

  get totalMs(): number {
    return Date.now() - this.startedAt;
  }

  /** รูปแบบสำหรับส่งกลับใน response — label ซ้ำจะถูกรวมยอด */
  toJSON(): Record<string, number> {
    const out: Record<string, number> = {};
    for (const s of this.steps) out[s.label] = (out[s.label] ?? 0) + s.ms;
    out.total = this.totalMs;
    return out;
  }

  /** บรรทัดเดียวสำหรับ log ฝั่งเซิร์ฟเวอร์ */
  line(tag: string): string {
    const parts = this.steps.map((s) => `${s.label}=${s.ms}`).join(' ');
    return `[${tag}:timing] total=${this.totalMs}ms ${parts}`;
  }
}

/**
 * ส่ง breakdown กลับไปกับ response หรือไม่ — ต้องเปิดเองด้วย CHAT_TIMING=on
 * ปิดไว้เป็นค่าเริ่มต้นเพราะไม่ควรเปิดเผยชื่อ provider/tool และเวลาภายในให้ client
 * (log ฝั่งเซิร์ฟเวอร์ทำงานเสมอ ใช้หาคอขวดได้โดยไม่ต้องเปิดอันนี้)
 */
export const exposeTiming = (): boolean => process.env.CHAT_TIMING === 'on';
