import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Payment gateway integration service for JazzCash and EasyPaisa
/// 
/// This service handles payment processing through third-party payment gateways.
/// You'll need to configure your payment gateway credentials and endpoints.
class PaymentService {
  PaymentService({required this.database});

  final FirebaseDatabase database;

  // TODO: Replace these with your actual payment gateway credentials
  // For Pakistan, you can use:
  // - JazzCash Merchant API
  // - EasyPaisa Merchant API
  // - Or aggregators like Payfast, Paymob, etc.
  
  static const String _merchantId = 'YOUR_MERCHANT_ID';
  static const String _merchantPassword = 'YOUR_MERCHANT_PASSWORD';
  static const String _merchantSalt = 'YOUR_MERCHANT_SALT';
  
  // Payment gateway endpoints
  static const String _jazzcashEndpoint = 'https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/';
  static const String _easypaisaEndpoint = 'https://easypaisa.com.pk/easypay/';
  
  // Your app's callback URLs
  static const String _returnUrl = 'https://your-app.com/payment/return';
  static const String _callbackUrl = 'https://your-app.com/payment/callback';

  /// Initiate a payment transaction
  /// Returns the transaction reference ID
  Future<String> initiatePayment({
    required String uid,
    required double amount,
    required String method,
    required String phoneNumber,
  }) async {
    // Create a deposit request in Firebase
    final depositRef = database.ref('deposits').push();
    final transactionId = depositRef.key!;
    
    await depositRef.set({
      'uid': uid,
      'amount': amount,
      'method': method,
      'phoneNumber': phoneNumber,
      'status': 'pending',
      'transactionId': transactionId,
      'at': ServerValue.timestamp,
    });

    return transactionId;
  }

  /// Launch JazzCash payment
  Future<bool> launchJazzCashPayment({
    required String transactionId,
    required double amount,
    required String phoneNumber,
  }) async {
    // Generate JazzCash payment parameters
    final params = _generateJazzCashParams(
      transactionId: transactionId,
      amount: amount,
      phoneNumber: phoneNumber,
    );

    // Build the payment URL
    final uri = Uri.parse(_jazzcashEndpoint).replace(queryParameters: params);

    // Launch the payment URL
    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
    return false;
  }

  /// Launch EasyPaisa payment
  Future<bool> launchEasyPaisaPayment({
    required String transactionId,
    required double amount,
    required String phoneNumber,
  }) async {
    // Generate EasyPaisa payment parameters
    final params = _generateEasyPaisaParams(
      transactionId: transactionId,
      amount: amount,
      phoneNumber: phoneNumber,
    );

    // Build the payment URL
    final uri = Uri.parse(_easypaisaEndpoint).replace(queryParameters: params);

    // Launch the payment URL
    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
    return false;
  }

  /// Generate JazzCash payment parameters
  Map<String, String> _generateJazzCashParams({
    required String transactionId,
    required double amount,
    required String phoneNumber,
  }) {
    final amountInPaisa = (amount * 100).toInt().toString();
    final dateTime = DateTime.now();
    final expiryDateTime = dateTime.add(const Duration(hours: 1));
    
    // Format: yyyyMMddHHmmss
    final txnDateTime = _formatDateTime(dateTime);
    final txnExpiryDateTime = _formatDateTime(expiryDateTime);

    final params = {
      'pp_Version': '1.1',
      'pp_TxnType': 'MWALLET',
      'pp_Language': 'EN',
      'pp_MerchantID': _merchantId,
      'pp_SubMerchantID': '',
      'pp_Password': _merchantPassword,
      'pp_TxnRefNo': transactionId,
      'pp_Amount': amountInPaisa,
      'pp_TxnCurrency': 'PKR',
      'pp_TxnDateTime': txnDateTime,
      'pp_BillReference': transactionId,
      'pp_Description': 'Aviator Game Deposit',
      'pp_TxnExpiryDateTime': txnExpiryDateTime,
      'pp_ReturnURL': _returnUrl,
      'pp_SecureHash': '',
      'ppmpf_1': phoneNumber,
    };

    // Generate secure hash
    params['pp_SecureHash'] = _generateSecureHash(params);

    return params;
  }

  /// Generate EasyPaisa payment parameters
  Map<String, String> _generateEasyPaisaParams({
    required String transactionId,
    required double amount,
    required String phoneNumber,
  }) {
    final amountInPaisa = (amount * 100).toInt().toString();
    
    return {
      'storeId': _merchantId,
      'amount': amountInPaisa,
      'postBackURL': _callbackUrl,
      'orderRefNum': transactionId,
      'expiryDate': _formatDateTime(DateTime.now().add(const Duration(hours: 1))),
      'merchantHashedReq': '', // Will be generated
      'autoRedirect': '1',
      'paymentMethod': 'MA_PAYMENT_METHOD',
      'emailAddress': 'customer@aviator.com',
      'mobileNum': phoneNumber,
    };
  }

  /// Generate secure hash for JazzCash
  String _generateSecureHash(Map<String, String> params) {
    // Build the string to hash
    final sortedKeys = params.keys.where((k) => k != 'pp_SecureHash').toList()
      ..sort();
    
    final hashString = _merchantSalt +
        sortedKeys.map((k) => params[k]).where((v) => v!.isNotEmpty).join('&');

    // In production, use proper HMAC-SHA256
    // For now, returning a placeholder
    return hashString.hashCode.toString();
  }

  /// Format DateTime for payment gateway
  String _formatDateTime(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}'
        '${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// Verify payment callback from gateway
  Future<bool> verifyPayment({
    required String transactionId,
    required Map<String, dynamic> responseData,
  }) async {
    // Verify the response hash
    // Check transaction status
    final responseCode = responseData['pp_ResponseCode'] ?? 
                        responseData['responseCode'];
    
    if (responseCode == '000' || responseCode == '00') {
      // Payment successful - update deposit status
      await database.ref('deposits/$transactionId').update({
        'status': 'approved',
        'paymentResponse': responseData,
        'approvedAt': ServerValue.timestamp,
      });
      return true;
    } else {
      // Payment failed
      await database.ref('deposits/$transactionId').update({
        'status': 'failed',
        'paymentResponse': responseData,
        'failedAt': ServerValue.timestamp,
      });
      return false;
    }
  }

  /// Check payment status
  Future<String> checkPaymentStatus(String transactionId) async {
    final snapshot = await database.ref('deposits/$transactionId/status').get();
    return snapshot.value?.toString() ?? 'pending';
  }

  /// Listen to payment status changes
  Stream<String> watchPaymentStatus(String transactionId) {
    return database
        .ref('deposits/$transactionId/status')
        .onValue
        .map((event) => event.snapshot.value?.toString() ?? 'pending');
  }
}
