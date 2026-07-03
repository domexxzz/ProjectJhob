import { createApp } from './app';
import { env } from './config/env';
import { startNotificationScheduler } from './modules/notifications/triggers';

const app = createApp();

app.listen(env.port, () => {
  console.log(`🟢 AI Finance Coach API → http://localhost:${env.port}`);
  console.log(`   Health: http://localhost:${env.port}/health`);
  startNotificationScheduler(); // เปิดด้วย env NOTIF_CRON=on
});
