import 'package:aviator_demo/game/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('asMap', () {
    test('normalises Firebase array coercion of integer keys', () {
      final m = asMap([null, {'roundId': 1}, {'roundId': 2}]);
      expect(m.keys, ['1', '2']);
      expect(m['2'], {'roundId': 2});
    });

    test('passes maps through with string keys', () {
      expect(asMap({1: 'a'}), {'1': 'a'});
      expect(asMap(null), isEmpty);
    });
  });

  group('RoundResult', () {
    test('parses server round map', () {
      final m = {
        'roundId': 42,
        'crashPoint': 3.45,
        'serverSeed': 'abc',
        'serverSeedHash': 'def',
        'clientSeeds': ['a', 'b', 'c'],
        'combinedHash': 'ghi',
        'endedAt': 1234567890,
        'totalBets': 10,
        'totalWagered': 500.0,
      };
      final r = RoundResult.fromMap(m);
      expect(r.roundId, 42);
      expect(r.crashPoint, 3.45);
      expect(r.clientSeeds, ['a', 'b', 'c']);
      expect(r.totalBets, 10);
      expect(r.totalWagered, 500.0);
    });
  });

  group('LiveBet', () {
    test('displays You for current user and masks others', () {
      final me = LiveBet.fromMap('uid_0', {
        'uid': 'uid',
        'name': 'Ahmed',
        'amount': 100.0,
        'status': 'placed',
      }, 'uid');
      final other = LiveBet.fromMap('x_0', {
        'uid': 'x',
        'name': 'Ahmed',
        'amount': 100.0,
        'status': 'placed',
      }, 'uid');
      expect(me.displayName, 'You');
      expect(other.displayName, 'A***d');
    });

    test('tracks placed status and cashout', () {
      final b = LiveBet.fromMap('uid_0', {
        'uid': 'uid',
        'name': 'Player',
        'amount': 100.0,
        'status': 'placed',
        'cashedOutAt': 2.5,
        'payout': 250.0,
      }, 'uid');
      expect(b.isPlaced, true);
      expect(b.isCashedOut, true);
      expect(b.payout, 250.0);
    });
  });

  group('WalletTx', () {
    test('parses transaction map', () {
      final m = {
        'type': 'win',
        'amount': 250.0,
        'at': 1234567890,
        'roundId': 42,
      };
      final t = WalletTx.fromMap(m);
      expect(t.type, 'win');
      expect(t.amount, 250.0);
      expect(t.roundId, 42);
    });
  });

  group('BetSlot', () {
    test('clamping and reset work', () {
      final s = BetSlot();
      s.amount = 500000.0;
      expect(s.amount, 500000.0); // local until client clamps
      s.resetRound();
      expect(s.bet, isNull);
      expect(s.pending, false);
      expect(s.queued, false);
    });
  });
}
