# Deploy to Render.com - Step by Step

## Step 1: Sign Up on Render

1. **Open your browser** and go to: https://dashboard.render.com/register
2. **Sign up** using:
   - GitHub (recommended - easiest)
   - OR Google
   - OR Email
3. **Verify your email** if needed

## Step 2: Create New Web Service

1. After logging in, click the **"New +"** button (top right)
2. Select **"Web Service"**

## Step 3: Connect Your Code

You have 2 options:

### Option A: Connect GitHub (Recommended)

1. Click **"Connect GitHub"**
2. Authorize Render to access your repos
3. Select your `aviator` repository
4. Click **"Connect"**

### Option B: Deploy from Git URL

1. Click **"Public Git repository"**
2. Enter: `https://github.com/YOUR_USERNAME/aviator.git`
3. Click **"Continue"**

### Option C: Manual Upload (If no GitHub)

If you don't have GitHub, we'll create a repo first:

1. Go to: https://github.com/new
2. Name: `aviator-game`
3. Click "Create repository"
4. Then run these commands:

```bash
cd C:\Users\Syed Abdul Rehman\StudioProjects\avaitor\aviator
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/aviator-game.git
git push -u origin main
```

Then go back to Render and connect this repo.

## Step 4: Configure the Service

Fill in these settings:

**Name:** `aviator-game-server`

**Region:** `Singapore` (closest to Pakistan for best performance)

**Branch:** `main` (or `master`)

**Root Directory:** `server`

**Runtime:** `Node`

**Build Command:**
```
npm install
```

**Start Command:**
```
node index.js
```

**Plan:** Select **"Free"**

## Step 5: Add Environment Variables

Click **"Advanced"** and add these environment variables:

1. Click **"Add Environment Variable"**
2. Add your Firebase credentials:

**Key:** `FIREBASE_PROJECT_ID`
**Value:** `aviator-91a24`

**Key:** `FIREBASE_DATABASE_URL`
**Value:** `https://aviator-91a24-default-rtdb.firebaseio.com`

(Add any other environment variables your server needs)

## Step 6: Deploy!

1. Click **"Create Web Service"**
2. Wait 3-5 minutes while Render:
   - Builds your code
   - Installs dependencies
   - Starts your server

You'll see logs in real-time!

## Step 7: Get Your Server URL

Once deployed, you'll see:
```
Your service is live at https://aviator-game-server.onrender.com
```

**Copy this URL!** You'll need it for your Flutter app.

## Step 8: Test Your Server

Visit: `https://aviator-game-server.onrender.com`

You should see your game server running!

## Step 9: Update Flutter App

Update `lib/widgets/dialogs.dart` with your Render URL:

```dart
final paymentUrl = Uri.parse('https://aviator-game-server.onrender.com/deposit.html')
```

## Important Notes:

⚠️ **Free tier limitations:**
- Server sleeps after 15 minutes of inactivity
- Takes ~30 seconds to wake up on first request
- 750 hours/month free (enough for 24/7 if you keep it alive)

✅ **Keep it alive:**
- Use UptimeRobot.com (FREE) to ping your server every 5 minutes
- This prevents it from sleeping

## Troubleshooting:

### Build fails:
- Check the logs in Render dashboard
- Make sure `package.json` is in the `server` folder
- Verify Node version is compatible

### Server won't start:
- Check environment variables are set correctly
- Look at the logs for error messages
- Make sure Firebase credentials are valid

### Can't access server:
- Wait 30 seconds for it to wake up (first request)
- Check if deployment succeeded
- Verify the URL is correct

---

**Next:** Once your server is live, I'll help you deploy the payment page to Netlify!
