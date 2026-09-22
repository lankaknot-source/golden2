import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/caregiver/job_feed_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/client/create_job_screen.dart';
import '../screens/client/elder_profile_screen.dart';
import '../screens/client/find_caregiver_screen.dart';
import '../screens/common/no_internet_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/log/care_log_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/profile/caregiver_verification_screen.dart';
import '../screens/profile/client_kyc_screen.dart';
import '../screens/profile/leave_request_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/rating/rating_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/wallet/wallet_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoading = authState is AuthLoading;
      final isAuth = authState is AuthAuthenticated;
      final location = state.matchedLocation;

      // While a sign-in / sign-up is in flight, stay on the auth screen so its
      // loading spinner and error messages can show. Only the initial app-launch
      // load (when not on an auth screen) should fall through to the splash.
      if (isLoading) {
        if (location == '/login' || location == '/signup') return null;
        return '/splash';
      }

      if (!isAuth) {
        if (location == '/login' || location == '/signup') return null;
        return '/login';
      }

      if (location == '/splash' || location == '/login' || location == '/signup') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, state) => const SignUpScreen()),
      GoRoute(path: '/role-selection', builder: (ctx, state) => const RoleSelectionScreen()),
      GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),
      GoRoute(path: '/bookings', builder: (ctx, state) => const BookingsScreen()),
      GoRoute(path: '/job-feed', builder: (ctx, state) => const JobFeedScreen()),
      GoRoute(path: '/create-job', builder: (ctx, state) => const CreateJobScreen()),
      GoRoute(path: '/find-caregiver', builder: (ctx, state) => const FindCaregiverScreen()),
      GoRoute(path: '/elder-profile', builder: (ctx, state) => const ElderProfileScreen()),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (ctx, state) => ChatScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/map/:bookingId',
        builder: (ctx, state) => MapScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(path: '/wallet', builder: (ctx, state) => const WalletScreen()),
      GoRoute(
        path: '/care-log/:bookingId',
        builder: (ctx, state) => CareLogScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
      GoRoute(path: '/client-kyc', builder: (ctx, state) => const ClientKycScreen()),
      GoRoute(
        path: '/caregiver-verification',
        builder: (ctx, state) => const CaregiverVerificationScreen(),
      ),
      GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
      GoRoute(path: '/no-internet', builder: (ctx, state) => const NoInternetScreen()),
      GoRoute(path: '/leave-requests', builder: (ctx, state) => const LeaveRequestScreen()),
      GoRoute(
        path: '/rating/:bookingId',
        builder: (ctx, state) => RatingScreen(
          bookingId: state.pathParameters['bookingId']!,
          caregiverId: state.extra as String? ?? '',
        ),
      ),
    ],
  );
});
