#!/bin/bash

# Firebase Functions Setup Script
# This script sets up your Aviator game server for Firebase Functions deployment

echo "🚀 Setting up Firebase Functions for Aviator Game Server..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
else
    echo "✅ Firebase CLI found"
fi

# Login to Firebase
echo "📝 Logging in to Firebase..."
firebase login

# Initialize Firebase (if not already done)
if [ ! -f "firebase.json" ]; then
    echo "🔧 Initializing Firebase..."
    firebase init functions hosting
else
    echo "✅ Firebase already initialized"
fi

# Create functions directory structure
echo "📁 Creating directory structure..."
mkdir -p functions
mkdir -p server/public

# Copy server files to functions
echo "📋 Copying server files..."
if [ -f "server/index.js" ]; then
    cp server/index.js functions/game-server.js
    echo "✅ Copied game-server.js"
fi

if [ -f "server/payment-webhook.js" ]; then
    cp server/payment-webhook.js functions/
    echo "✅ Copied payment-webhook.js"
fi

# Create functions index.js
echo "📝 Creating functions/index.js..."
cat > functions/index.js << 'EOF'
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Import game server
const GameLoop = require('./game-server');

// Keep game loop running
let gameLoop = null;

// Initialize game loop
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
EOF

echo "✅ Created functions/index.js"

# Create package.json for functions
echo "📝 Creating functions/package.json..."
cat > functions/package.json << 'EOF'
{
  "name": "aviator-game-functions",
  "description": "Aviator Crash Game Server - Firebase Functions",
  "version": "1.0.0",
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  },
  "devDependencies": {
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
}
EOF

echo "✅ Created functions/package.json"

# Install dependencies
echo "📦 Installing dependencies..."
cd functions
npm install
cd ..

# Create firebase.json if it doesn't exist
if [ ! -f "firebase.json" ]; then
    echo "📝 Creating firebase.json..."
    cat > firebase.json << 'EOF'
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs18"
  },
  "hosting": {
    "public": "server/public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ]
  }
}
EOF
    echo "✅ Created firebase.json"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy: firebase deploy --only functions,hosting"
echo "2. Initialize: Visit https://YOUR_PROJECT.cloudfunctions.net/initGameServer"
echo "3. Monitor: firebase functions:log"
echo ""
echo "🎮 Your game server will run 24/7 on Firebase!"
