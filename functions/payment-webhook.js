/**
 * Payment Gateway Webhook Handler
 * 
 * This file handles payment callbacks from JazzCash and EasyPaisa.
 * Deploy this as a separate Cloud Function or Express endpoint.
 * 
 * Setup:
 * 1. Deploy this as a publicly accessible endpoint
 * 2. Configure your payment gateway to send callbacks to this URL
 * 3. Update the callback URL in your payment gateway dashboard
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();

// Your merchant credentials (same as in payment_service.dart)
const MERCHANT_ID = process.env.MERCHANT_ID || 'YOUR_MERCHANT_ID';
const MERCHANT_PASSWORD = process.env.MERCHANT_PASSWORD || 'YOUR_MERCHANT_PASSWORD';
const MERCHANT_SALT = process.env.MERCHANT_SALT || 'YOUR_MERCHANT_SALT';

/**
 * Handle JazzCash payment callback
 */
async function handleJazzCashCallback(req, res) {
  try {
    const response = req.body;
    
    console.log('[JazzCash Callback]', response);
    
    // Verify the secure hash
    if (!verifyJazzCashHash(response)) {
      console.error('[JazzCash] Invalid secure hash');
      return res.status(400).json({ error: 'Invalid secure hash' });
    }
    
    const transactionId = response.pp_TxnRefNo;
    const responseCode = response.pp_ResponseCode;
    const responseMessage = response.pp_ResponseMessage;
    
    // Get deposit record
    const depositRef = db.ref(`deposits/${transactionId}`);
    const snapshot = await depositRef.once('value');
    
    if (!snapshot.exists()) {
      console.error('[JazzCash] Transaction not found:', transactionId);
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    const deposit = snapshot.val();
    
    // Check if payment was successful
    if (responseCode === '000') {
      // Payment successful
      console.log('[JazzCash] Payment successful:', transactionId);
      
      await depositRef.update({
        status: 'approved',
        paymentResponse: response,
        approvedAt: admin.database.ServerValue.TIMESTAMP,
      });
      
      // The existing server game loop will automatically credit the wallet
      // when it detects status changed to 'approved'
      
      res.json({ success: true, message: 'Payment processed successfully' });
    } else {
      // Payment failed
      console.log('[JazzCash] Payment failed:', transactionId, responseMessage);
      
      await depositRef.update({
        status: 'failed',
        paymentResponse: response,
        failedAt: admin.database.ServerValue.TIMESTAMP,
        failureReason: responseMessage,
      });
      
      res.json({ success: false, message: responseMessage });
    }
  } catch (error) {
    console.error('[JazzCash] Error processing callback:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * Handle EasyPaisa payment callback
 */
async function handleEasyPaisaCallback(req, res) {
  try {
    const response = req.body;
    
    console.log('[EasyPaisa Callback]', response);
    
    // Verify the hash
    if (!verifyEasyPaisaHash(response)) {
      console.error('[EasyPaisa] Invalid hash');
      return res.status(400).json({ error: 'Invalid hash' });
    }
    
    const transactionId = response.orderRefNum;
    const responseCode = response.responseCode;
    const responseMessage = response.responseDesc;
    
    // Get deposit record
    const depositRef = db.ref(`deposits/${transactionId}`);
    const snapshot = await depositRef.once('value');
    
    if (!snapshot.exists()) {
      console.error('[EasyPaisa] Transaction not found:', transactionId);
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    const deposit = snapshot.val();
    
    // Check if payment was successful (response code '00' or '0000')
    if (responseCode === '00' || responseCode === '0000') {
      // Payment successful
      console.log('[EasyPaisa] Payment successful:', transactionId);
      
      await depositRef.update({
        status: 'approved',
        paymentResponse: response,
        approvedAt: admin.database.ServerValue.TIMESTAMP,
      });
      
      res.json({ success: true, message: 'Payment processed successfully' });
    } else {
      // Payment failed
      console.log('[EasyPaisa] Payment failed:', transactionId, responseMessage);
      
      await depositRef.update({
        status: 'failed',
        paymentResponse: response,
        failedAt: admin.database.ServerValue.TIMESTAMP,
        failureReason: responseMessage,
      });
      
      res.json({ success: false, message: responseMessage });
    }
  } catch (error) {
    console.error('[EasyPaisa] Error processing callback:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * Verify JazzCash secure hash
 */
function verifyJazzCashHash(response) {
  const receivedHash = response.pp_SecureHash;
  
  // Build hash string (same order as sent)
  const sortedKeys = Object.keys(response)
    .filter(k => k !== 'pp_SecureHash')
    .sort();
  
  const hashString = MERCHANT_SALT + 
    sortedKeys
      .map(k => response[k])
      .filter(v => v !== undefined && v !== '')
      .join('&');
  
  const calculatedHash = crypto
    .createHmac('sha256', MERCHANT_SALT)
    .update(hashString)
    .digest('hex')
    .toUpperCase();
  
  return calculatedHash === receivedHash.toUpperCase();
}

/**
 * Verify EasyPaisa hash
 */
function verifyEasyPaisaHash(response) {
  const receivedHash = response.merchantHashedResp;
  
  // Build hash string according to EasyPaisa documentation
  const hashString = `${MERCHANT_SALT}${response.amount}${response.orderRefNum}`;
  
  const calculatedHash = crypto
    .createHash('sha256')
    .update(hashString)
    .digest('hex')
    .toUpperCase();
  
  return calculatedHash === receivedHash.toUpperCase();
}

/**
 * Express.js route handlers
 * Add these to your Express app:
 * 
 * app.post('/payment/jazzcash/callback', handleJazzCashCallback);
 * app.post('/payment/easypaisa/callback', handleEasyPaisaCallback);
 */

module.exports = {
  handleJazzCashCallback,
  handleEasyPaisaCallback,
};
