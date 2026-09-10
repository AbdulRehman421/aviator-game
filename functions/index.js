const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Import game server
const GameLoop = require('./game-server');

// Keep game loop running
let gameLoop = null;

async function ensureGameLoop() {
  if (!gameLoop) {
    gameLoop = new GameLoop();
    await gameLoop.start();
    console.log('✅ Game server started');
  }
  return gameLoop;
}

// HTTP endpoint to initialize/check server
exports.initGameServer = functions.https.onRequest(async (req, res) => {
  try {
    await ensureGameLoop();
    res.json({ 
      status: 'running',
      message: 'Game server is active',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error starting game server:', error);
    res.status(500).json({ 
      status: 'error',
      message: error.message 
    });
  }
});

// Keep-alive function (runs every minute)
exports.keepAlive = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Karachi')
  .onRun(async (context) => {
    try {
      await ensureGameLoop();
      console.log('💚 Game server keep-alive');
      return null;
    } catch (error) {
      console.error('❌ Keep-alive error:', error);
      throw error;
    }
  });

// Payment webhooks
const { handleJazzCashCallback, handleEasyPaisaCallback } = require('./payment-webhook');

exports.jazzcashCallback = functions.https.onRequest(handleJazzCashCallback);
exports.easypaisaCallback = functions.https.onRequest(handleEasyPaisaCallback);

// Health check endpoint
exports.health = functions.https.onRequest((req, res) => {
  res.json({ 
    status: 'healthy',
    gameServer: gameLoop ? 'running' : 'stopped',
    timestamp: new Date().toISOString()
  });
});
