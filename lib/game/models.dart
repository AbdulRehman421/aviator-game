/// Phase of the current round.
enum RoundPhase { betting, flying, crashed }

RoundPhase phaseFromString(String? s) {
  switch (s) {
    case 'flying':
      return RoundPhase.flying;
    case 'crashed':
      return RoundPhase.crashed;
    default:
      return RoundPhase.betting;
  }
}

/// Firebase returns nodes whose keys are sequential integers (e.g.
/// `game/history/1,2,3…`) as a List with nulls in the gaps; normalise both.
Map<String, dynamic> asMap(Object? v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  if (v is List) {
    return {
      for (var i = 0; i < v.length; i++)
        if (v[i] != null) '$i': v[i],
    };
  }
  return const {};
}

double? asDouble(Object? v) => v is num ? v.toDouble() : null;
int? asInt(Object? v) => v is num ? v.toInt() : null;

/// A finished round, including everything needed to verify it was fair.
class RoundResult {
  const RoundResult({
    required this.roundId,
    required this.crashPoint,
    required this.serverSeed,
    required this.serverSeedHash,
    required this.clientSeeds,
    required this.combinedHash,
    required this.endedAt,
    required this.totalBets,
    required this.totalWagered,
    this.prediction,
  });

  factory RoundResult.fromMap(Map<String, dynamic> m) {
    final seeds = m['clientSeeds'];
    return RoundResult(
      roundId: asInt(m['roundId']) ?? 0,
      crashPoint: asDouble(m['crashPoint']) ?? 1,
      serverSeed: m['serverSeed']?.toString() ?? '',
      serverSeedHash: m['serverSeedHash']?.toString() ?? '',
      clientSeeds: seeds is List
          ? seeds.map((e) => e.toString()).toList()
          : const [],
      combinedHash: m['combinedHash']?.toString() ?? '',
      endedAt: DateTime.fromMillisecondsSinceEpoch(asInt(m['endedAt']) ?? 0),
      totalBets: asInt(m['totalBets']) ?? 0,
      totalWagered: asDouble(m['totalWagered']) ?? 0,
      prediction: asDouble(m['prediction']),
    );
  }

  final int roundId;
  final double crashPoint;
  final String serverSeed;
  final String serverSeedHash;
  final List<String> clientSeeds;
  final String combinedHash;
  final DateTime endedAt;
  final int totalBets;
  final double totalWagered;
  final double? prediction;

  /// True when the round reached the predicted multiplier.
  bool get predictionHit =>
      prediction != null && crashPoint >= prediction!;
}

/// A bet in the current round as stored at `rounds/{roundId}/bets/{uid}_{slot}`.
class LiveBet {
  const LiveBet({
    required this.key,
    required this.uid,
    required this.player,
    required this.slot,
    required this.amount,
    required this.status,
    required this.isMe,
    this.cashedOutAt,
    this.payout,
    this.autoCashOutAt,
    this.cashOutRequested = false,
    this.cancelRequested = false,
    this.rejectReason,
  });

  factory LiveBet.fromMap(String key, Map<String, dynamic> m, String myUid) {
    final uid = m['uid']?.toString() ?? '';
    return LiveBet(
      key: key,
      uid: uid,
      player: m['name']?.toString() ?? 'Player',
      slot: asInt(m['slot']) ?? 0,
      amount: asDouble(m['amount']) ?? 0,
      status: m['status']?.toString() ?? 'pending',
      isMe: uid == myUid,
      cashedOutAt: asDouble(m['cashedOutAt']),
      payout: asDouble(m['payout']),
      autoCashOutAt: asDouble(m['autoCashOutAt']),
      cashOutRequested: m['cashOutRequested'] != null,
      cancelRequested: m['cancelRequested'] != null,
      rejectReason: m['reason']?.toString(),
    );
  }

  final String key;
  final String uid;
  final String player;
  final int slot;
  final double amount;
  final String status;
  final bool isMe;
  final double? cashedOutAt;
  final double? payout;
  final double? autoCashOutAt;
  final bool cashOutRequested;
  final bool cancelRequested;
  final String? rejectReason;

  bool get isPending => status == 'pending';
  bool get isPlaced => status == 'placed';
  bool get isRejected => status == 'rejected';
  bool get isLost => status == 'lost';
  bool get isCashedOut => cashedOutAt != null;

  /// Other players are shown masked, e.g. `a***n`.
  String get displayName {
    if (isMe) return 'You';
    if (player.length <= 2) return '$player***';
    return '${player[0]}***${player[player.length - 1]}';
  }
}

/// Entry in the player's personal bet history (`users/{uid}/bets`).
class MyBet {
  const MyBet({
    required this.roundId,
    required this.time,
    required this.amount,
    this.cashedOutAt,
    this.payout,
  });

  factory MyBet.fromMap(Map<String, dynamic> m) => MyBet(
        roundId: asInt(m['roundId']) ?? 0,
        time: DateTime.fromMillisecondsSinceEpoch(asInt(m['time']) ?? 0),
        amount: asDouble(m['amount']) ?? 0,
        cashedOutAt: asDouble(m['cashedOutAt']),
        payout: asDouble(m['payout']),
      );

  final int roundId;
  final DateTime time;
  final double amount;
  final double? cashedOutAt;
  final double? payout;

  bool get won => cashedOutAt != null;
}

/// Wallet ledger entry (`users/{uid}/transactions`).
class WalletTx {
  const WalletTx({
    required this.type,
    required this.amount,
    required this.time,
    this.roundId,
    this.method,
  });

  factory WalletTx.fromMap(Map<String, dynamic> m) => WalletTx(
        type: m['type']?.toString() ?? '',
        amount: asDouble(m['amount']) ?? 0,
        time: DateTime.fromMillisecondsSinceEpoch(asInt(m['at']) ?? 0),
        roundId: asInt(m['roundId']),
        method: m['method']?.toString(),
      );

  final String type;
  final double amount;
  final DateTime time;
  final int? roundId;
  final String? method;
}

/// One of the two independent bet panels the player controls. Local input
/// state plus a mirror of the server-side bet for the current round.
class BetSlot {
  BetSlot({this.amount = 100.0});

  double amount;
  bool autoBet = false;
  bool autoCashOut = false;
  double autoCashOutAt = 2.00;

  /// A bet requested while a round was in progress; placed automatically at
  /// the start of the next betting phase.
  bool queued = false;

  /// A bet write has been sent and the server has not acknowledged it yet.
  bool pending = false;

  LiveBet? bet;

  bool get isPlaced => bet != null && !bet!.isRejected;
  bool get isCashedOut => bet?.cashedOutAt != null;
  double? get placedAmount => bet?.amount;
  double? get cashedOutAt => bet?.cashedOutAt;
  double? get payout => bet?.payout;

  /// True when no new bet can be started from this slot.
  bool get isBusy => isPlaced || queued || pending;

  void resetRound() {
    bet = null;
    pending = false;
  }
}
