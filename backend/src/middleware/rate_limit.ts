/**
 * จำกัดจำนวนครั้งที่ยิงเข้ามาได้ (rate limiting)
 *
 * ทำไมระบบการเงินต้องมี:
 *  1. ไม่มีเพดาน = เดารหัสผ่านรัว ๆ ได้ไม่จำกัด (brute force)
 *  2. /chat เรียก LLM ซึ่งคิดเงินตามการใช้งาน — ใครยิงรัวก็เผาโควต้าเราจนหมด
 *  3. รับ JSON ได้ถึง 15MB (รูปสลิป) ยิงรัว ๆ ทำให้เซิร์ฟเวอร์ล่มได้ง่าย
 *
 * นับแยกตาม IP · เกินเพดานตอบ HTTP 429
 */
import rateLimit from 'express-rate-limit';

const MINUTE = 60 * 1000;

/** ข้อความตอบเวลาโดนจำกัด — ให้ผู้ใช้ทั่วไปอ่านรู้เรื่อง ไม่ใช่ศัพท์เทคนิค */
function message(text: string) {
  return { error: text };
}

/**
 * ล็อกอิน/สมัคร — เข้มที่สุด เพราะเป็นประตูเข้าระบบ
 * 10 ครั้ง/5 นาที พอสำหรับคนพิมพ์รหัสผิดบ้าง แต่ตัดการเดารหัสอัตโนมัติทิ้ง
 */
export const authLimiter = rateLimit({
  windowMs: 5 * MINUTE,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: message('พยายามเข้าสู่ระบบบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่'),
});

/**
 * แชท AI — คุมต้นทุน LLM
 * 30 ข้อความ/นาที เกินกว่าที่คนพิมพ์ไหวมาก ๆ แต่กันสคริปต์ยิงรัวได้
 */
export const aiLimiter = rateLimit({
  windowMs: MINUTE,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: message('คุยเร็วเกินไป พักสักครู่นะ เดี๋ยวพี่เงินตอบต่อ'),
});

/**
 * เพดานรวมทุก endpoint — กันยิงถล่มทั่วไป
 * 300 ครั้ง/นาที เผื่อไว้เยอะเพราะหน้าแดชบอร์ดเรียกหลาย API พร้อมกัน
 */
export const apiLimiter = rateLimit({
  windowMs: MINUTE,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: message('ใช้งานถี่เกินไป กรุณารอสักครู่'),
});
