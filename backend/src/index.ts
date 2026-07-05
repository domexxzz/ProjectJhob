import { createApp } from './app';
import { env } from './config/env';
import { startNotificationScheduler } from './modules/notifications/triggers';

const app = createApp();

// ผูก IPv4 0.0.0.0 ตรง ๆ (แทน default '::') ให้เครื่องอื่นใน LAN เช่นมือถือ เข้าผ่าน IPv4 ได้
app.listen(env.port, '0.0.0.0', () => {
  console.log(`🟢 AI Finance Coach API → http://localhost:${env.port} (bound 0.0.0.0)`);
  console.log(`   Health: http://localhost:${env.port}/health`);
  startNotificationScheduler(); // เปิดด้วย env NOTIF_CRON=on
});
