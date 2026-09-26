import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/live/live_match_screen.dart';
import '../features/match_setup/match_setup_screen.dart';
import '../features/stats/match_stats_screen.dart';
import '../features/stats/player_stats_screen.dart';
import '../features/teams/squad_screen.dart';

class AppRoutes {
  static const home = '/';
  static const squad = '/squad';
  static const matchSetup = '/match/new';
  static const liveMatch = '/match/live';
  static const matchStats = '/match/stats';
  static const playerStats = '/players/stats';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _fade(const HomeScreen(), settings);
      case AppRoutes.squad:
        return _fade(const SquadScreen(), settings);
      case AppRoutes.matchSetup:
        return _fade(const MatchSetupScreen(), settings);
      case AppRoutes.liveMatch:
        final matchId = settings.arguments as String;
        return _fade(LiveMatchScreen(matchId: matchId), settings);
      case AppRoutes.matchStats:
        final matchId = settings.arguments as String;
        return _fade(MatchStatsScreen(matchId: matchId), settings);
      case AppRoutes.playerStats:
        final args = settings.arguments as PlayerStatsArgs?;
        return _fade(PlayerStatsScreen(args: args), settings);
      default:
        return _fade(const HomeScreen(), settings);
    }
  }

  static PageRouteBuilder _fade(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
