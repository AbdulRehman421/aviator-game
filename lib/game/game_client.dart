import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'fair.dart';
import 'models.dart';

/// Client-side view of the shared online game.
///
/// All authority lives on the game server (`server/index.js`): it generates
/// seeds, runs the round clock, debits/credits wallets and settles bets. This
/// class mirrors that state from Realtime Database, derives the live
/// multiplier from server-synchronised time, and sends bet requests.
///
/// Database layout:
///   game/current                      current round (phase + timestamps)
///   game/history/{roundId}            finished rounds (provably fair data)
///   rounds/{roundId}/bets/{uid}_{n}   bets for a round
///   users/{uid}/profile               display name, email
///   users/{uid}/wallet                balance (server-owned)
///   users/{uid}/bets                  personal bet history (server-owned)
///   users/{uid}/transactions          wallet ledger (server-owned)
///   deposits/{id}                     deposit requests (payment hook)
class GameClient extends ChangeNotifier {
  GameClient({
    required this.uid,
    required this.displayName,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance {
    _listen();
  }

  final String uid;
  final String displayName;
  final FirebaseDatabase _db;

  final List<StreamSubscription> _subs = [];
  StreamSubscription? _betsSub;
  int? _betsRound;
  Timer? _frame;

  // ------------------------------------------------------------ round state

  RoundPhase phase = RoundPhase.betting;
  int roundId = 0;
  String serverSeedHash = '';
  List<String> clientSeeds = const [];
  int? _bettingStartAt;
  int? _bettingEndsAt;
  int? _flightStartAt;
  int? _crashedAt;
  double? _crashPoint;

  /// Server-published predicted multiplier for the current round.
  double? prediction;

  int _serverOffsetMs = 0;
  bool connected = false;

  /// False until the server has published a round.
  bool get hasRound => roundId > 0;

  // ------------------------------------------------------------- user state

  double balance = 0;
  final List<BetSlot> slots = [BetSlot(amount: 100), BetSlot(amount: 200)];
  List<RoundResult> history = const [];
  List<LiveBet> liveBets = const [];

  /// Bets from the last finished round, kept until this round has its own.
  List<LiveBet> previousBets = const [];
  int previousBetsRound = 0;
  List<MyBet> myBets = const [];

  /// Fires ~20x/sec while a round is live. Widgets that render the running
  /// multiplier or countdown listen to this; everything else only needs
  /// [ChangeNotifier] updates.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);
  List<WalletTx> transactions = const [];

  final _messages = StreamController<String>.broadcast();

  /// Human-readable notices (rejected bets, errors) for the UI to surface.
  Stream<String> get messages => _messages.stream;

  // ---------------------------------------------------------------- timing

  int get serverNow => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  double get bettingSecondsLeft {
    final end = _bettingEndsAt;
    if (phase != RoundPhase.betting || end == null) return 0;
    return max(0, (end - serverNow) / 1000);
  }

  double get bettingProgress {
    final start = _bettingStartAt;
    final end = _bettingEndsAt;
    if (start == null || end == null || end <= start) return 0;
    return (bettingSecondsLeft / ((end - start) / 1000)).clamp(0.0, 1.0);
  }

  /// Seconds since take-off; frozen at the moment of the crash.
  double get flightSeconds {
    final start = _flightStartAt;
    if (start == null || phase == RoundPhase.betting) return 0;
    final end = _crashedAt ?? serverNow;
    return max(0, (end - start) / 1000);
  }

  double get crashedSeconds {
    final at = _crashedAt;
    if (phase != RoundPhase.crashed || at == null) return 0;
    return max(0, (serverNow - at) / 1000);
  }

  double get currentMultiplier {
    switch (phase) {
      case RoundPhase.betting:
        return 1.00;
      case RoundPhase.crashed:
        return _crashPoint ?? _floorMultiplier(flightSeconds);
      case RoundPhase.flying:
        return _floorMultiplier(flightSeconds);
    }
  }

  double _floorMultiplier(double seconds) =>
      (multiplierAt(seconds) * 100).floorToDouble() / 100;

  // ------------------------------------------------------------- live bets

  int get liveBetCount => liveBets.length;
  double get liveTotalWagered =>
      liveBets.fold(0.0, (sum, b) => sum + b.amount);
  int get liveCashedOutCount => liveBets.where((b) => b.isCashedOut).length;

  RoundResult? get lastRound => history.isEmpty ? null : history.first;

  // ------------------------------------------------------------- listeners

  void _listen() {
    _subs.add(_db.ref('.info/serverTimeOffset').onValue.listen((e) {
      _serverOffsetMs = asInt(e.snapshot.value) ?? 0;
    }));
    _subs.add(_db.ref('.info/connected').onValue.listen((e) {
      connected = e.snapshot.value == true;
      notifyListeners();
    }));
    _subs.add(_db.ref('game/current').onValue.listen(_onRound));
    _subs.add(_db
        .ref('game/history')
        .orderByKey()
        .limitToLast(30)
        .onValue
        .listen(_onHistory));
    _subs.add(_db.ref('users/$uid/wallet/balance').onValue.listen((e) {
      balance = asDouble(e.snapshot.value) ?? 0;
      notifyListeners();
    }));
    _subs.add(_db
        .ref('users/$uid/bets')
        .orderByChild('time')
        .limitToLast(100)
        .onValue
        .listen((e) {
      myBets = asMap(e.snapshot.value)
          .values
          .map((v) => MyBet.fromMap(asMap(v)))
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
      notifyListeners();
    }));
    _subs.add(_db
        .ref('users/$uid/transactions')
        .orderByChild('at')
        .limitToLast(50)
        .onValue
        .listen((e) {
      transactions = asMap(e.snapshot.value)
          .values
          .map((v) => WalletTx.fromMap(asMap(v)))
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
      notifyListeners();
    }));
  }

  void _onRound(DatabaseEvent e) {
    final m = asMap(e.snapshot.value);
    if (m.isEmpty) {
      roundId = 0;
      _stopFrame();
      notifyListeners();
      return;
    }

    final newRound = asInt(m['roundId']) ?? 0;
    final newPhase = phaseFromString(m['phase']?.toString());
    final roundChanged = newRound != roundId;
    final tookOff = newPhase == RoundPhase.flying && phase != RoundPhase.flying;

    roundId = newRound;
    phase = newPhase;
    serverSeedHash = m['serverSeedHash']?.toString() ?? '';
    final seeds = m['clientSeeds'];
    clientSeeds =
        seeds is List ? seeds.map((s) => s.toString()).toList() : const [];
    _bettingStartAt = asInt(m['bettingStartAt']);
    _bettingEndsAt = asInt(m['bettingEndsAt']);
    _flightStartAt = asInt(m['flightStartAt']);
    _crashedAt = asInt(m['crashedAt']);
    _crashPoint = asDouble(m['crashPoint']);
    prediction = asDouble(m['prediction']);

    if (tookOff) _resyncClock(_flightStartAt);

    if (roundChanged) {
      for (final s in slots) {
        s.resetRound();
      }
      if (liveBets.isNotEmpty) {
        previousBets = liveBets;
        previousBetsRound = _betsRound ?? 0;
      }
      liveBets = const [];
      _subscribeBets(roundId);
      if (phase == RoundPhase.betting) {
        for (var i = 0; i < slots.length; i++) {
          final s = slots[i];
          if (s.queued || s.autoBet) {
            s.queued = false;
            placeBet(i);
          }
        }
      }
    }

    if (phase == RoundPhase.betting || phase == RoundPhase.flying) {
      _startFrame();
    } else {
      _stopFrame();
    }
    notifyListeners();
  }

  /// The take-off event arrives within a few hundred ms of [flightStartAt].
  /// If our clock says the flight hasn't started yet, or started long ago,
  /// the offset is wrong (e.g. game server clock drift) - re-anchor to it.
  void _resyncClock(int? flightStartAt) {
    if (flightStartAt == null) return;
    final elapsed = serverNow - flightStartAt;
    if (elapsed < 0 || elapsed > 1500) {
      _serverOffsetMs = flightStartAt - DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _subscribeBets(int round) {
    if (_betsRound == round) return;
    _betsSub?.cancel();
    _betsRound = round;
    _betsSub = _db.ref('rounds/$round/bets').onValue.listen((e) {
      final all = asMap(e.snapshot.value)
          .entries
          .map((en) => LiveBet.fromMap(en.key, asMap(en.value), uid))
          .where((b) => b.isPlaced || b.isLost || b.isMe)
          .toList()
        ..sort((a, b) {
          if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
          if (a.isCashedOut != b.isCashedOut) return a.isCashedOut ? -1 : 1;
          return b.amount.compareTo(a.amount);
        });

      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        final mine = all.where((b) => b.key == '${uid}_$i').firstOrNull;
        if (mine == null) {
          if (s.bet != null && !s.bet!.isRejected) {
            // Bet removed (cancelled) or round data pruned.
            s.bet = null;
          }
          // Keep `pending` until the server acknowledges or the write fails.
        } else if (mine.isRejected) {
          if (s.bet?.status != 'rejected') {
            _messages.add(mine.rejectReason ?? 'Bet rejected');
          }
          s.bet = null;
          s.pending = false;
        } else {
          s.bet = mine;
          s.pending = false;
        }
      }

      liveBets = all.where((b) => b.isPlaced || b.isLost).toList();
      notifyListeners();
    });
  }

  void _onHistory(DatabaseEvent e) {
    history = asMap(e.snapshot.value)
        .values
        .map((v) => RoundResult.fromMap(asMap(v)))
        .toList()
      ..sort((a, b) => b.roundId.compareTo(a.roundId));
    notifyListeners();
  }

  void _startFrame() {
    _frame ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => frame.value++,
    );
  }

  void _stopFrame() {
    _frame?.cancel();
    _frame = null;
  }

  // -------------------------------------------------------- player actions

  DatabaseReference _betRef(int slotIndex) =>
      _db.ref('rounds/$roundId/bets/${uid}_$slotIndex');

  /// Places the slot's bet now (betting phase) or queues it for the next
  /// round. Returns false if the slot is busy or funds are short.
  bool placeBet(int slotIndex) {
    final s = slots[slotIndex];
    if (s.isBusy) return false;
    if (!hasRound) return false;

    if (phase != RoundPhase.betting) {
      s.queued = true;
      notifyListeners();
      return true;
    }

    final amt = round2(s.amount.clamp(GameRules.minBet, GameRules.maxBet));
    if (amt > balance) return false;

    s.pending = true;
    _betRef(slotIndex).set({
      'uid': uid,
      'name': displayName,
      'slot': slotIndex,
      'amount': amt,
      'status': 'pending',
      if (s.autoCashOut) 'autoCashOutAt': s.autoCashOutAt,
      'placedAt': ServerValue.timestamp,
    }).catchError((Object err) {
      s.pending = false;
      _messages.add('Could not place bet: $err');
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  /// Cancels a queued bet, or asks the server to refund a placed bet during
  /// the betting phase.
  void cancelBet(int slotIndex) {
    final s = slots[slotIndex];
    if (s.queued) {
      s.queued = false;
      notifyListeners();
      return;
    }
    final bet = s.bet;
    if (bet == null || !bet.isPlaced || phase != RoundPhase.betting) return;
    _betRef(slotIndex)
        .update({'cancelRequested': ServerValue.timestamp})
        .catchError((Object err) => _messages.add('Could not cancel: $err'));
  }

  /// Asks the server to cash out at the current multiplier. The payout is
  /// confirmed asynchronously via the bet node.
  void cashOut(int slotIndex) {
    final s = slots[slotIndex];
    final bet = s.bet;
    if (phase != RoundPhase.flying ||
        bet == null ||
        !bet.isPlaced ||
        bet.isCashedOut ||
        bet.cashOutRequested) {
      return;
    }
    _betRef(slotIndex)
        .update({'cashOutRequested': ServerValue.timestamp})
        .catchError((Object err) => _messages.add('Could not cash out: $err'));
  }

  void setAmount(int slotIndex, double amount) {
    slots[slotIndex].amount =
        round2(amount.clamp(GameRules.minBet, GameRules.maxBet));
    notifyListeners();
  }

  void setAutoBet(int slotIndex, bool enabled) {
    slots[slotIndex].autoBet = enabled;
    notifyListeners();
  }

  void setAutoCashOut(int slotIndex, bool enabled) {
    slots[slotIndex].autoCashOut = enabled;
    notifyListeners();
  }

  void setAutoCashOutAt(int slotIndex, double multiplier) {
    slots[slotIndex].autoCashOutAt = round2(max(1.01, multiplier));
    notifyListeners();
  }

  /// Records a deposit request. A payment provider (e.g. JazzCash/Easypaisa)
  /// or an admin marks it `approved`; the server then credits the wallet.
  /// Returns the deposit ID.
  Future<String> requestDeposit(double amount, {String method = 'manual'}) async {
    final depositRef = _db.ref('deposits').push();
    await depositRef.set({
      'uid': uid,
      'amount': round2(amount),
      'method': method,
      'status': 'pending',
      'at': ServerValue.timestamp,
    });
    return depositRef.key!;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _betsSub?.cancel();
    _stopFrame();
    frame.dispose();
    _messages.close();
    super.dispose();
  }
}
