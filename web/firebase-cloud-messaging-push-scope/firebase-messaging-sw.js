const appBaseUrl = new URL('../', self.registration.scope);

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const link = event.notification.data?.link || new URL(
    '#/notifiche',
    appBaseUrl
  ).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(async (finestre) => {
        for (const finestra of finestre) {
          if ('navigate' in finestra) await finestra.navigate(link);
          if ('focus' in finestra) return finestra.focus();
        }
        return clients.openWindow(link);
      })
  );
});

importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: 'AIzaSyAcav1EUY47kUXyINnr82Ux0Smu5Z4v42g',
  authDomain: 'progmentore-9b804.firebaseapp.com',
  projectId: 'progmentore-9b804',
  storageBucket: 'progmentore-9b804.firebasestorage.app',
  messagingSenderId: '168070790692',
  appId: '1:168070790692:web:b24306731b3e54efb4e2b1',
  measurementId: 'G-VCY5Y962KC',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log('[firebase-messaging-sw.js] Messaggio background:', message);

  // I messaggi con payload `notification` vengono mostrati automaticamente
  // da Firebase. Questo fallback gestisce anche eventuali messaggi data-only.
  if (message.notification) return;

  const data = message.data || {};
  const iconUrl = new URL('icons/Icon-192.png', appBaseUrl).href;
  const linkUrl = new URL(
    data.link || '#/notifiche',
    appBaseUrl
  ).href;

  return self.registration.showNotification(
    data.titolo || 'Progetto Mentore',
    {
      body: data.messaggio || 'Hai ricevuto una nuova notifica.',
      icon: iconUrl,
      badge: iconUrl,
      data: { link: linkUrl },
      tag: data.messaggio_id || undefined,
    }
  );
});
