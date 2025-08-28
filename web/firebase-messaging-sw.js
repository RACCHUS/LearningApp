// [START initialize_firebase_in_sw]
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCqOYbLs4qXXseOk3PAvlLvugkEsk69DAo",
  authDomain: "learningapp-2ed8a.firebaseapp.com",
  projectId: "learningapp-2ed8a",
  storageBucket: "learningapp-2ed8a.firebasestorage.app",
  messagingSenderId: "526319550622",
  appId: "1:526319550622:web:9adf7950b0439bee3f7b8f",
  measurementId: "G-Y3VGL6HHTY"
});

const messaging = firebase.messaging();
// [END initialize_firebase_in_sw]
