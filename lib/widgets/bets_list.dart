import 'package:flutter/material.dart';

import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';

class BetsListPanel extends StatefulWidget {
  const BetsListPanel({
    super.key,
    required this.engine,
    this.expand = false,
  });

  final GameClient engine;

  /// When true the list fills available height and scrolls internally;
  /// otherwise it lays out all rows (for use inside a parent scroll view).
  final bool expand;

  @override
  State<BetsListPanel> createState() => _BetsListPanelState();
}

class _BetsListPanelState extends State<BetsListPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final e = widget.engine;
        final List<Widget> rows;
        switch (_tab) {
          case 0:
            rows = _liveRows(e);
            break;
          case 1:
            rows = _betRows(e.previousBets,
                empty: 'No bets in the previous round.');
            break;
          default:
            rows = _myRows(e);
        }
        final header = Column(
          children: [
            _tabs(),
            const SizedBox(height: 10),
            _summary(e),
            const SizedBox(height: 6),
            _columnHeader(),
          ],
        );

        Widget body;
        if (widget.expand) {
          body = Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i],
            ),
          );
        } else {
          body = Column(children: rows.take(40).toList());
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [header, body, _footer()],
          ),
        );
      },
    );
  }

  Widget _footer() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 12, color: AppColors.green),
          SizedBox(width: 4),
          Text('Provably Fair Game',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int idx, String label) {
      final selected = _tab == idx;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = idx),
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

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        tab(0, 'All Bets'),
        tab(1, 'Previous'),
        tab(2, 'My Bets'),
      ]),
    );
  }

  Widget _summary(GameClient e) {
    if (_tab == 1) {
      final bets = e.previousBets;
      final cashed = bets.where((b) => b.isCashedOut).length;
      final wagered = bets.fold(0.0, (s, b) => s + b.amount);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              e.previousBetsRound > 0
                  ? 'ROUND #${e.previousBetsRound}'
                  : 'PREVIOUS ROUND',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          Text('${bets.length} bets · $cashed cashed out · ${pkr(wagered)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
    }
    if (_tab == 2) {
      final won = e.myBets.where((b) => b.won).length;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('MY BETS',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          Text('${e.myBets.length} bets · $won won',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
    }
    final showingPrevious = e.liveBets.isEmpty && e.previousBets.isNotEmpty;
    final bets = showingPrevious ? e.previousBets : e.liveBets;
    final cashed = bets.where((b) => b.isCashedOut).length;
    final wagered = bets.fold(0.0, (s, b) => s + b.amount);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(showingPrevious ? 'LAST ROUND' : 'ALL BETS',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            Text('${bets.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$cashed/${bets.length} cashed out',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(pkr(wagered),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _columnHeader() {
    const style = TextStyle(color: Colors.white38, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
              flex: 3, child: Text(_tab == 2 ? 'Time' : 'Player', style: style)),
          const Expanded(flex: 2, child: Text('Bet PKR', style: style)),
          const Expanded(
              flex: 2, child: Text('X', style: style, textAlign: TextAlign.center)),
          const Expanded(
              flex: 3,
              child: Text('Win PKR', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  List<Widget> _liveRows(GameClient e) {
    final bets = e.liveBets.isEmpty ? e.previousBets : e.liveBets;
    return _betRows(bets, empty: 'No bets in this round yet.');
  }

  List<Widget> _betRows(List<LiveBet> bets, {required String empty}) {
    if (bets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(empty,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ];
    }
    return bets.map((b) {
      final cashed = b.cashedOutAt != null;
      return _row(
        key: ValueKey(b.key),
        highlight: cashed,
        lost: b.isLost,
        mine: b.isMe,
        leading: Row(
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: b.isMe ? AppColors.red : _avatarColor(b.uid),
              child: Text(
                  b.player.isEmpty ? '?' : b.player[0].toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(b.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: b.isMe ? Colors.white : Colors.white70,
                      fontWeight: b.isMe ? FontWeight.bold : FontWeight.normal)),
            ),
          ],
        ),
        amount: b.amount,
        multiplier: b.cashedOutAt,
        payout: b.payout,
        lostAmount: b.isLost ? b.amount : null,
      );
    }).toList();
  }

  Color _avatarColor(String uid) {
    const palette = [
      Color(0xFF3E5C76),
      Color(0xFF5B4B8A),
      Color(0xFF2E7D6B),
      Color(0xFF8A5B3C),
      Color(0xFF6B3E5C),
    ];
    var h = 0;
    for (final c in uid.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  List<Widget> _myRows(GameClient e) {
    if (e.myBets.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(20),
          child: Text('No bets yet — place a bet to get started.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ];
    }
    return e.myBets.map((b) {
      final t = b.time;
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      final ss = t.second.toString().padLeft(2, '0');
      return _row(
        highlight: b.won,
        lost: !b.won,
        leading: Text('$hh:$mm:$ss',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        amount: b.amount,
        multiplier: b.cashedOutAt,
        payout: b.payout,
        lostAmount: b.won ? null : b.amount,
      );
    }).toList();
  }

  Widget _row({
    Key? key,
    required Widget leading,
    required double amount,
    double? multiplier,
    double? payout,
    double? lostAmount,
    bool highlight = false,
    bool mine = false,
    bool lost = false,
  }) {
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 250),
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF123405)
            : (lost ? const Color(0xFF2A1416) : AppColors.panelAlt),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: AppColors.green.withValues(alpha: 0.5))
            : (mine
                ? Border.all(color: AppColors.red.withValues(alpha: 0.5))
                : null),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: leading),
          Expanded(
            flex: 2,
            child: Text(money(amount),
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: multiplier == null
                  ? const Text('-',
                      style: TextStyle(color: Colors.white38, fontSize: 12))
                  : _multiplierChip(multiplier),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              payout != null
                  ? money(payout)
                  : (lostAmount != null ? '-${money(lostAmount)}' : '-'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: payout != null
                    ? Colors.white
                    : (lost ? AppColors.red : Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiplierChip(double m) {
    final color = AppColors.forMultiplier(m);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(multiplierText(m),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
