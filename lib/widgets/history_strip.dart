import 'package:flutter/material.dart';

import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';
import 'dialogs.dart';

class HistoryStrip extends StatefulWidget {
  const HistoryStrip({super.key, required this.engine});

  final GameClient engine;

  @override
  State<HistoryStrip> createState() => _HistoryStripState();
}

class _HistoryStripState extends State<HistoryStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final history = widget.engine.history;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: history.isEmpty
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Round history will appear here',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, i) => _chip(history[i]),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    tooltip: 'Round history',
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.history,
                      color: Colors.white70,
                    ),
                    onPressed: history.isEmpty
                        ? null
                        : () => setState(() => _expanded = !_expanded),
                  ),
                ),
              ],
            ),
            if (_expanded && history.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROUND HISTORY',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: history.map(_chip).toList(),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(RoundResult r) {
    final color = AppColors.forMultiplier(r.crashPoint);
    return GestureDetector(
      onTap: () => showRoundDetails(context, r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          multiplierText(r.crashPoint),
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
