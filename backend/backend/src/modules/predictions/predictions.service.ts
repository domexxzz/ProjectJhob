import { prisma } from '../../lib/prisma';

const FASTAPI_URL = process.env.PREDICTION_API_URL ?? 'http://127.0.0.1:8000/predict';

export interface PredictionResult {
  forecast: { date: string; balance: number; lower: number; upper: number }[]; // satang
  predictedTotalExpense: number;
  predictedTotalIncome: number;
  projectedEndingBalance: number;
  alerts: { type: string; title: string; body: string }[]; // info | warning | danger
  anomalies: { id: string; date: string; amount: number; note: string; description: string }[];
}

interface FastApiResult {
  forecast?: { date: string; balance: number; lower: number; upper: number }[];
  predicted_total_expense?: number;
  predicted_total_income?: number;
  projected_ending_balance?: number;
  alerts?: { type: string; title: string; body: string }[];
  anomalies?: { id: string; date: string; amount: number; note: string; description: string }[];
}

/**
 * เรียก FastAPI (Prophet) พยากรณ์ให้ user คนหนึ่ง — คืนค่าเป็น "สตางค์"
 * คืน null ถ้า service ไม่พร้อม/ล้มเหลว (ผู้เรียกไปตัดสินใจ fallback เอง)
 * ใช้ร่วมกันทั้ง REST controller และ background trigger
 */
export async function fetchPrediction(userId: string): Promise<PredictionResult | null> {
  const [user, transactions] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.transaction.findMany({ where: { userId }, orderBy: { occurredAt: 'asc' } }),
  ]);

  let currentBalanceSatang = 0;
  for (const t of transactions) currentBalanceSatang += t.type === 'income' ? t.amount : -t.amount;

  const payload = {
    transactions: transactions.map((t) => ({
      id: t.id,
      date: t.occurredAt.toISOString().split('T')[0],
      amount: t.amount / 100.0, // บาท (float) สำหรับ Python
      type: t.type,
      note: t.note || '',
    })),
    current_balance: currentBalanceSatang / 100.0,
    monthly_income: (user?.monthlyIncome || 0) / 100.0,
    forecast_days: 30,
  };

  let res: Response;
  try {
    res = await fetch(FASTAPI_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    console.error('[predictions] FastAPI ไม่ตอบ (service ปิดอยู่?):', (e as Error).message);
    return null;
  }
  if (!res.ok) {
    console.error('[predictions] FastAPI error', res.status, (await res.text().catch(() => '')).slice(0, 200));
    return null;
  }

  const r = (await res.json()) as FastApiResult;
  return {
    forecast: (r.forecast ?? []).map((f) => ({
      date: f.date,
      balance: Math.round(f.balance * 100),
      lower: Math.round(f.lower * 100),
      upper: Math.round(f.upper * 100),
    })),
    predictedTotalExpense: Math.round((r.predicted_total_expense ?? 0) * 100),
    predictedTotalIncome: Math.round((r.predicted_total_income ?? 0) * 100),
    projectedEndingBalance: Math.round((r.projected_ending_balance ?? 0) * 100),
    alerts: r.alerts ?? [],
    anomalies: (r.anomalies ?? []).map((a) => ({
      id: a.id,
      date: a.date,
      amount: Math.round(a.amount * 100),
      note: a.note,
      description: a.description,
    })),
  };
}
