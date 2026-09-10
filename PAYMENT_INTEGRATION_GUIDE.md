# Payment Gateway Integration Guide

This guide explains how to integrate JazzCash and EasyPaisa payment gateways into your Aviator game.

## Overview

The payment integration consists of three main components:

1. **Flutter App** (`lib/services/payment_service.dart`) - Initiates payments and launches payment gateway
2. **Payment Gateway** (JazzCash/EasyPaisa) - Processes the actual payment
3. **Webhook Handler** (`server/payment-webhook.js`) - Receives payment confirmation callbacks

## Flow Diagram

```
User → Flutter App → Payment Gateway → User completes payment
                          ↓
                    Webhook Handler → Firebase → Auto-credit wallet
```

## Step 1: Get Payment Gateway Credentials

### For JazzCash:
1. Visit [JazzCash Merchant Portal](https://sandbox.jazzcash.com.pk/)
2. Register as a merchant
3. Get your credentials:
   - Merchant ID
   - Merchant Password
   - Integration Salt (Secret Key)

### For EasyPaisa:
1. Visit [EasyPaisa Business](https://easypaisa.com.pk/business/)
2. Register for merchant account
3. Get your credentials:
   - Store ID
   - Secret Key

## Step 2: Configure Credentials

### In Flutter App (`lib/services/payment_service.dart`):

```dart
static const String _merchantId = 'YOUR_MERCHANT_ID';
static const String _merchantPassword = 'YOUR_MERCHANT_PASSWORD';
static const String _merchantSalt = 'YOUR_MERCHANT_SALT';
```

### In Server (`server/payment-webhook.js`):

```javascript
const MERCHANT_ID = process.env.MERCHANT_ID || 'YOUR_MERCHANT_ID';
const MERCHANT_PASSWORD = process.env.MERCHANT_PASSWORD || 'YOUR_MERCHANT_PASSWORD';
const MERCHANT_SALT = process.env.MERCHANT_SALT || 'YOUR_MERCHANT_SALT';
```

**Important:** Use environment variables in production, never hardcode credentials!

## Step 3: Deploy Webhook Handler

### Option A: Deploy as Cloud Function (Recommended)

```bash
# Install Firebase Functions
npm install -g firebase-tools
firebase init functions

# Copy payment-webhook.js to functions/index.js
# Add the following to functions/index.js:

const functions = require('firebase-functions');
const { handleJazzCashCallback, handleEasyPaisaCallback } = require('./payment-webhook');

exports.jazzcashCallback = functions.https.onRequest(handleJazzCashCallback);
exports.easypaisaCallback = functions.https.onRequest(handleEasyPaisaCallback);

# Deploy
firebase deploy --only functions
```

Your webhook URLs will be:
- JazzCash: `https://YOUR_PROJECT.cloudfunctions.net/jazzcashCallback`
- EasyPaisa: `https://YOUR_PROJECT.cloudfunctions.net/easypaisaCallback`

### Option B: Add to Existing Express Server

```javascript
const express = require('express');
const { handleJazzCashCallback, handleEasyPaisaCallback } = require('./payment-webhook');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.post('/payment/jazzcash/callback', handleJazzCashCallback);
app.post('/payment/easypaisa/callback', handleEasyPaisaCallback);

app.listen(3000);
```

## Step 4: Configure Payment Gateway Dashboard

### JazzCash Configuration:
1. Login to JazzCash Merchant Portal
2. Go to Settings → Integration
3. Set **Return URL**: `yourapp://payment/return`
4. Set **Callback URL**: Your webhook URL from Step 3
5. Enable **Mobile Wallet (MWALLET)** payment method

### EasyPaisa Configuration:
1. Login to EasyPaisa Merchant Portal
2. Go to Integration Settings
3. Set **Post Back URL**: Your webhook URL from Step 3
4. Enable **Mobile Account** payment method

## Step 5: Update Flutter App URLs

In `lib/services/payment_service.dart`, update:

```dart
// Your webhook URLs from Step 3
static const String _returnUrl = 'yourapp://payment/return';
static const String _callbackUrl = 'https://YOUR_PROJECT.cloudfunctions.net/jazzcashCallback';
```

## Step 6: Enable Deep Linking (Optional)

To handle return URLs in your app:

### Android (`android/app/src/main/AndroidManifest.xml`):

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="yourapp" android:host="payment" />
</intent-filter>
```

### iOS (`ios/Runner/Info.plist`):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

## Step 7: Install Dependencies

```bash
cd aviator
flutter pub get
```

## Step 8: Test Payment Flow

### Testing with Sandbox:

1. **JazzCash Sandbox**:
   - Use test credentials from JazzCash
   - Test phone: Any valid format
   - Test OTP: Usually `1234` or `0000`

2. **EasyPaisa Sandbox**:
   - Use test credentials from EasyPaisa
   - Test phone: Provided by EasyPaisa
   - Test PIN: Provided by EasyPaisa

### Testing Steps:

1. Run your Flutter app
2. Click "Deposit"
3. Select JazzCash or EasyPaisa
4. Enter phone number and amount
5. Click "Pay Now"
6. Complete payment in gateway
7. Check Firebase → deposits → status should change to "approved"
8. Check user wallet → balance should be credited

## Step 9: Go Live

### Before Production:

1. ✅ Replace sandbox URLs with production URLs
2. ✅ Use production merchant credentials
3. ✅ Test with real small amounts
4. ✅ Set up proper error handling
5. ✅ Enable transaction logging
6. ✅ Set up monitoring/alerts

### Production URLs:

**JazzCash Production:**
```dart
static const String _jazzcashEndpoint = 
    'https://payments.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/';
```

**EasyPaisa Production:**
```dart
static const String _easypaisaEndpoint = 
    'https://easypaisa.com.pk/easypay/';
```

## Troubleshooting

### Payment not redirecting:
- Check if `url_launcher` package is installed
- Verify payment gateway URLs are correct
- Check device has internet connection

### Callback not received:
- Verify webhook URL is publicly accessible
- Check Firebase Functions logs
- Ensure callback URL is configured in gateway dashboard

### Payment successful but wallet not credited:
- Check `deposits/{transactionId}/status` in Firebase
- Verify server game loop is running
- Check server logs for errors

### Hash verification failed:
- Ensure merchant salt matches in all places
- Check parameter order in hash calculation
- Verify no extra spaces in credentials

## Security Best Practices

1. **Never expose credentials in client code**
2. **Always verify payment callbacks on server**
3. **Use HTTPS for all webhook endpoints**
4. **Implement rate limiting on payment endpoints**
5. **Log all transactions for audit trail**
6. **Set up fraud detection rules**
7. **Monitor for unusual payment patterns**

## Support

### JazzCash Support:
- Email: merchantsupport@jazzcash.com.pk
- Phone: 111-124-444

### EasyPaisa Support:
- Email: merchantsupport@easypaisa.com.pk
- Phone: 111-003-947

## Alternative Payment Aggregators

If direct integration is complex, consider using payment aggregators:

1. **Payfast.pk** - Supports JazzCash, EasyPaisa, and cards
2. **Paymob** - Multi-channel payment gateway
3. **Stripe** (with local payment methods)

These provide simpler APIs and handle gateway complexities.

## Next Steps

1. Complete merchant registration
2. Get sandbox credentials
3. Test in sandbox environment
4. Apply for production access
5. Deploy and go live!

---

**Note:** Payment gateway integration requires proper merchant agreements and compliance with local regulations. Ensure you have all necessary licenses and approvals before processing real payments.
