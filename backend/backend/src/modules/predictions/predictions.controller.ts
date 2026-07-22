import { Request, Response } from 'express';
import { fetchPrediction } from './predictions.service';

// GET /api/v1/predictions — ดึงผลพยากรณ์ตรง ๆ (ยังคงไว้เผื่อ debug/หน้ารายละเอียด)
// หมายเหตุ: การใช้งานหลักย้ายไป background (prediction_triggers) → ส่งเข้า Notification แทน
export async function getPredictions(req: Request, res: Response): Promise<void> {
  const userId = req.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const result = await fetchPrediction(userId);
  if (!result) {
    res.status(502).json({ error: 'AI Prediction service ไม่พร้อมใช้งาน (ตรวจว่ารัน FastAPI :8000 อยู่)' });
    return;
  }
  res.status(200).json(result);
}
