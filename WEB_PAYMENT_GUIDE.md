# Web-Based Payment Integration Guide

This is the **RECOMMENDED** approach for payment integration - similar to professional games.

## Why This Approach is Better

### ✅ Advantages:
1. **More Secure** - Payment credentials stay on your server, never in the app
2. **Easier Updates** - Change payment logic without updating the app
3. **Better UX** - Professional, consistent payment experience
4. **Multi-Gateway Support** - Easy to add/remove payment methods
5. **PCI Compliance** - Reduced security requirements
6. **Cross-Platform** - Works on Android, iOS, and Web
7. **Easier Testing** - Test payments in browser without rebuilding app

### ❌ Direct Integration Issues:
- Payment credentials exposed in app code
- Must update app for any payment changes
- Complex gateway-specific code in app
- Harder to maintain and debug

## Architecture

```
User clicks Deposit
    ↓
Flutter App creates deposit request in Firebase
    ↓
App opens web page: your-domain.com/deposit.html?depositId=xxx&amount=xxx
    ↓
User selects payment method and enters phone
    ↓
Web page redirects to JazzCash/EasyPaisa
    ↓
User completes payment in their wallet app
    ↓
Gateway sends callback to your server
    ↓
Server updates deposit status to 'approved'
    ↓
Game server auto-credits wallet
    ↓
User sees updated balance in app
```

## Setup Steps

### 1. Host the Payment Page

#### Option A: Firebase Hosting (Recommended - FREE)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
cd aviator
firebase init hosting

# Select:
# - Public directory: server/public
# - Single-page app: No
# - Automatic builds: No

# Deploy
firebase deploy --only hosting
```

Your payment page will be at:
```
https://YOUR_PROJECT.web.app/deposit.html
```

#### Option B: Your Own Domain

1. Upload `server/public/deposit.html` to your web server
2. Access at `https://your-domain.com/deposit.html`

### 2. Configure Firebase in Payment Page

Edit `server/public/deposit.html` and replace Firebase config:

```javascript
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    databaseURL: "https://YOUR_PROJECT.firebaseio.com",
    projectId: "YOUR_PROJECT",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
};
```

Get these from: Firebase Console → Project Settings → General

### 3. Update Flutter App URL

Edit `lib/widgets/dialogs.dart`:

```dart
final paymentUrl = Uri.parse('https://YOUR_PROJECT.web.app/deposit.html').replace(
  queryParameters: {
    'depositId': depositId,
    'uid': engine.uid,
    'amount': amount.toString(),
  },
);
```

### 4. Set Up Payment Gateway Backend

Create a server endpoint to handle payment initiation:

```javascript
// server/payment-api.js
const express = require('express');
const router = express.Router();

router.post('/initiate-payment', async (req, res) => {
  const { depositId, amount, phoneNumber, method } = req.body;
  
  try {
    if (method === 'jazzcash') {
      const paymentUrl = await generateJazzCashURL(depositId, amount, phoneNumber);
      res.json({ success: true, paymentUrl });
    } else if (method === 'easypaisa') {
      const paymentUrl = await generateEasyPaisaURL(depositId, amount, phoneNumber);
      res.json({ success: true, paymentUrl });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
```

### 5. Update Payment Page to Call Backend

In `deposit.html`, update the `initiatePayment` function:

```javascript
async function initiatePayment(depositId, amount, phoneNumber, method) {
    const response = await fetch('https://your-api.com/initiate-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ depositId, amount, phoneNumber, method })
    });
    
    const data = await response.json();
    return data.paymentUrl;
}
```

### 6. Test the Flow

1. Run your Flutter app
2. Click "Deposit"
3. Enter amount and phone number
4. Click "Pay Now"
5. Browser should open with your payment page
6. Select payment method
7. Enter phone number
8. Click "Submit"
9. Should redirect to payment gateway

## Customization

### Change Colors

Edit `deposit.html` CSS:

```css
/* Primary color */
.submit-btn {
    background: #4CAF50; /* Change to your brand color */
}

/* Background */
body {
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
}
```

### Add More Payment Methods

In `deposit.html`, add to payment methods section:

```html
<label class="payment-method" data-method="bank">
    <input type="radio" name="paymentMethod" value="bank">
    <div class="payment-icon">🏦</div>
    <div class="payment-label">Bank Transfer</div>
</label>
```

### Add Urdu/Arabic Support

The page already has bilingual support. To add more:

```html
<div class="info-box">
    English text here
    <br><br>
    اردو متن یہاں
</div>
```

## Security Best Practices

### 1. Validate on Server

Never trust client-side data. Always validate on server:

```javascript
// Verify deposit exists and belongs to user
const deposit = await db.ref(`deposits/${depositId}`).once('value');
if (!deposit.exists() || deposit.val().uid !== userId) {
    throw new Error('Invalid deposit');
}

// Verify amount matches
if (deposit.val().amount !== amount) {
    throw new Error('Amount mismatch');
}
```

### 2. Use HTTPS Only

```javascript
// In deposit.html, check for HTTPS
if (location.protocol !== 'https:' && location.hostname !== 'localhost') {
    alert('This page must be accessed via HTTPS');
}
```

### 3. Implement Rate Limiting

```javascript
// Limit payment attempts per user
const attempts = await db.ref(`payment_attempts/${userId}`).once('value');
if (attempts.val() > 5) {
    throw new Error('Too many payment attempts. Please try again later.');
}
```

### 4. Add CORS Protection

```javascript
// Only allow requests from your app
app.use(cors({
    origin: ['https://YOUR_PROJECT.web.app', 'https://your-app.com']
}));
```

## Testing

### Test in Browser

1. Open: `http://localhost:8080/deposit.html?depositId=test123&uid=testuser&amount=1000`
2. Fill in form
3. Check browser console for errors
4. Verify Firebase updates

### Test in App

1. Enable USB debugging
2. Run app: `flutter run`
3. Click deposit
4. Check if browser opens
5. Complete payment flow

## Troubleshooting

### Browser doesn't open
- Check `url_launcher` package is installed
- Verify URL is correct
- Check device has browser app

### Payment page shows error
- Check Firebase config is correct
- Verify depositId exists in database
- Check browser console for errors

### Payment not completing
- Check webhook is receiving callbacks
- Verify payment gateway credentials
- Check server logs

## Going Live

### Checklist:

- [ ] Replace Firebase config with production
- [ ] Update payment gateway to production URLs
- [ ] Use production merchant credentials
- [ ] Enable HTTPS on all endpoints
- [ ] Test with real small amounts
- [ ] Set up monitoring and alerts
- [ ] Add error tracking (Sentry, etc.)
- [ ] Configure proper CORS
- [ ] Add rate limiting
- [ ] Set up backup payment methods

## Cost Estimate

### Firebase Hosting (FREE tier includes):
- 10 GB storage
- 360 MB/day bandwidth
- Free SSL certificate
- Custom domain support

### Payment Gateway Fees:
- **JazzCash**: 1.5% - 2.5% per transaction
- **EasyPaisa**: 1.5% - 2.5% per transaction
- **Minimum**: Usually PKR 10-20 per transaction

## Support

If you need help:
1. Check browser console for errors
2. Check Firebase logs
3. Check server logs
4. Test with sandbox credentials first

## Next Steps

1. Deploy payment page to Firebase Hosting
2. Update Flutter app with correct URL
3. Test in sandbox environment
4. Apply for production access
5. Go live!

---

**This approach is used by professional games because it's secure, maintainable, and provides the best user experience.**
