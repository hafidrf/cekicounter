import 'package:go_router/go_router.dart';

import 'ui/game_page.dart';
import 'ui/history_page.dart';
import 'ui/home_page.dart';
import 'ui/setup_page.dart';
import 'ui/standings_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/play', builder: (context, state) => const SetupPage()),
    GoRoute(path: '/game', builder: (context, state) => const GamePage()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryPage()),
    GoRoute(path: '/klasemen', builder: (context, state) => const StandingsPage()),
  ],
);
