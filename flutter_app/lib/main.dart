import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Auth
import 'presentation/auth/auth_view_model.dart';
import 'presentation/auth/splash_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/sign_up_screen.dart';
import 'presentation/auth/role_selection_screen.dart';

// Home
import 'presentation/home/home_screen.dart';
import 'presentation/home/home_view_model.dart';

// Client Core
import 'presentation/client/find_caregiver_screen.dart';
import 'presentation/client/find_caregiver_view_model.dart';
import 'presentation/client/elder_profile_screen.dart';
import 'presentation/client/elder_profile_view_model.dart';
import 'presentation/client/create_job_screen.dart';
import 'presentation/client/create_job_view_model.dart';

// Phase 3: Ancillary Features
import 'presentation/profile/profile_screen.dart';
import 'presentation/profile/profile_view_model.dart';
import 'presentation/wallet/wallet_screen.dart';
import 'presentation/wallet/wallet_view_model.dart';
import 'presentation/map/map_screen.dart';
import 'presentation/map/map_view_model.dart';

// Phase 4: Advanced Communication
import 'presentation/chat/chat_screen.dart';
import 'presentation/chat/chat_view_model.dart';
import 'presentation/chat/messages_screen.dart';
import 'presentation/log/care_log_screen.dart';
import 'presentation/log/care_log_view_model.dart';

// Phase 2: Caregiver/Nurse Workflows
import 'presentation/caregiver/job_feed_screen.dart';
import 'presentation/caregiver/job_feed_view_model.dart';
import 'presentation/bookings/bookings_screen.dart';
import 'presentation/bookings/bookings_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init failed: $e. Make sure google-services.json is added.");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => FindCaregiverViewModel()),
        ChangeNotifierProvider(create: (_) => ElderProfileViewModel()),
        ChangeNotifierProvider(create: (_) => CreateJobViewModel()),
        ChangeNotifierProvider(create: (_) => JobFeedViewModel()),
        ChangeNotifierProvider(create: (_) => BookingsViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => WalletViewModel()),
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ChangeNotifierProvider(create: (_) => CareLogViewModel()),
      ],
      child: const GoldenHandApp(),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/role_selection', builder: (context, state) => const RoleSelectionScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/find_caregiver', builder: (context, state) => const FindCaregiverScreen()),
    GoRoute(path: '/elder_profile', builder: (context, state) => const ElderProfileScreen()),
    GoRoute(
      path: '/create_job',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CreateJobScreen(
          caregiverId: extra?['caregiverId'],
          caregiverName: extra?['caregiverName'],
        );
      },
    ),
    GoRoute(path: '/job_feed', builder: (context, state) => const JobFeedScreen()),
    GoRoute(path: '/bookings', builder: (context, state) => const BookingsScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(path: '/messages', builder: (context, state) => const MessagesScreen()),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final bookingId = state.extra as String? ?? '';
        return ChatScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: '/care_log',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CareLogScreen(bookingId: extra['bookingId'] ?? '', elderId: extra['elderId'] ?? '');
      },
    ),
  ],
);

class GoldenHandApp extends StatelessWidget {
  const GoldenHandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Golden Hand Caregivers',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D3B66)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D3B66),
          foregroundColor: Colors.white,
        ),
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
