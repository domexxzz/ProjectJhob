import 'dotenv/config';

function get(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env var: ${name}`);
  return v;
}


/**
 * ค่าลับที่ห้ามใช้ค่า default ตอนขึ้น production
 *
 * repo เราเป็น public ใครก็อ่านค่า default ในโค้ดได้ ถ้าลืมตั้ง env var
 * บนเซิร์ฟเวอร์ ระบบจะไม่แจ้งอะไรเลยแต่ใครก็ปลอม token เป็นใครก็ได้
 * จึงให้ "ไม่ยอมสตาร์ท" ไปเลยดีกว่าเปิดใช้งานทั้งที่ไม่ปลอดภัย
 */
function requireSecretInProduction(key: string, devFallback: string): string {
  const value = process.env[key];
  if (value && value.trim()) return value;
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      `[config] ไม่ได้ตั้ง ${key} — ระบบไม่ยอมสตาร์ทบน production เพราะค่า default ` +
        `อยู่ในซอร์สโค้ดสาธารณะ ใครก็ปลอม token ได้ · ตั้งค่าใน Render → Environment`,
    );
  }
  return devFallback;
}

export const env = {
  databaseUrl: get('DATABASE_URL', 'file:./dev.db'),
  jwtSecret: requireSecretInProduction('JWT_SECRET', 'dev-insecure-secret-change-me'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  port: Number(process.env.PORT ?? 4000),
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  // AI Coach providers (ใส่ตัวไหน ตัวนั้นถูกใช้; ลำดับ Typhoon → Groq → OpenAI → fallback)
  typhoonApiKey: process.env.TYPHOON_API_KEY,
  typhoonModel: process.env.TYPHOON_MODEL ?? 'typhoon-v2.5-30b-a3b-instruct',
  typhoonOcrModel: process.env.TYPHOON_OCR_MODEL ?? 'typhoon-ocr-v1.5',
  groqApiKey: process.env.GROQ_API_KEY,
  groqModel: process.env.GROQ_MODEL ?? 'llama-3.3-70b-versatile',
  openaiApiKey: process.env.OPENAI_API_KEY,
  openaiModel: process.env.OPENAI_MODEL ?? 'gpt-3.5-turbo',
  openaiBaseUrl: process.env.OPENAI_BASE_URL, // custom OpenAI-compatible endpoint (optional)
  // Social login (OAuth) — ตั้งค่าจาก Google Cloud / Facebook Developer
  googleClientId: process.env.GOOGLE_CLIENT_ID, // ใช้ verify Google ID token (คั่นด้วย , ได้หลายตัว: web,android,ios)
  facebookAppId: process.env.FACEBOOK_APP_ID,
  facebookAppSecret: process.env.FACEBOOK_APP_SECRET,
  googleClientSecret: process.env.GOOGLE_CLIENT_SECRET, // สำหรับ server-side OAuth (Gmail import)
  gmailRedirectUri: process.env.GMAIL_REDIRECT_URI ?? 'http://localhost:4000/api/v1/integrations/gmail/callback',
  webAppUrl: process.env.WEB_APP_URL ?? 'http://localhost:5000',
};
