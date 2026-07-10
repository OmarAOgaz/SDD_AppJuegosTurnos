import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/game/ended_screen.dart';
import '../features/game/game_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/player_profile/personalize_screen.dart';
import '../features/spike/spike_session_screen.dart';

import '../core/providers/network_providers.dart';

class TurnosApp extends ConsumerWidget {
  const TurnosApp({super.key});

  static final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return LobbyScreen(
            role: query['role'] ?? 'host',
            host: query['host'],
            port: int.tryParse(query['port'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/personalize',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return PersonalizeScreen(
            returnHost: query['returnHost'],
            returnPort: int.tryParse(query['returnPort'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return GameScreen(
            role: query['role'] ?? 'host',
            host: query['host'],
            port: int.tryParse(query['port'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/ended',
        builder: (context, state) => const EndedScreen(),
      ),
      GoRoute(
        path: '/spike',
        builder: (context, state) {
          if (!kDebugMode) {
            return const HomeScreen();
          }
          final query = state.uri.queryParameters;
          return SpikeSessionScreen(
            role: query['role'] ?? 'host',
            host: query['host'],
            port: int.tryParse(query['port'] ?? ''),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(deviceIdProvider);
    ref.watch(gameSocketClientProvider);
    return MaterialApp.router(
      title: 'Turnos Juegos de mesa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
