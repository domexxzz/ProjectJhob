import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';

export function notFound(_req: Request, res: Response): void {
  res.status(404).json({ error: 'Not found' });
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(400).json({ error: 'Validation failed', details: err.flatten() });
    return;
  }
  const e = err as { status?: number; message?: string };
  if (e && typeof e.status === 'number') {
    res.status(e.status).json({ error: e.message ?? 'Error' });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
