import 'dotenv/config';

function get(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env var: ${name}`);
  return v;
}

export const env = {
  databaseUrl: get('DATABASE_URL', 'file:./dev.db'),
  jwtSecret: get('JWT_SECRET', 'dev-insecure-secret-change-me'),
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
