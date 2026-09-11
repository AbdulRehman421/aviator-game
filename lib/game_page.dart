import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game/game_client.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'widgets/bet_panel.dart';
import 'widgets/bets_list.dart';
import 'widgets/dialogs.dart';
import 'widgets/flight_area.dart';
import 'widgets/history_strip.dart';
import 'widgets/prediction_banner.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.user, required this.auth});

  final User user;
  final AuthService auth;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final GameClient engine;
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  StreamSubscription<String>? _messages;

  @override
  void initState() {
    super.initState();
    engine = GameClient(
      uid: widget.user.uid,
      displayName: widget.user.displayName?.trim().isNotEmpty == true
          ? widget.user.displayName!.trim()
          : (widget.user.email?.split('@').first ?? 'Player'),
    );
    _messages = engine.messages.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    });
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1e6;
    })
      ..start();
  }

  @override
  void dispose() {
    _messages?.cancel();
    _ticker.dispose();
    _clock.dispose();
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ConnectionBar(engine: engine),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  return wide ? _wideLayout() : _narrowLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => _Header(engine: engine, user: widget.user, auth: widget.auth);

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 360,
            child: BetsListPanel(engine: engine, expand: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 8),
                PredictionBanner(engine: engine),
                const SizedBox(height: 8),
                HistoryStrip(engine: engine),
                const SizedBox(height: 8),
                Expanded(child: FlightArea(engine: engine, clock: _clock)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BetPanel(engine: engine, index: 0)),
                    const SizedBox(width: 8),
                    Expanded(child: BetPanel(engine: engine, index: 1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _header(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: PredictionBanner(engine: engine),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: HistoryStrip(engine: engine),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: LayoutBuilder(
                builder: (context, c) {
                  final height = (c.maxWidth * 0.56).clamp(180.0, 320.0);
                  return SizedBox(
                    height: height,
                    child: FlightArea(engine: engine, clock: _clock),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  BetPanel(engine: engine, index: 0),
                  const SizedBox(height: 8),
                  BetPanel(engine: engine, index: 1),
                  const SizedBox(height: 8),
                  BetsListPanel(engine: engine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.engine});

  final GameClient engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        if (engine.connected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.orange.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Text(
            'Reconnecting…',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.engine,
    required this.user,
    required this.auth,
  });

  final GameClient engine;
  final User user;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        return Row(
          children: [
            const Text(
              'Aviator',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: TextButton.icon(
                onPressed: () => showHowToPlay(context),
                icon: const Icon(Icons.help_outline, size: 14),
                label: const Text('How to play?',
                    overflow: TextOverflow.ellipsis),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  backgroundColor: AppColors.panel,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 28),
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => showWallet(context, engine),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    pkr(engine.balance),
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Wallet',
              iconSize: 20,
              icon: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70),
              onPressed: () => showWallet(context, engine),
            ),
            IconButton(
              tooltip: 'Provably fair',
              iconSize: 20,
              icon: const Icon(Icons.verified_user_outlined,
                  color: Colors.white70),
              onPressed: () => showProvablyFair(context, engine),
            ),
            PopupMenuButton<String>(
              tooltip: engine.displayName,
              color: AppColors.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              onSelected: (v) {
                if (v == 'logout') auth.signOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(engine.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(user.email ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 16, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Log out'),
                    ],
                  ),
                ),
              ],
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.red,
                child: Text(
                  engine.displayName.isEmpty
                      ? '?'
                      : engine.displayName[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
