import 'package:aviator_demo/game/fair.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameRules', () {
    test('constants match requirements', () {
      expect(GameRules.currency, 'PKR');
      expect(GameRules.minBet, 16.0);
      expect(GameRules.maxBet, 300000.0);
    });

    test('multiplierAt 0 seconds is 1.0', () {
      expect(multiplierAt(0.0), closeTo(1.0, 1e-12));
    });

    test('multiplierAt ~6.93 seconds is 2.0', () {
      final s = secondsToReach(2.0);
      expect(multiplierAt(s), closeTo(2.0, 1e-9));
    });

    test('secondsToReach is inverse of multiplierAt', () {
      const target = 5.0;
      final s = secondsToReach(target);
      expect(multiplierAt(s), closeTo(target, 1e-9));
    });
  });

  group('crashPointFromHash', () {
    test('divisible hash returns 1.00x', () {
      // Any 13-hex prefix that is a multiple of 33.
      const hash = '0000000000000000000000000000000000000000000000000000000000000000';
      expect(crashPointFromHash(hash), 1.00);
    });

    test('non-divisible hash returns a multiplier >= 1.0', () {
      const hash = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      final cp = crashPointFromHash(hash);
      expect(cp, greaterThanOrEqualTo(1.0));
    });

    test('sha helpers produce hex strings', () {
      const input = 'server seed';
      final s256 = sha256Hex(input);
      final s512 = sha512Hex(input);
      expect(s256, hasLength(64));
      expect(s512, hasLength(128));
    });
  });
}
