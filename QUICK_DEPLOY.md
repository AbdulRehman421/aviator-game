# Quick Deploy Guide - 5 Minutes to 24/7 Server

Deploy your Aviator game server to run 24/7 without keeping your laptop on.

## Prerequisites

- ✅ Node.js installed
- ✅ Firebase project created
- ✅ Game working locally

## Step 1: Run Setup Script (Windows)

```cmd
cd C:\Users\Syed Abdul Rehman\StudioProjects\avaitor\aviator
firebase-functions-setup.bat
```

This will:
- Install Firebase CLI
- Login to Firebase
- Copy server files
- Create configuration
- Install dependencies

## Step 2: Deploy to Firebase

```cmd
firebase deploy --only functions,hosting
```

Wait 2-3 minutes for deployment to complete.

## Step 3: Initialize Server

After deployment, you'll see URLs like:
```
✔  functions[initGameServer(us-central1)] https://us-central1-YOUR_PROJECT.cloudfunctions.net/initGameServer
✔  functions[keepAlive(us-central1)] Scheduled
✔  hosting[YOUR_PROJECT] https://YOUR_PROJECT.web.app
```

**Visit the initGameServer URL once** to start your game:
```
https://us-central1-YOUR_PROJECT.cloudfunctions.net/initGameServer
```

You should see:
```json
{
  "status": "running",
  "message": "Game server is active"
}
```

## Step 4: Update Flutter App

Update the payment URL in `lib/widgets/dialogs.dart`:

```dart
final paymentUrl = Uri.parse('https://YOUR_PROJECT.web.app/deposit.html').replace(
  queryParameters: {
    'depositId': depositId,
    'uid': engine.uid,
    'amount': amount.toString(),
  },
);
```

Replace `YOUR_PROJECT` with your actual Firebase project ID.

## Step 5: Test

1. Run your Flutter app
2. Try placing a bet
3. Check if rounds are cycling
4. Try deposit flow

## Monitoring

### View Logs:
```cmd
firebase functions:log
```

### View in Firebase Console:
1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Functions" in left menu
4. See all function invocations and logs

### Check Server Status:
Visit: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/health`

## Troubleshooting

### "Command not found: firebase"
```cmd
npm install -g firebase-tools
```

### "Not logged in"
```cmd
firebase login
```

### "Permission denied"
```cmd
firebase login --reauth
```

### Server not starting
```cmd
# Check logs
firebase functions:log

# Redeploy
firebase deploy --only functions --force
```

### High costs
Check usage in Firebase Console. Free tier includes:
- 2M function invocations/month
- 10GB hosting bandwidth/month

Typical usage for small game: **FREE**

## What Happens Now?

✅ **Game server runs 24/7** - No laptop needed  
✅ **Auto-scaling** - Handles any number of players  
✅ **Keep-alive** - Runs every minute to stay active  
✅ **Payment page** - Hosted on Firebase  
✅ **Webhooks** - Ready for JazzCash/EasyPaisa  
✅ **Monitoring** - Built-in logs and metrics  

## Cost Breakdown

### FREE Tier Includes:
- 2,000,000 function invocations/month
- 400,000 GB-seconds compute time
- 10 GB hosting bandwidth
- 1 GB hosting storage

### Your Expected Usage:
- **Game loop**: ~43,000 invocations/month (every minute)
- **Player actions**: ~10,000-50,000/month (depends on players)
- **Total**: Well within FREE tier

### If You Exceed Free Tier:
- $0.40 per million invocations
- Typical cost: $0-5/month for small game

## Next Steps

1. ✅ Server deployed and running 24/7
2. ✅ Payment page hosted
3. ⏭️ Configure payment gateway credentials
4. ⏭️ Test with real players
5. ⏭️ Set up monitoring alerts
6. ⏭️ Add more features!

## Support

Need help?
- Firebase docs: https://firebase.google.com/docs/functions
- Check logs: `firebase functions:log`
- Firebase Console: https://console.firebase.google.com

---

**Congratulations! Your game server is now running 24/7 in the cloud! 🎉**
