import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/my_claims_screen.dart';
import 'screens/claim_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/item_matches_screen.dart';
import 'screens/cctv_verification_screen.dart';
import 'screens/cctv_logs_screen.dart';

// Placeholder widget for missing routes
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Coming soon: $title')),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null || AuthState.isFakeAdmin;
    final isLoginRoute = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return AuthState.isFakeAdmin ? '/admin' : '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/report',
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/my-claims',
      builder: (context, state) => const MyClaimsScreen(),
    ),
    GoRoute(
      path: '/claims/:claimId/chat',
      builder: (context, state) {
        final claimId = state.pathParameters['claimId']!;
        return ClaimChatScreen(claimId: claimId);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/items/:itemId/matches',
      builder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        final extra = state.extra as Map<String, String>? ?? {};
        return ItemMatchesScreen(
          itemId: itemId,
          itemTitle: extra['title'] ?? 'Item',
          itemType: extra['type'] ?? 'lost',
        );
      },
    ),
    GoRoute(
      path: '/claims/:claimId/cctv',
      builder: (context, state) {
        final claimId = state.pathParameters['claimId']!;
        return CctvVerificationScreen(claimId: claimId);
      },
    ),
    GoRoute(
      path: '/cctv/logs',
      builder: (context, state) => const CctvLogsScreen(),
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final dynamic _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
