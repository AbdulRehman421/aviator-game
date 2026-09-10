# Server Deployment Guide - 24/7 Hosting

This guide shows you how to deploy your Aviator game server to run 24/7 without keeping your laptop on.

## Option 1: Firebase Cloud Functions (RECOMMENDED) ⭐

### Why Firebase?
- ✅ **FREE** tier includes 2M invocations/month
- ✅ **Auto-scaling** - handles unlimited players
- ✅ **No server management** - Google manages everything
- ✅ **Built-in monitoring** and logs
- ✅ **Already integrated** with your Firebase project
- ✅ **Payment page hosting** included (Firebase Hosting)

### Cost Estimate:
- **FREE tier**: Up to 2M function invocations/month
- **After free tier**: $0.40 per million invocations
- **Typical cost for small game**: $0-5/month

### Setup Steps:

#### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

#### 2. Initialize Firebase Functions

```bash
cd aviator
firebase login
firebase init functions

# Select:
# - Language: JavaScript
# - ESLint: Yes
# - Install dependencies: Yes
```

#### 3. Move Your Server Code

```bash
# Copy your game server to functions
cp server/index.js functions/game-server.js
```

#### 4. Create Functions Entry Point

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Import game server
const GameLoop = require('./game-server');

// Keep game loop running
let gameLoop = null;

// Initialize game loop on function startup
exports.initGameServer = functions.https.onRequest(async (req, res) => {
  if (!gameLoop) {
    gameLoop = new GameLoop();
    await gameLoop.start();
    console.log('Game server started');
  }
  res.json({ status: 'Game server running' });
});

// Keep-alive function (runs every minute)
exports.keepAlive = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    if (!gameLoop) {
      gameLoop = new GameLoop();
      await gameLoop.start();
    }
    console.log('Game server keep-alive');
    return null;
  });

// Payment webhooks
const { handleJazzCashCallback, handleEasyPaisaCallback } = require('./payment-webhook');

exports.jazzcashCallback = functions.https.onRequest(handleJazzCashCallback);
exports.easypaisaCallback = functions.https.onRequest(handleEasyPaisaCallback);
```

#### 5. Update package.json

Edit `functions/package.json`:

```json
{
  "name": "functions",
  "description": "Aviator Game Server",
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  }
}
```

#### 6. Deploy

```bash
firebase deploy --only functions,hosting
```

Your server will be live at:
- Functions: `https://YOUR_PROJECT.cloudfunctions.net/`
- Payment page: `https://YOUR_PROJECT.web.app/deposit.html`

#### 7. Initialize the Server

Visit this URL once to start the game loop:
```
https://YOUR_PROJECT.cloudfunctions.net/initGameServer
```

### Monitoring

View logs:
```bash
firebase functions:log
```

View in Firebase Console:
- Go to Firebase Console → Functions
- See invocations, errors, and performance

---

## Option 2: Heroku (Easy, Paid)

### Why Heroku?
- ✅ Easy deployment with Git
- ✅ Free tier available (with sleep mode)
- ✅ Good for Node.js apps
- ❌ Free tier sleeps after 30 min inactivity
- ❌ Paid tier: $7/month minimum

### Setup:

#### 1. Install Heroku CLI

```bash
# Download from: https://devcenter.heroku.com/articles/heroku-cli
```

#### 2. Create Heroku App

```bash
cd aviator/server
heroku login
heroku create aviator-game-server
```

#### 3. Add Procfile

Create `server/Procfile`:
```
web: node index.js
```

#### 4. Deploy

```bash
git init
git add .
git commit -m "Initial commit"
git push heroku main
```

#### 5. Set Environment Variables

```bash
heroku config:set FIREBASE_CONFIG='{"apiKey":"...","projectId":"..."}'
```

### Cost:
- **Free tier**: Sleeps after 30 min (not suitable for 24/7)
- **Hobby tier**: $7/month (24/7 uptime)
- **Standard tier**: $25/month (better performance)

---

## Option 3: DigitalOcean / AWS / Google Cloud (Advanced)

### Why VPS?
- ✅ Full control over server
- ✅ Can run multiple services
- ✅ Good for scaling
- ❌ Requires server management skills
- ❌ More expensive

### DigitalOcean Setup:

#### 1. Create Droplet

- Go to digitalocean.com
- Create account
- Create Droplet (Ubuntu 22.04)
- Choose $6/month plan

#### 2. SSH into Server

```bash
ssh root@YOUR_SERVER_IP
```

#### 3. Install Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```

#### 4. Upload Your Code

```bash
# On your laptop
scp -r server root@YOUR_SERVER_IP:/root/aviator-server
```

#### 5. Install Dependencies

```bash
cd /root/aviator-server
npm install
```

#### 6. Start with PM2

```bash
pm2 start index.js --name aviator-game
pm2 save
pm2 startup
```

#### 7. Configure Firewall

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### Cost:
- **Basic Droplet**: $6/month
- **Better performance**: $12-24/month

---

## Option 4: Railway.app (Modern, Easy)

### Why Railway?
- ✅ Very easy deployment
- ✅ Free $5 credit/month
- ✅ Automatic HTTPS
- ✅ Good for Node.js
- ❌ Limited free tier

### Setup:

#### 1. Sign up at railway.app

#### 2. Create New Project

- Click "New Project"
- Select "Deploy from GitHub"
- Connect your repository

#### 3. Configure

Railway will auto-detect Node.js and deploy.

#### 4. Add Environment Variables

In Railway dashboard, add:
- `FIREBASE_CONFIG`
- `MERCHANT_ID`
- `MERCHANT_PASSWORD`
- etc.

### Cost:
- **Free**: $5 credit/month (~100 hours)
- **Paid**: $5/month + usage

---

## Comparison Table

| Service | Cost | Ease | Best For |
|---------|------|------|----------|
| **Firebase Functions** | FREE-$5/mo | ⭐⭐⭐⭐⭐ | Small-medium games |
| **Heroku** | $7/mo | ⭐⭐⭐⭐ | Quick deployment |
| **Railway** | $5/mo | ⭐⭐⭐⭐⭐ | Modern apps |
| **DigitalOcean** | $6/mo | ⭐⭐⭐ | Full control |
| **AWS/GCP** | $10+/mo | ⭐⭐ | Enterprise |

---

## My Recommendation: Firebase Functions

For your game, I **strongly recommend Firebase Functions** because:

1. **You're already using Firebase** - No new services needed
2. **FREE for your scale** - 2M invocations covers thousands of players
3. **Zero maintenance** - Google handles everything
4. **Auto-scaling** - Handles traffic spikes automatically
5. **Built-in monitoring** - See everything in Firebase Console
6. **Payment page hosting** - Firebase Hosting is included

### Quick Start (Firebase):

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Initialize
cd aviator
firebase init functions

# 3. Copy server code
cp server/index.js functions/game-server.js
cp server/payment-webhook.js functions/

# 4. Create functions/index.js (see above)

# 5. Deploy
firebase deploy --only functions,hosting

# 6. Initialize
# Visit: https://YOUR_PROJECT.cloudfunctions.net/initGameServer

# Done! Your server is now running 24/7
```

---

## Post-Deployment Checklist

After deploying, verify:

- [ ] Game server is running
- [ ] Players can connect
- [ ] Bets are being processed
- [ ] Rounds are cycling correctly
- [ ] Payment page is accessible
- [ ] Webhooks are receiving callbacks
- [ ] Logs show no errors
- [ ] Database is updating correctly

---

## Monitoring & Maintenance

### Firebase Functions:

```bash
# View logs
firebase functions:log

# View specific function
firebase functions:log --only initGameServer

# Monitor in real-time
firebase functions:log --follow
```

### Set up Alerts:

1. Go to Firebase Console → Functions
2. Click on function name
3. Set up alerts for:
   - High error rate
   - High latency
   - Function crashes

---

## Troubleshooting

### Server not starting:
```bash
# Check logs
firebase functions:log

# Redeploy
firebase deploy --only functions --force
```

### High costs:
- Check function invocations in Firebase Console
- Optimize code to reduce calls
- Add caching where possible

### Connection issues:
- Verify Firebase config is correct
- Check database rules allow server writes
- Ensure functions have proper permissions

---

## Scaling Tips

As your game grows:

1. **Monitor usage** - Watch Firebase Console metrics
2. **Optimize code** - Reduce unnecessary database reads
3. **Add caching** - Cache frequently accessed data
4. **Use Cloud Scheduler** - For periodic tasks
5. **Consider dedicated server** - If costs exceed $50/month

---

## Support

Need help? Check:
- Firebase Functions docs: https://firebase.google.com/docs/functions
- Firebase Console: https://console.firebase.google.com
- Stack Overflow: Tag `firebase-functions`

---

**Start with Firebase Functions - it's free, easy, and perfect for your game!**
