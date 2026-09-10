import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Game constants shared by the client and mirrored by the server.
/// Changing any of these requires the same change in `server/index.js`.
class GameRules {
  static const currency = 'PKR';
  static const minBet = 16.0;
  static const maxBet = 300000.0;

  /// Multiplier = e^(growthRate · seconds). 0.1 reaches 2x at ~6.9s.
  static const growthRate = 0.1;

  /// One in every [houseEdgeDivisor] rounds crashes instantly at 1.00x.
  static const houseEdgeDivisor = 33;
}

const int _e52 = 4503599627370496; // 2^52

/// Standard crash-game formula: take the first 52 bits of the combined hash
/// as an integer `h`. The result is (100·2^52 − h) / (2^52 − h) / 100,
/// giving P(result ≥ x) ≈ 0.99 / x, plus an instant 1.00x every
/// [houseEdgeDivisor] rounds.
double crashPointFromHash(
  String hash, {
  int houseEdgeDivisor = GameRules.houseEdgeDivisor,
}) {
  final h = int.parse(hash.substring(0, 13), radix: 16);
  if (houseEdgeDivisor > 0 && h % houseEdgeDivisor == 0) return 1.00;
  final result = ((100.0 * _e52 - h) / (_e52 - h)).floorToDouble() / 100;
  return max(1.00, result);
}

double multiplierAt(double seconds) => exp(GameRules.growthRate * seconds);

double secondsToReach(double multiplier) =>
    log(max(1.0, multiplier)) / GameRules.growthRate;

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();
String sha512Hex(String input) => sha512.convert(utf8.encode(input)).toString();

double round2(double v) => (v * 100).roundToDouble() / 100;
