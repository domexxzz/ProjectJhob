// Service worker สำหรับรับแจ้งเตือน Web Push ตอนที่แอปปิด/อยู่เบื้องหลัง
// จำเป็นสำหรับ PWA บน iPhone (iOS 16.4+ และต้อง "เพิ่มลงหน้าจอโฮม" ก่อน)
// ใช้ compat SDK เพราะ service worker ใช้ importScripts (ไม่รองรับ ES module ในทุกเบราว์เซอร์)
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDXm7OkxFLW6YSaLaFy-_1Zib2yIZjhwfc',
  authDomain: 'phee-ngern.firebaseapp.com',
  projectId: 'phee-ngern',
  storageBucket: 'phee-ngern.firebasestorage.app',
  messagingSenderId: '52873487111',
  appId: '1:52873487111:web:a9ef21ee2d93ce3ce65ba2',
});

const messaging = firebase.messaging();

// ข้อความที่เข้ามาตอนแอปไม่ได้เปิดอยู่ → เด้งขึ้น notification center
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'พี่เงิน';
  const body = payload.notification?.body || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'phee-ngern',
    data: payload.data || {},
  });
});

// แตะที่การแจ้งเตือน → เปิดแอป (ถ้าเปิดอยู่แล้วให้โฟกัสแท็บเดิม)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if ('focus' in c) return c.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    }),
  );
});
