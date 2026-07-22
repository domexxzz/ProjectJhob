import express from 'express';
import cors from 'cors';
import { env } from './config/env';
import { healthRouter } from './modules/health/health.routes';
import { authRouter } from './modules/auth/auth.routes';
import { transactionsRouter } from './modules/transactions/transactions.routes';
import { categoriesRouter } from './modules/categories/categories.routes';
import { budgetsRouter } from './modules/budgets/budgets.routes';
import { goalsRouter } from './modules/goals/goals.routes';
import { notificationsRouter } from './modules/notifications/notifications.routes';
import { recommendationsRouter } from './modules/recommendations/recommendations.routes';
import { subscriptionsRouter } from './modules/subscriptions/subscriptions.routes';
import { integrationsRouter } from './modules/integrations/integrations.routes';
import { chatRouter } from './modules/chat/chat.routes';
import { predictionsRouter } from './modules/predictions/predictions.routes';
import { exportRouter } from './modules/export/export.routes';
import { notFound, errorHandler } from './middleware/error';

export function createApp() {
  const app = express();

  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json({ limit: '15mb' })); // รองรับรูป base64 (OCR สลิป/เอกสาร)

  app.use('/health', healthRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/transactions', transactionsRouter);
  app.use('/api/v1/categories', categoriesRouter);
  app.use('/api/v1/budgets', budgetsRouter);
  app.use('/api/v1/goals', goalsRouter);
  app.use('/api/v1/notifications', notificationsRouter);
  app.use('/api/v1/recommendations', recommendationsRouter);
  app.use('/api/v1/subscriptions', subscriptionsRouter);
  app.use('/api/v1/integrations', integrationsRouter);
  app.use('/api/v1/chat', chatRouter);
  app.use('/api/v1/predictions', predictionsRouter);
  app.use('/api/v1/export', exportRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
