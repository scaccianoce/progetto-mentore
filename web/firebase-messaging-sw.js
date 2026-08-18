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
});
