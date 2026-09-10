import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../flight_path_painter.dart';
import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';

class FlightArea extends StatelessWidget {
  const FlightArea({super.key, required this.engine, required this.clock});

  final GameClient engine;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([engine, clock]),
      builder: (context, _) {
        final e = engine;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: FlightScenePainter(
                      phase: e.phase,
                      flightSeconds: e.flightSeconds,
                      crashedSeconds: e.crashedSeconds,
                      time: clock.value,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 48, 16, 36),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _overlay(e),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: _cashOutToasts(e),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const _multiplierStyle = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  Widget _multiplier(double value, Color color) {
    return Text(
      multiplierText(value),
      style: _multiplierStyle.copyWith(
        color: color,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16),
          Shadow(color: color.withValues(alpha: 0.35), blurRadius: 32),
        ],
      ),
    );
  }

  Widget _caption(String text, {Color color = Colors.white70}) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
    );
  }

  Widget _overlay(GameClient e) {
    if (!e.hasRound) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          _caption(
            e.connected ? 'CONNECTING TO GAME' : 'RECONNECTING',
            color: Colors.white70,
          ),
        ],
      );
    }
    switch (e.phase) {
      case RoundPhase.betting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: clock.value * 6,
              child: Icon(Icons.toys_outlined,
                  size: 52, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 14),
            _caption('WAITING FOR NEXT ROUND', color: Colors.white),
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.bettingProgress,
                  minHeight: 5,
                  color: AppColors.red,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ],
        );
      case RoundPhase.flying:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _caption('CURRENT ROUND', color: Colors.white54),
            const SizedBox(height: 6),
            _multiplier(e.currentMultiplier, Colors.white),
          ],
        );
      case RoundPhase.crashed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _caption('FLEW AWAY!', color: Colors.white),
            const SizedBox(height: 6),
            _multiplier(e.currentMultiplier, AppColors.red),
          ],
        );
    }
  }

  Widget _cashOutToasts(GameClient e) {
    if (e.phase == RoundPhase.betting) return const SizedBox.shrink();
    final cashed = e.slots.where((s) => s.isPlaced && s.isCashedOut).toList();
    if (cashed.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: cashed.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF123405),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.green),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('You have cashed out!',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 10),
                  Text(multiplierText(s.cashedOutAt!),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Win ${pkr(s.payout!)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
