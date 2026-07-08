import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/player_profile/personalize_screen.dart';
import '../features/spike/spike_session_screen.dart';

class TurnosApp extends ConsumerWidget {
  const TurnosApp({super.key});

  static final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
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
        path: '/spike',
        builder: (context, state) {
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
