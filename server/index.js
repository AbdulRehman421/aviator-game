require('dotenv').config();

const crypto = require('crypto');
const admin = require('firebase-admin');

// ------------------------------------------------------------------ config

const CURRENCY = 'PKR';
const MIN_BET = 16;
const MAX_BET = 300000;
const GROWTH_RATE = 0.1;
const HOUSE_EDGE_DIVISOR = 33;
const BETTING_SECONDS = parseInt(process.env.BETTING_SECONDS || '5', 10);
const CRASH_PAUSE_SECONDS = parseInt(process.env.CRASH_PAUSE_SECONDS || '3', 10);
const SIGNUP_BONUS = parseFloat(process.env.SIGNUP_BONUS || '0');

const E52 = 4503599627370496n;

// ------------------------------------------------------------------ helpers

// Offset between this machine's clock and Firebase's; all published
// timestamps use Firebase time so clients can rely on .info/serverTimeOffset.
let clockOffset = 0;
const now = () => Date.now() + clockOffset;
const round2 = (v) => Math.round(v * 100) / 100;

const multiplierAt = (seconds) => Math.exp(GROWTH_RATE * seconds);
const secondsToReach = (multiplier) => Math.log(Math.max(1, multiplier)) / GROWTH_RATE;

const randomHex = (bytes) =>
  Array.from({ length: bytes }, () =>
    Math.floor(Math.random() * 256)
      .toString(16)
      .padStart(2, '0')
  ).join('');

const sha256 = (s) =>
  crypto.createHash('sha256').update(s, 'utf8').digest('hex');
const sha512 = (s) =>
  crypto.createHash('sha512').update(s, 'utf8').digest('hex');

const crashPointFromHash = (hash) => {
  const h = BigInt(parseInt(hash.slice(0, 13), 16));
  if (h % BigInt(HOUSE_EDGE_DIVISOR) === 0n) return 1.0;
  const result =
    Number((100n * E52 - h) / (E52 - h)) / 100 +
    Number((100n * E52 - h) % (E52 - h)) / Number(E52 - h) / 100;
  const floored = Math.floor(result * 100) / 100;
  return Math.max(1.0, floored);
};

const crashPointFromSeeds = (serverSeed, clientSeeds) =>
  crashPointFromHash(sha512(serverSeed + clientSeeds.join('')));

// ------------------------------------------------------------------ firebase

// Initialize Firebase Admin with environment variables
let app;
if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
  // For production - use base64-encoded JSON
  const serviceAccountJson = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
  const serviceAccount = JSON.parse(serviceAccountJson);
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://aviator-91a24-default-rtdb.firebaseio.com',
  });
} else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // For production (Render, etc.) - use JSON from environment variable
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://aviator-91a24-default-rtdb.firebaseio.com',
  });
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  // For local development - use file path
  app = admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS),
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://aviator-91a24-default-rtdb.firebaseio.com',
  });
} else {
  // Fallback - use application default credentials
  app = admin.initializeApp({
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://aviator-91a24-default-rtdb.firebaseio.com',
  });
}

const db = admin.database(app);
db.ref('.info/serverTimeOffset').on('value', (snap) => {
  clockOffset = snap.val() || 0;
});

// ------------------------------------------------------------------ wallet

// Credits/debits the balance and writes a ledger entry.
async function walletTx(uid, type, amount, roundId) {
  const at = now();
  const txRef = db.ref(`users/${uid}/transactions`).push();
  const updates = {};
  updates[`users/${uid}/wallet/balance`] = admin.database.ServerValue.increment(
    round2(amount)
  );
  updates[`users/${uid}/wallet/updatedAt`] = at;
  updates[`users/${uid}/transactions/${txRef.key}`] = {
    type,
    amount: round2(amount),
    at,
    roundId: roundId ?? null,
  };
  await db.ref().update(updates);
}

// Writes a ledger entry only (balance already changed elsewhere).
async function logTx(uid, type, amount, roundId) {
  await db.ref(`users/${uid}/transactions`).push().set({
    type,
    amount: round2(amount),
    at: now(),
    roundId: roundId ?? null,
  });
}

async function signupBonus(uid) {
  if (SIGNUP_BONUS <= 0) return;
  const snap = await db.ref(`users/${uid}/wallet`).get();
  if (snap.exists()) return;
  const at = now();
  await db.ref(`users/${uid}/wallet`).set({
    balance: round2(SIGNUP_BONUS),
    currency: CURRENCY,
    createdAt: at,
    updatedAt: at,
  });
  await db.ref(`users/${uid}/transactions`).push().set({
    type: 'signup_bonus',
    amount: round2(SIGNUP_BONUS),
    at,
  });
}

// ------------------------------------------------------------------ game loop

class GameLoop {
  constructor() {
    this.roundId = 0;
    this.phase = 'betting';
    this.crashPoint = 1.0;
    this.crashSeconds = 0;
    this.bettingStartAt = 0;
    this.flightStartAt = 0;
    this.bets = new Map();
    this.timers = [];
    this.processing = new Set();
    this.betsRef = null;
    this.betsListener = null;
    this.betsChangedListener = null;
    this.secret = null;
  }

  async start() {
    // Recover from an interrupted round.
    const current = await db.ref('game/current').get();
    if (current.exists()) {
      const data = current.val();
      // Continue numbering from the last published round.
      this.roundId = Math.max(this.roundId, Number(data?.roundId) || 0);
      if (data && (data.phase === 'flying' || data.phase === 'betting')) {
        console.log('Recovering interrupted round', data.roundId);
        await this._refundRound(data.roundId);
      } else if (data && data.phase === 'crashed' && data.crashedAt) {
        const elapsed = (now() - data.crashedAt) / 1000;
        if (elapsed < CRASH_PAUSE_SECONDS) {
          const wait = (CRASH_PAUSE_SECONDS - elapsed) * 1000;
          this._setTimer(() => this._startBettingPhase(), wait);
          return;
        }
      }
    }
    this._startBettingPhase();
  }

  async _startBettingPhase() {
    this._clearTimers();
    this._detachBetListeners();
    this.roundId += 1;
    this.phase = 'betting';
    this.bets.clear();
    this.processing.clear();

    // Never start a round on top of stale data from a previous run.
    await db.ref(`rounds/${this.roundId}`).remove();

    const serverSeed = randomHex(16);
    const serverSeedHash = sha256(serverSeed);
    const clientSeeds = Array.from({ length: 3 }, () => randomHex(8));
    const combinedHash = sha512(serverSeed + clientSeeds.join(''));
    const crashPoint = crashPointFromHash(combinedHash);

    const crashSeconds = secondsToReach(crashPoint);
    const bettingStartAt = now();
    const bettingEndsAt = bettingStartAt + BETTING_SECONDS * 1000;

    // Only the commitment (hash) is public until the round ends.
    const round = {
      roundId: this.roundId,
      phase: 'betting',
      serverSeedHash,
      clientSeeds,
      bettingStartAt,
      bettingEndsAt,
      flightStartAt: null,
      crashedAt: null,
      crashPoint: null,
    };
    this.secret = { serverSeed, combinedHash, crashPoint: round2(crashPoint) };

    await db.ref('game/current').set(round);
    this.bettingStartAt = bettingStartAt;
    this.crashPoint = this.secret.crashPoint;
    this.crashSeconds = crashSeconds;

    // Attach bet listeners for this round. child_changed fires whenever any
    // field of a bet changes (e.g. the client adds cashOutRequested).
    this.betsRef = db.ref(`rounds/${this.roundId}/bets`);
    this.betsListener = this.betsRef.on('child_added', (snap) =>
      this._onBetAdded(this.roundId, snap.key, snap.val())
    );
    this.betsChangedListener = this.betsRef.on('child_changed', (snap) => {
      const v = snap.val() || {};
      console.log(
        `[bet-changed] ${snap.key} phase=${this.phase} known=${this.bets.has(snap.key)} ` +
          `cashOutReq=${!!v.cashOutRequested} cancelReq=${!!v.cancelRequested} cashedOutAt=${v.cashedOutAt ?? '-'}`
      );
      return this._onBetUpdated(snap.key, snap.val());
    });

    this._setTimer(() => this._startFlightPhase(), BETTING_SECONDS * 1000);
    console.log(`Round ${this.roundId} started. Crash at ${round2(crashPoint)}x`);
  }

  _startFlightPhase() {
    this.phase = 'flying';
    this.flightStartAt = now();
    db.ref('game/current').update({
      phase: 'flying',
      flightStartAt: this.flightStartAt,
    });

    // Schedule auto cashouts and the crash.
    for (const [key, bet] of this.bets.entries()) {
      if (bet.status !== 'placed' || !bet.autoCashOutAt) continue;
      if (bet.autoCashOutAt < this.crashPoint) {
        const delay = secondsToReach(bet.autoCashOutAt) * 1000;
        this._setTimer(() => this._autoCashOut(key), Math.max(0, delay));
      }
    }

    const crashDelay = this.crashSeconds * 1000;
    this._setTimer(() => this._crash(), Math.max(0, crashDelay));
  }

  async _crash() {
    this.phase = 'crashed';
    const crashedAt = now();
    await db.ref('game/current').update({
      phase: 'crashed',
      crashedAt,
      crashPoint: this.crashPoint,
    });

    this._detachBetListeners();

    // Settle remaining bets as lost and record history.
    const history = await db.ref(`rounds/${this.roundId}/bets`).get();
    const betValues = history.val() || {};
    let totalBets = 0;
    let totalWagered = 0;

    const updates = {};
    for (const [key, bet] of Object.entries(betValues)) {
      if (bet.status !== 'placed' && bet.status !== 'pending') continue;
      totalBets += 1;
      totalWagered += bet.amount;
      if (bet.status === 'placed' && !bet.cashedOutAt) {
        // Lost.
        updates[`rounds/${this.roundId}/bets/${key}/status`] = 'lost';
        await this._recordMyBet(bet.uid, this.roundId, bet.amount, null, null);
      } else if (bet.status === 'pending') {
        updates[`rounds/${this.roundId}/bets/${key}/status`] = 'rejected';
        updates[`rounds/${this.roundId}/bets/${key}/reason`] =
          'Round started before bet was accepted';
      }
    }

    const currentSnap = await db.ref('game/current').get();
    const roundData = currentSnap.val();
    if (roundData) {
      updates[`game/history/${this.roundId}`] = {
        ...roundData,
        ...(this.secret || {}),
        totalBets,
        totalWagered: round2(totalWagered),
        endedAt: crashedAt,
      };
    }

    // Prune old bet data.
    if (this.roundId > 50) {
      updates[`rounds/${this.roundId - 50}`] = null;
    }
    await db.ref().update(updates);

    this._setTimer(() => this._startBettingPhase(), CRASH_PAUSE_SECONDS * 1000);
  }

  // ---------------------------------------------------------------- bet handling

  async _onBetAdded(round, key, bet) {
    if (round !== this.roundId) return;
    if (this.processing.has(key)) return;
    this.processing.add(key);
    try {
      await this._handleBet(round, key, bet);
    } finally {
      this.processing.delete(key);
    }
  }

  async _handleBet(round, key, bet) {
    if (!bet || bet.status !== 'pending') return;

    // Validate ownership and amount.
    const parts = (key || '').split('_');
    if (parts.length !== 2 || parts[0] !== bet.uid) {
      await this._reject(key, 'Invalid bet key');
      return;
    }

    if (this.phase !== 'betting') {
      await this._reject(key, 'Betting closed');
      return;
    }

    const amount = round2(bet.amount);
    if (
      !Number.isFinite(amount) ||
      amount < MIN_BET ||
      amount > MAX_BET ||
      (amount * 100) % 1 !== 0
    ) {
      await this._reject(key, `Bet must be between ${MIN_BET} and ${MAX_BET} ${CURRENCY}`);
      return;
    }

    const walletSnap = await db.ref(`users/${bet.uid}/wallet/balance`).get();
    const balance = (walletSnap.val() || 0);
    if (balance < amount) {
      await this._reject(key, 'Insufficient balance');
      return;
    }

    // Debit wallet atomically.
    let committed = false;
    try {
      const result = await db
        .ref(`users/${bet.uid}/wallet/balance`)
        .transaction((current) => {
          const cur = current || 0;
          if (cur < amount) return undefined; // abort
          return round2(cur - amount);
        });
      committed = result.committed;
    } catch (e) {
      committed = false;
    }
    if (!committed) {
      await this._reject(key, 'Insufficient balance');
      return;
    }

    await logTx(bet.uid, 'bet', -amount, this.roundId);

    const placedAt = now();
    const updates = {
      [`rounds/${round}/bets/${key}/status`]: 'placed',
      [`rounds/${round}/bets/${key}/amount`]: amount,
      [`rounds/${round}/bets/${key}/placedAt`]: placedAt,
    };
    if (bet.autoCashOutAt) {
      updates[`rounds/${round}/bets/${key}/autoCashOutAt`] = round2(bet.autoCashOutAt);
    }
    await db.ref().update(updates);

    this.bets.set(key, {
      ...bet,
      status: 'placed',
      amount,
      placedAt,
      roundId: this.roundId,
    });
    console.log(`[bet-placed] ${key} ${amount} ${CURRENCY} round=${round}`);

    // The client may have written a request while we were placing the bet.
    const latest = (await db.ref(`rounds/${round}/bets/${key}`).get()).val();
    if (latest) await this._onBetUpdated(key, latest);
  }

  _detachBetListeners() {
    if (!this.betsRef) return;
    if (this.betsListener) this.betsRef.off('child_added', this.betsListener);
    if (this.betsChangedListener) {
      this.betsRef.off('child_changed', this.betsChangedListener);
    }
    this.betsListener = null;
    this.betsChangedListener = null;
  }

  async _onBetUpdated(key, data) {
    if (!data) return;
    if (!this.bets.has(key)) {
      // Only the server writes status=placed, so a placed bet in the DB is
      // trustworthy even if we lost our in-memory copy (e.g. restart).
      if (data.status !== 'placed' || !data.uid) return;
      if (!data.placedAt || data.placedAt < this.bettingStartAt) return;
      this.bets.set(key, { ...data, roundId: this.roundId });
      console.log(`[bet-adopted] ${key}`);
    }
    const bet = this.bets.get(key);
    if (bet.cashedOutAt || data.cashedOutAt) return;

    if (data.cashOutRequested && !bet.cashOutHandled) {
      if (this.phase === 'flying') {
        bet.cashOutHandled = true;
        await this._settleCashOut(key);
      } else if (this.phase === 'crashed') {
        bet.cashOutHandled = true;
        await this._rejectCashOut(key, 'Round already crashed');
      }
      // During betting: ignore, the client can't cash out yet.
    } else if (data.cancelRequested && !bet.cancelHandled) {
      bet.cancelHandled = true;
      if (this.phase === 'betting') {
        await this._cancelBet(key);
      } else {
        await this._rejectCancel(key, 'Cannot cancel after betting closed');
      }
    }
  }

  async _settleCashOut(key) {
    if (!this.bets.has(key)) return;
    const bet = this.bets.get(key);
    if (bet.cashedOutAt) return;

    let multiplier = round2(multiplierAt((now() - this.flightStartAt) / 1000));
    if (multiplier >= this.crashPoint) multiplier = this.crashPoint;

    const payout = round2(bet.amount * multiplier);
    bet.cashedOutAt = multiplier;
    bet.payout = payout;
    console.log(`[cash-out] ${key} at ${multiplier}x -> ${payout} ${CURRENCY}`);

    await walletTx(bet.uid, 'win', payout, this.roundId);
    await this._recordMyBet(bet.uid, this.roundId, bet.amount, multiplier, payout);

    await db.ref(`rounds/${this.roundId}/bets/${key}`).update({
      cashedOutAt: multiplier,
      payout,
    });
  }

  async _autoCashOut(key) {
    if (!this.bets.has(key)) return;
    const bet = this.bets.get(key);
    if (!bet || bet.cashedOutAt) return;
    const target = round2(bet.autoCashOutAt);
    if (target >= this.crashPoint) return;

    const payout = round2(bet.amount * target);
    bet.cashedOutAt = target;
    bet.payout = payout;

    await walletTx(bet.uid, 'win', payout, this.roundId);
    await this._recordMyBet(bet.uid, this.roundId, bet.amount, target, payout);

    await db.ref(`rounds/${this.roundId}/bets/${key}`).update({
      cashedOutAt: target,
      payout,
    });
  }

  async _cancelBet(key) {
    if (!this.bets.has(key)) return;
    const bet = this.bets.get(key);
    if (bet.cashedOutAt) return;

    await walletTx(bet.uid, 'refund', bet.amount, this.roundId);
    await db.ref(`rounds/${this.roundId}/bets/${key}`).remove();
    this.bets.delete(key);
  }

  async _reject(key, reason) {
    await db.ref(`rounds/${this.roundId}/bets/${key}`).update({
      status: 'rejected',
      reason,
    });
    this.bets.delete(key);
  }

  async _rejectCashOut(key, reason) {
    const snap = await db.ref(`rounds/${this.roundId}/bets/${key}`).get();
    const bet = snap.val();
    if (!bet || bet.cashedOutAt) return;
    await db.ref(`rounds/${this.roundId}/bets/${key}`).update({
      cashOutRejected: reason,
    });
  }

  async _rejectCancel(key, reason) {
    await db.ref(`rounds/${this.roundId}/bets/${key}`).update({
      cancelRejected: reason,
    });
  }

  async _recordMyBet(uid, roundId, amount, cashOutAt, payout) {
    const at = now();
    await db.ref(`users/${uid}/bets`).push().set({
      roundId,
      amount,
      cashedOutAt: cashOutAt ?? null,
      payout: payout ?? null,
      time: at,
    });
  }

  async _refundRound(round) {
    const snap = await db.ref(`rounds/${round}/bets`).get();
    const bets = snap.val() || {};
    for (const [key, bet] of Object.entries(bets)) {
      if (bet.status === 'placed' && !bet.cashedOutAt && bet.uid) {
        await walletTx(bet.uid, 'refund', bet.amount, round);
        console.log(`[refund] ${key} ${bet.amount} ${CURRENCY} (round ${round} interrupted)`);
      }
    }
    await db.ref(`rounds/${round}`).remove();
  }

  _setTimer(fn, delay) {
    const t = setTimeout(fn, delay);
    this.timers.push(t);
  }

  _clearTimers() {
    for (const t of this.timers) clearTimeout(t);
    this.timers = [];
  }
}

// ------------------------------------------------------------------ user lifecycle

async function watchNewUsers() {
  db.ref('users').on('child_added', async (snap) => {
    const uid = snap.key;
    if (!uid) return;
    await signupBonus(uid);
  });
}

async function watchDeposits() {
  db.ref('deposits').on('child_added', async (snap) => {
    const id = snap.key;
    const deposit = snap.val();
    if (!deposit || deposit.status !== 'pending') return;
    // In a real payment flow the provider would set status to 'approved'
    // when money is received. Then the server credits the wallet once.
    await db.ref(`deposits/${id}`).child('status').on('value', async (statusSnap) => {
      const status = statusSnap.val();
      if (status !== 'approved') return;
      const full = (await db.ref(`deposits/${id}`).get()).val() || {};
      if (full.credited) return;
      const amount = round2(full.amount || 0);
      if (amount <= 0) return;
      await db.ref(`deposits/${id}`).update({ credited: true });
      await walletTx(full.uid, 'deposit', amount, null);
    });
  });
}

// ------------------------------------------------------------------ recovery

// Only one game loop may run against a database. A second instance (another
// terminal, a cloud deployment, ...) would fight over game/current.
const INSTANCE_ID = randomHex(8);
const LOCK_TTL_MS = 15000;

async function acquireLock() {
  const ref = db.ref('game/server');
  const result = await ref.transaction((cur) => {
    if (cur && cur.instanceId !== INSTANCE_ID && now() - (cur.heartbeat || 0) < LOCK_TTL_MS) {
      return undefined; // another live instance holds it
    }
    return { instanceId: INSTANCE_ID, heartbeat: now(), startedAt: now() };
  });
  if (!result.committed) {
    const other = (await ref.get()).val() || {};
    throw new Error(
      `Another game server (${other.instanceId}) is already running against this database. ` +
        'Stop it first (check other terminals / cloud deployments).'
    );
  }
  setInterval(() => ref.update({ heartbeat: now() }), LOCK_TTL_MS / 3);
  ref.onDisconnect().remove();
}

async function main() {
  await acquireLock();
  console.log(`Game server ${INSTANCE_ID} started`);
  const game = new GameLoop();
  await watchNewUsers();
  await watchDeposits();
  await game.start();
  
  // Start HTTP server for health checks (required by Render)
  const http = require('http');
  const PORT = process.env.PORT || 10000;
  
  const server = http.createServer((req, res) => {
    if (req.url === '/health' || req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'ok',
        message: 'Aviator game server running',
        instanceId: INSTANCE_ID,
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      }));
    } else {
      res.writeHead(404);
      res.end('Not found');
    }
  });
  
  server.listen(PORT, () => {
    console.log(`HTTP server listening on port ${PORT}`);
  });
}

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
});

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
