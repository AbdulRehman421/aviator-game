@echo off
echo.
echo ========================================
echo   Firebase Functions Setup
echo   Aviator Game Server - 24/7 Deployment
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js not found! Please install Node.js first.
    echo Download from: https://nodejs.org/
    pause
    exit /b 1
)
echo [OK] Node.js found

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [INSTALLING] Firebase CLI...
    call npm install -g firebase-tools
) else (
    echo [OK] Firebase CLI found
)

echo.
echo [STEP 1] Logging in to Firebase...
call firebase login

echo.
echo [STEP 2] Creating directory structure...
if not exist "functions" mkdir functions
if not exist "server\public" mkdir server\public

echo.
echo [STEP 3] Copying server files...
if exist "server\index.js" (
    copy /Y "server\index.js" "functions\game-server.js" >nul
    echo [OK] Copied game-server.js
)

if exist "server\payment-webhook.js" (
    copy /Y "server\payment-webhook.js" "functions\" >nul
    echo [OK] Copied payment-webhook.js
)

echo.
echo [STEP 4] Creating functions configuration...

REM Create functions/index.js
(
echo const functions = require('firebase-functions'^);
echo const admin = require('firebase-admin'^);
echo.
echo admin.initializeApp(^);
echo.
echo const GameLoop = require('./game-server'^);
echo.
echo let gameLoop = null;
echo.
echo async function ensureGameLoop(^) {
echo   if ^(!gameLoop^) {
echo     gameLoop = new GameLoop(^);
echo     await gameLoop.start(^);
echo     console.log('Game server started'^);
echo   }
echo   return gameLoop;
echo }
echo.
echo exports.initGameServer = functions.https.onRequest(async ^(req, res^) =^> {
echo   try {
echo     await ensureGameLoop(^);
echo     res.json^({ status: 'running', message: 'Game server is active' }^);
echo   } catch ^(error^) {
echo     res.status^(500^).json^({ status: 'error', message: error.message }^);
echo   }
echo }^);
echo.
echo exports.keepAlive = functions.pubsub.schedule('every 1 minutes'^).onRun(async ^(^) =^> {
echo   await ensureGameLoop(^);
echo   return null;
echo }^);
echo.
echo const { handleJazzCashCallback, handleEasyPaisaCallback } = require('./payment-webhook'^);
echo exports.jazzcashCallback = functions.https.onRequest^(handleJazzCashCallback^);
echo exports.easypaisaCallback = functions.https.onRequest^(handleEasyPaisaCallback^);
) > functions\index.js
echo [OK] Created functions/index.js

REM Create functions/package.json
(
echo {
echo   "name": "aviator-game-functions",
echo   "description": "Aviator Game Server",
echo   "version": "1.0.0",
echo   "engines": { "node": "18" },
echo   "main": "index.js",
echo   "dependencies": {
echo     "firebase-admin": "^12.0.0",
echo     "firebase-functions": "^4.5.0"
echo   }
echo }
) > functions\package.json
echo [OK] Created functions/package.json

REM Create firebase.json if it doesn't exist
if not exist "firebase.json" (
    (
    echo {
    echo   "functions": {
    echo     "source": "functions",
    echo     "runtime": "nodejs18"
    echo   },
    echo   "hosting": {
    echo     "public": "server/public",
    echo     "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
    echo   }
    echo }
    ) > firebase.json
    echo [OK] Created firebase.json
)

echo.
echo [STEP 5] Installing dependencies...
cd functions
call npm install
cd ..

echo.
echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo Next steps:
echo   1. Deploy:     firebase deploy --only functions,hosting
echo   2. Initialize: Visit your Cloud Function URL
echo   3. Monitor:    firebase functions:log
echo.
echo Your game server will run 24/7 on Firebase!
echo.
pause
