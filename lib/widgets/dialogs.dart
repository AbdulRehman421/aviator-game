import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/fair.dart';
import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';

Future<void> showRoundDetails(BuildContext context, RoundResult r) {
  final verified =
      r.combinedHash.length >= 13 ? crashPointFromHash(r.combinedHash) : 0.0;
  final ok = (verified - r.crashPoint).abs() < 0.005;
  final color = AppColors.forMultiplier(r.crashPoint);

  return showDialog(
    context: context,
    builder: (ctx) => _Dialog(
      title: 'Round #${r.roundId}',
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(multiplierText(r.crashPoint),
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${r.totalBets} bets · ${pkr(r.totalWagered)}\n'
                '${_time(r.endedAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _seedField('Server seed', r.serverSeed),
        _seedField(
            'Server seed SHA-256 (published before round)', r.serverSeedHash),
        for (var i = 0; i < r.clientSeeds.length; i++)
          _seedField('Client seed ${i + 1}', r.clientSeeds[i]),
        _seedField('Combined SHA-512', r.combinedHash),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(ok ? Icons.verified : Icons.error,
                color: ok ? AppColors.green : AppColors.red, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ok
                    ? 'Verified: hash reproduces ${multiplierText(verified)}'
                    : 'Mismatch: hash gives ${multiplierText(verified)}',
                style: TextStyle(
                    color: ok ? AppColors.green : AppColors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> showProvablyFair(BuildContext context, GameClient engine) {
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: engine,
      builder: (ctx, _) => _Dialog(
        title: 'Provably Fair',
        children: [
          const Text(
            'Before each round the game commits to a secret server seed by '
            'publishing its SHA-256 hash. Three client seeds are combined with '
            'the server seed into a SHA-512 hash, and the crash point is '
            'derived from the first 52 bits of that hash. After the round the '
            'server seed is revealed so anyone can recompute the result.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text('CURRENT ROUND #${engine.roundId}',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          _seedField('Server seed SHA-256', engine.serverSeedHash),
          for (var i = 0; i < engine.clientSeeds.length; i++)
            _seedField('Client seed ${i + 1}', engine.clientSeeds[i]),
          if (engine.lastRound != null) ...[
            const SizedBox(height: 12),
            Text('PREVIOUS ROUND #${engine.lastRound!.roundId}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            _seedField('Revealed server seed', engine.lastRound!.serverSeed),
            _seedField('Result', multiplierText(engine.lastRound!.crashPoint)),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showRoundDetails(context, engine.lastRound!);
              },
              child: const Text('Verify previous round'),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> showHowToPlay(BuildContext context) {
  const steps = [
    (
      'Place a bet',
      'Choose an amount and press BET before the plane takes off. You can run two bets at once.'
    ),
    (
      'Watch it fly',
      'The multiplier grows from 1.00x as the plane climbs. Your potential win is bet × multiplier.'
    ),
    (
      'Cash out in time',
      'Press CASH OUT before the plane flies away to lock in the win. If it flies away first, the bet is lost.'
    ),
    (
      'Automate',
      'Use the Auto tab to bet every round and/or cash out automatically at a chosen multiplier.'
    ),
  ];
  return showDialog(
    context: context,
    builder: (ctx) => _Dialog(
      title: 'How to play',
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.red,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(steps[i].$2,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Minimum bet ${pkr(GameRules.minBet)} · Maximum bet ${pkr(GameRules.maxBet)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> showWallet(BuildContext context, GameClient engine) {
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: engine,
      builder: (ctx, _) => _Dialog(
        title: 'Wallet',
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BALANCE',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(pkr(engine.balance),
                          style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showDeposit(ctx, engine),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Deposit'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('RECENT TRANSACTIONS',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          if (engine.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No transactions yet.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            for (final t in engine.transactions.take(30)) _txRow(t),
        ],
      ),
    ),
  );
}

Widget _txRow(WalletTx t) {
  final positive = t.amount >= 0;
  String label;
  IconData icon;
  switch (t.type) {
    case 'bet':
      label = 'Bet · Round #${t.roundId ?? '-'}';
      icon = Icons.casino_outlined;
      break;
    case 'win':
      label = 'Win · Round #${t.roundId ?? '-'}';
      icon = Icons.emoji_events_outlined;
      break;
    case 'refund':
      label = 'Bet cancelled · Round #${t.roundId ?? '-'}';
      icon = Icons.undo;
      break;
    case 'deposit':
      final method = t.method;
      if (method == 'jazzcash') {
        label = 'Deposit · JazzCash';
        icon = Icons.phone_android;
      } else if (method == 'easypaisa') {
        label = 'Deposit · EasyPaisa';
        icon = Icons.account_balance_wallet;
      } else {
        label = 'Deposit';
        icon = Icons.account_balance_wallet_outlined;
      }
      break;
    case 'signup_bonus':
      label = 'Welcome bonus';
      icon = Icons.card_giftcard;
      break;
    default:
      label = t.type;
      icon = Icons.receipt_long_outlined;
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text(_dateTime(t.time),
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${positive ? '+' : ''}${money(t.amount)}',
          style: TextStyle(
            color: positive ? AppColors.green : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Future<void> _showDeposit(BuildContext context, GameClient engine) async {
  final amountCtrl = TextEditingController(text: '1000');
  final phoneCtrl = TextEditingController();
  String selectedMethod = 'jazzcash';
  
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _Dialog(
        title: 'Deposit PKR',
        children: [
          const Text(
            'Select payment method and enter details to proceed.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Method',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodButton(
                  label: 'JazzCash',
                  icon: Icons.phone_android,
                  isSelected: selectedMethod == 'jazzcash',
                  onTap: () => setState(() => selectedMethod = 'jazzcash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodButton(
                  label: 'EasyPaisa',
                  icon: Icons.account_balance_wallet,
                  isSelected: selectedMethod == 'easypaisa',
                  onTap: () => setState(() => selectedMethod = 'easypaisa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Mobile Number',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.field,
              prefixText: '+92 ',
              prefixStyle: const TextStyle(color: Colors.white70),
              hintText: '3001234567',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Amount',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.field,
              suffixText: 'PKR',
              hintText: 'Min 100 PKR',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will be redirected to ${selectedMethod == 'jazzcash' ? 'JazzCash' : 'EasyPaisa'} to complete payment.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text);
                  final phone = phoneCtrl.text.trim();
                  if (amount == null || amount < 100) return;
                  if (phone.isEmpty || phone.length < 10) return;
                  Navigator.of(ctx).pop({
                    'amount': amount,
                    'method': selectedMethod,
                    'phone': phone,
                  });
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                child: const Text('Pay Now'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  
  if (result == null) return;
  final amount = result['amount'] as double;
  final method = result['method'] as String;
  final phone = result['phone'] as String;
  
  try {
    // Create deposit request in Firebase
    final depositId = await engine.requestDeposit(amount, method: method);
    
    if (!context.mounted) return;
    
    // Build payment page URL
    // TODO: Replace with your actual domain
    final paymentUrl = Uri.parse('https://your-domain.com/deposit.html').replace(
      queryParameters: {
        'depositId': depositId,
        'uid': engine.uid,
        'amount': amount.toString(),
      },
    );
    
    // Launch payment page in browser
    final canLaunch = await canLaunchUrl(paymentUrl);
    if (canLaunch) {
      final launched = await launchUrl(
        paymentUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (!context.mounted) return;
      
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening payment page...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to launch payment page');
      }
    } else {
      throw Exception('Cannot open payment page. Please check your browser settings.');
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: $e')),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.green.withValues(alpha: 0.15) : AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.green : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.green : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

String _time(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

Widget _seedField(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.white54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Dialog extends StatelessWidget {
  const _Dialog({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
