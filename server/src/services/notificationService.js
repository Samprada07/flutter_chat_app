const admin = require('firebase-admin');

// ─── Initialize Firebase Admin ────────────────────────────────────────────
// Uses service account key to authenticate with Firebase
// This allows the server to send push notifications to any device
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// ─── Send Push Notification ───────────────────────────────────────────────
// Sends a push notification to a specific device using its FCM token
// Called when a new message is sent and receiver is offline
const sendPushNotification = async ({
  fcmToken,
  title,
  body,
  data = {},
}) => {
  try {
    if (!fcmToken) {
      console.log('No FCM token, skipping notification');
      return;
    }

    const message = {
      notification: { title, body },
      // Extra data sent with notification
      // Used to navigate to correct screen when notification is tapped
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    console.log('Push notification sent:', response);

  } catch (err) {
    console.error('Error sending push notification:', err);
  }
};

module.exports = { sendPushNotification };