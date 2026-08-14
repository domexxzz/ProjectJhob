import express from "express";
import cors from "cors";
import path from "path";
import { env } from "./config/env";
import { healthRouter } from "./modules/health/health.routes";
import { authRouter } from "./modules/auth/auth.routes";
import { transactionsRouter } from "./modules/transactions/transactions.routes";
import { categoriesRouter } from "./modules/categories/categories.routes";
import { budgetsRouter } from "./modules/budgets/budgets.routes";
import { goalsRouter } from "./modules/goals/goals.routes";
import { notificationsRouter } from "./modules/notifications/notifications.routes";
import { recommendationsRouter } from "./modules/recommendations/recommendations.routes";
import { subscriptionsRouter } from "./modules/subscriptions/subscriptions.routes";
import { integrationsRouter } from "./modules/integrations/integrations.routes";
import { chatRouter } from "./modules/chat/chat.routes";
import { predictionsRouter } from "./modules/predictions/predictions.routes";
import { exportRouter } from "./modules/export/export.routes";
import { currencyRouter } from "./modules/currency/currency.routes";
import { notFound, errorHandler } from "./middleware/error";
import helmet from "helmet";
import { authLimiter, aiLimiter, apiLimiter } from "./middleware/rate_limit";

export function createApp() {
  const app = express();

  // Render อยู่หลัง reverse proxy — ถ้าไม่บอก Express ให้เชื่อ X-Forwarded-For
  // ระบบจะเห็นผู้ใช้ทุกคนเป็น IP เดียวกัน (IP ของ proxy) แล้ว rate limit จะไป
  // นับรวมกันทั้งระบบ = ผู้ใช้จริงโดนบล็อกทั้งหมด · 1 = เชื่อ proxy ชั้นเดียว
  app.set("trust proxy", 1);

  // ปิดการบอกว่าเซิร์ฟเวอร์รันด้วยอะไร — ลดข้อมูลที่ผู้โจมตีใช้เลือกช่องโหว่
  app.disable("x-powered-by");
  // security headers: กันเดาชนิดไฟล์ (nosniff), กันเว็บอื่นเอาไปฝัง, บังคับ HTTPS
  // contentSecurityPolicy ปิดไว้เพราะหน้าเว็บเป็น Flutter build ที่ใช้ inline script
  app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json({ limit: "15mb" })); // รองรับรูป base64 (OCR สลิป/เอกสาร)

  app.use("/health", healthRouter);
  app.use("/api/v1", apiLimiter); // เพดานรวมทุก endpoint
  app.use("/api/v1/auth", authLimiter, authRouter); // เข้มเป็นพิเศษ — กันเดารหัสผ่าน
  app.use("/api/v1/chat", aiLimiter); // กันยิงรัวจนเผาโควต้า LLM (เสียเงินจริง)
  app.use("/api/v1/transactions", transactionsRouter);
  app.use("/api/v1/categories", categoriesRouter);
  app.use("/api/v1/budgets", budgetsRouter);
  app.use("/api/v1/goals", goalsRouter);
  app.use("/api/v1/notifications", notificationsRouter);
  app.use("/api/v1/recommendations", recommendationsRouter);
  app.use("/api/v1/subscriptions", subscriptionsRouter);
  app.use("/api/v1/integrations", integrationsRouter);
  app.use("/api/v1/chat", chatRouter);
  app.use("/api/v1/predictions", predictionsRouter);
  app.use("/api/v1/export", exportRouter);
  app.use("/api/v1/currency", currencyRouter);

  // ── เสิร์ฟ Flutter web (PWA) ── ให้เปิดเป็นเว็บ/เพิ่มลงหน้าจอโฮมบน iPhone ได้
  // ไฟล์ web build ก็อปมาไว้ที่ backend/public (commit ไปกับ deploy) · static + SPA fallback
  const webDir = path.resolve(__dirname, "../public");
  app.use(express.static(webDir));
  app.use((req, res, next) => {
    if (
      req.method === "GET" &&
      !req.path.startsWith("/api") &&
      !req.path.startsWith("/health")
    ) {
      res.sendFile(path.join(webDir, "index.html"), (err) => {
        if (err) next();
      });
    } else {
      next();
    }
  });

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
