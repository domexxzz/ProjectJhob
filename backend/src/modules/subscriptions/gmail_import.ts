import { prisma } from '../../lib/prisma';
import { HttpError } from '../../lib/http';

// 📧 นำเข้า subscription จาก Gmail (best-effort) — ต้องใช้ Google access token ที่มี scope gmail.readonly
// หมายเหตุ: การอ่านยอดเงินจากเนื้อเมลแม่นยำยาก → ใช้ "ราคาเริ่มต้น" ของบริการยอดฮิต (ผู้ใช้แก้ทีหลังได้)

interface KnownService {
  match: RegExp; // จับจากช่อง From
  name: string;
  logo: string;
  defaultAmount: number; // สตางค์
}

const KNOWN: KnownService[] = [
  { match: /netflix\.com/i, name: 'Netflix', logo: '🎬', defaultAmount: 41900 },
  { match: /spotify\.com/i, name: 'Spotify', logo: '🎵', defaultAmount: 14900 },
  { match: /youtube\.com|youtubepremium/i, name: 'YouTube Premium', logo: '▶️', defaultAmount: 17900 },
  { match: /disney(plus)?\.com/i, name: 'Disney+ Hotstar', logo: '🏰', defaultAmount: 29900 },
  { match: /(icloud|apple)\.com/i, name: 'iCloud+', logo: '☁️', defaultAmount: 3500 },
  { match: /primevideo|amazon\.com/i, name: 'Prime Video', logo: '📦', defaultAmount: 14900 },
];

function nextMonthSameDay(): Date {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth() + 1, d.getDate());
}

/** ค้น Gmail หาอีเมลใบเสร็จของบริการยอดฮิต แล้วสร้าง subscription (ข้ามอันที่มีอยู่แล้ว) */
export async function importSubscriptionsFromGmail(userId: string, accessToken: string) {
  const query =
    'newer_than:1y (subject:(receipt OR subscription OR payment OR ใบเสร็จ OR "your receipt")) ' +
    '(from:netflix.com OR from:spotify.com OR from:youtube.com OR from:google.com OR from:disneyplus.com OR from:apple.com OR from:amazon.com)';

  const searchUrl =
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=25&q=${encodeURIComponent(query)}`;
  const sRes = await fetch(searchUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!sRes.ok) {
    const errBody = await sRes.text().catch(() => '');
    console.error(`[gmail-import] Gmail API ${sRes.status}:`, errBody.slice(0, 500));
    if (sRes.status === 401 || sRes.status === 403) {
      throw new HttpError(401, `อ่าน Gmail ไม่ได้ (${sRes.status}) — token ไม่มี scope gmail.readonly หรือหมดอายุ · ลองล็อกอิน Google ใหม่ด้วยบัญชี test user`);
    }
    throw new HttpError(502, `เรียก Gmail API ไม่สำเร็จ (${sRes.status})`);
  }

  const search = (await sRes.json()) as { messages?: { id: string }[] };
  const messages = search.messages ?? [];
  if (messages.length === 0) return { imported: 0, scanned: 0, subscriptions: [] };

  const seen = new Set<string>();
  const created = [];

  for (const m of messages) {
    const mRes = await fetch(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/${m.id}?format=metadata&metadataHeaders=From&metadataHeaders=Subject`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    if (!mRes.ok) continue;
    const msg = (await mRes.json()) as { payload?: { headers?: { name: string; value: string }[] } };
    const headers = msg.payload?.headers ?? [];
    const from = headers.find((h) => h.name.toLowerCase() === 'from')?.value ?? '';

    const svc = KNOWN.find((k) => k.match.test(from));
    if (!svc || seen.has(svc.name)) continue;
    seen.add(svc.name);

    // ข้ามถ้ามี subscription ชื่อนี้อยู่แล้ว
    const exists = await prisma.subscription.findFirst({ where: { userId, name: svc.name } });
    if (exists) continue;

    const sub = await prisma.subscription.create({
      data: {
        userId,
        name: svc.name,
        amount: svc.defaultAmount,
        cycle: 'monthly',
        nextBilling: nextMonthSameDay(),
        logo: svc.logo,
      },
    });
    created.push(sub);
  }

  return { imported: created.length, scanned: messages.length, subscriptions: created };
}
