const admin = require('firebase-admin');

// Ensure the correct relative path
const serviceAccount = require('./cloud-first-task-firebase-adminsdk-zxr0j-80f4b28dc8.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log('Firebase initialized successfully');

// List<String> topics = ['Sports', 'Politics', 'Economics'];


const message = {
  notification: {
    title: 'Sports News',
    body: 'Sports News Body',
  },
  topic: 'Sports',
};

admin
  .messaging()
  .send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.error('Error sending message:', error);
  });

const message2 = {
  notification: {
    title: 'Politics News',
    body: 'Politics News Body',
  },
  topic: 'Politics',
};

admin
  .messaging()
  .send(message2)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.error('Error sending message:', error);
  });

const message3 = {
  notification: {
    title: 'Economics News',
    body: 'Economics News Body',
  },
  topic: 'Economics',
};
  
admin
  .messaging()
  .send(message3)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.error('Error sending message:', error);
  });
