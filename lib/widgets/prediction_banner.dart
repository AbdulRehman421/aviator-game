import 'package:flutter/material.dart';

import '../game/game_client.dart';
import '../game/models.dart';
import '../theme.dart';

/// Top banner showing the server's predicted multiplier for the current
/// round, then whether the round actually reached it.
class PredictionBanner extends StatelessWidget {
  const PredictionBanner({super.key, required this.engine});

  final GameClient engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final prediction = engine.prediction;
        if (!engine.hasRound || prediction == null) {
          return const SizedBox.shrink();
        }

        final phase = engine.phase;
        final crashed = phase == RoundPhase.crashed;
        final crashPoint = crashed ? engine.currentMultiplier : null;
        final hit = crashed && crashPoint != null && crashPoint >= prediction;

        final color = crashed
            ? (hit ? AppColors.green : AppColors.red)
            : AppColors.forMultiplier(prediction);

        final withPrediction =
            engine.history.where((r) => r.prediction != null).toList();
        final hits = withPrediction.where((r) => r.predictionHit).length;
        final accuracy = withPrediction.isEmpty
            ? null
            : (hits * 100 / withPrediction.length).round();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(
                crashed
                    ? (hit ? Icons.check_circle : Icons.cancel)
                    : Icons.auto_graph,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      crashed
                          ? (hit ? 'PREDICTION HIT' : 'PREDICTION MISSED')
                          : 'ROUND #${engine.roundId} PREDICTION',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      crashed
                          ? 'Predicted ${multiplierText(prediction)} · '
                              'Flew to ${multiplierText(crashPoint!)}'
                          : phase == RoundPhase.flying
                              ? 'Cash out before ${multiplierText(prediction)}'
                              : 'Expected to reach ${multiplierText(prediction)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  multiplierText(prediction),
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (accuracy != null) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$accuracy%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'accuracy',
                      style: TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
