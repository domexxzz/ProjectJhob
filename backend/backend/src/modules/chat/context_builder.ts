import { prisma } from '../../lib/prisma';

/** Context injection สำหรับโค้ช "พี่เงิน" (ตามสไลด์ 5) — จำนวนเงินเป็นสตางค์, ไม่มี PII */
export interface CoachContext {
  displayName: string | null;
  monthlyIncome: number;
  thisMonthSpent: number;
  thisMonthIncome: number;
  budgetRemaining: { category: string; remaining: number }[]; // remaining < 0 = เกินงบ
  topExpenses: { category: string; amount: number }[];
  goals: { name: string; progressPct: number }[];
  streakDays: number;
}

export async function buildContext(userId: string): Promise<CoachContext> {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  const [user, txns, budgets, goals] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.transaction.findMany({
      where: { userId, occurredAt: { gte: start, lt: end } },
      include: { category: true },
    }),
    prisma.budget.findMany({ where: { userId, period: 'monthly' }, include: { category: true } }),
    prisma.goal.findMany({ where: { userId } }),
  ]);

  let thisMonthSpent = 0;
  let thisMonthIncome = 0;
  const catSpend = new Map<string, number>();
  for (const t of txns) {
    if (t.type === 'income') {
      thisMonthIncome += t.amount;
    } else {
      thisMonthSpent += t.amount;
      const name = t.category?.nameTh ?? 'อื่นๆ';
      catSpend.set(name, (catSpend.get(name) ?? 0) + t.amount);
    }
  }

  const topExpenses = [...catSpend.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([category, amount]) => ({ category, amount }));

  const budgetRemaining = budgets.map((b) => {
    const name = b.category?.nameTh ?? 'รวม';
    const spent = catSpend.get(name) ?? 0;
    return { category: name, remaining: b.amount - spent };
  });

  const goalsOut = goals.map((g) => ({
    name: g.name,
    progressPct: g.target > 0 ? Math.round((g.current / g.target) * 100) : 0,
  }));

  return {
    displayName: user?.displayName ?? null,
    monthlyIncome: user?.monthlyIncome || thisMonthIncome,
    thisMonthSpent,
    thisMonthIncome,
    budgetRemaining,
    topExpenses,
    goals: goalsOut,
    streakDays: user?.streak ?? 0,
  };
}
