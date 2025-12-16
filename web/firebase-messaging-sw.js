/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');


const firebaseConfig = {
  apiKey: "AIzaSyDWR4aghTmUGwTzMEAVTyYqe4dx8Fom51A",
  authDomain: "splitnest-2aadd.firebaseapp.com",
  projectId: "splitnest-2aadd",
  storageBucket: "splitnest-2aadd.firebasestorage.app",
  messagingSenderId: "466626241242",
  appId: "1:466626241242:web:1e763011a640137deefbe3",
  measurementId: "G-YCWHFZWM63"
};

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = (payload.notification && payload.notification.title) || 'SplitNest';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
  };
  self.registration.showNotification(title, options);
});
