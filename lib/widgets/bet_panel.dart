import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';

class BetPanel extends StatefulWidget {
  const BetPanel({super.key, required this.engine, required this.index});

  final GameClient engine;
  final int index;

  @override
  State<BetPanel> createState() => _BetPanelState();
}

class _BetPanelState extends State<BetPanel> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _autoCtrl;
  bool _autoTab = false;

  GameClient get engine => widget.engine;
  BetSlot get slot => engine.slots[widget.index];

  static const _quick = [64.0, 160.0, 320.0, 1600.0];
  static const _step = 10.0;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: money(slot.amount));
    _autoCtrl =
        TextEditingController(text: slot.autoCashOutAt.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _autoCtrl.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    engine.setAmount(widget.index, v);
    _amountCtrl.text = money(slot.amount);
    _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
  }

  void _commitTypedAmount() {
    final v = double.tryParse(_amountCtrl.text);
    if (v != null) _setAmount(v);
    _amountCtrl.text = money(slot.amount);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([engine, engine.frame]),
      builder: (context, _) {
        final locked = slot.isBusy;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabs(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _amountControls(locked)),
                  const SizedBox(width: 10),
                  Expanded(child: _actionButton()),
                ],
              ),
              if (_autoTab) ...[
                const SizedBox(height: 12),
                _autoToggles(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tabs() {
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.border : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            tab('Bet', !_autoTab, () => setState(() => _autoTab = false)),
            tab('Auto', _autoTab, () => setState(() => _autoTab = true)),
          ],
        ),
      ),
    );
  }

  Widget _amountControls(bool locked) {
    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _stepButton(
                  Icons.remove,
                  locked
                      ? null
                      : () {
                          _setAmount(slot.amount - _step);
                        }),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  enabled: !locked,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onSubmitted: (_) => _commitTypedAmount(),
                  onTapOutside: (_) => _commitTypedAmount(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              _stepButton(
                  Icons.add,
                  locked
                      ? null
                      : () {
                          _setAmount(slot.amount + _step);
                        }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _quick.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextButton(
                    onPressed: locked
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _setAmount(_quick[i]);
                          },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.panelAlt,
                      foregroundColor: Colors.white60,
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _quickLabel(_quick[i]),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _quickLabel(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
      : v.toStringAsFixed(0);

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        onPressed: onTap,
        icon:
            Icon(icon, color: onTap == null ? Colors.white24 : Colors.white70),
      ),
    );
  }

  Widget _actionButton() {
    final e = engine;
    final i = widget.index;
    String label;
    String? sub;
    Color color;
    VoidCallback? onTap;

    if (slot.pending) {
      label = 'PLACING…';
      sub = pkr(slot.amount);
      color = AppColors.green.withValues(alpha: 0.45);
    } else if (slot.isPlaced) {
      final bet = slot.bet!;
      if (slot.isCashedOut) {
        label = 'CASHED OUT';
        sub = '${multiplierText(slot.cashedOutAt!)}  +${money(slot.payout!)}';
        color = AppColors.green.withValues(alpha: 0.45);
      } else if (e.phase == RoundPhase.flying) {
        if (bet.cashOutRequested) {
          label = 'CASHING OUT…';
          color = AppColors.orange.withValues(alpha: 0.6);
        } else {
          label = 'CASH OUT';
          sub = pkr(slot.placedAmount! * e.currentMultiplier);
          color = AppColors.orange;
          onTap = () => e.cashOut(i);
        }
      } else if (e.phase == RoundPhase.betting) {
        if (bet.cancelRequested) {
          label = 'CANCELLING…';
          color = AppColors.red.withValues(alpha: 0.6);
        } else {
          label = 'CANCEL';
          color = AppColors.red;
          onTap = () => e.cancelBet(i);
        }
      } else {
        label = 'FLEW AWAY';
        sub = '-${pkr(slot.placedAmount!)}';
        color = Colors.white12;
      }
    } else if (slot.queued) {
      label = 'CANCEL';
      sub = 'Waiting for next round';
      color = AppColors.red;
      onTap = () => e.cancelBet(i);
    } else {
      label = 'BET';
      sub = pkr(slot.amount);
      color = AppColors.green;
      onTap = !e.hasRound
          ? null
          : () {
              _commitTypedAmount();
              if (!e.placeBet(i) && e.phase == RoundPhase.betting) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insufficient balance'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            };
    }

    return SizedBox(
      height: 72,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(sub,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _autoToggles() {
    final i = widget.index;
    return Column(
      children: [
        Row(
          children: [
            const Text('Auto bet',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            _switch(slot.autoBet, (v) => engine.setAutoBet(i, v)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Auto Cash Out',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            _switch(slot.autoCashOut, (v) => engine.setAutoCashOut(i, v)),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              height: 32,
              child: TextField(
                controller: _autoCtrl,
                enabled: slot.autoCashOut,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v >= 1.01) {
                    engine.setAutoCashOutAt(i, v);
                  }
                },
                style: TextStyle(
                  color: slot.autoCashOut ? Colors.white : Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.field,
                  suffixText: 'x',
                  suffixStyle: const TextStyle(color: Colors.white38),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 28,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.green,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
