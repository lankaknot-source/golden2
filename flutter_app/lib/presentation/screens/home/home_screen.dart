import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/notification_service.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/user_provider.dart';

Future<void> _openLegalPage(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ── Promo banner provider ─────────────────────────────────────────────────────

final promoBannersProvider = FutureProvider<List<String>>((ref) async {
  try {
    final snap = await ref
        .watch(bookingRepositoryProvider)
        .firestore
        .collection('settings')
        .doc('promotion')
        .get();
    if (snap.exists) {
      final data = snap.data();
      final banners = List<String>.from(data?['banners'] as List? ?? []);
      if (banners.isNotEmpty) return banners;
    }
  } catch (_) {}
  return [];
});

// ── Language provider ─────────────────────────────────────────────────────────

final homeLanguageProvider = StateNotifierProvider<_HomeLangNotifier, String>((ref) {
  return _HomeLangNotifier();
});

class _HomeLangNotifier extends StateNotifier<String> {
  _HomeLangNotifier() : super('en') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('app_language') ?? 'en';
  }

  Future<void> toggle() async {
    state = state == 'en' ? 'si' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', state);
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _clientDests = [
    NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_today_rounded),
        label: 'Bookings'),
    NavigationDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Elders'),
    NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile'),
  ];

  static const _caregiverDests = [
    NavigationDestination(
        icon: Icon(Icons.work_outline_rounded),
        selectedIcon: Icon(Icons.work_rounded),
        label: 'Jobs'),
    NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_today_rounded),
        label: 'Bookings'),
    NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map_rounded),
        label: 'Map'),
    NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Wallet'),
    NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final isCaregiver = user.isCaregiverOrNurse;

    final pages = isCaregiver
        ? <Widget>[
            const _JobFeedTab(),
            const _BookingsTab(),
            _PlaceholderTab(
                icon: Icons.map_rounded,
                label: 'Live Map',
                route: '/map/active'),
            _PlaceholderTab(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                route: '/wallet'),
            const _ProfileTab(),
          ]
        : <Widget>[
            const _ClientHomeTab(),
            const _BookingsTab(),
            _PlaceholderTab(
                icon: Icons.people_rounded,
                label: 'My Elders',
                route: '/elder-profile'),
            const _ProfileTab(),
          ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: isCaregiver ? _caregiverDests : _clientDests,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      ),
    );
  }
}

// ── SOS FAB ───────────────────────────────────────────────────────────────────

class _SosFab extends ConsumerWidget {
  const _SosFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'sos_fab',
      backgroundColor: AppColors.error,
      onPressed: () => _showSosDialog(context, ref),
      shape: const CircleBorder(),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sos_rounded, color: Colors.white, size: 22),
          Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSosDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Emergency SOS',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will create an emergency booking request and alert nearby caregivers immediately.\n\nAre you sure you want to send an emergency alert?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final now = DateTime.now();
      final emergency = Booking(
        id: '',
        clientId: user.uid,
        elderId: 'sos_${user.uid}',
        address: user.address ?? 'Location unknown',
        locationLat: user.locationLat ?? 0.0,
        locationLng: user.locationLng ?? 0.0,
        requestedTime: now.millisecondsSinceEpoch,
        scheduledTime: now.millisecondsSinceEpoch,
        startTime: now.millisecondsSinceEpoch,
        endTime: now.add(const Duration(hours: 4)).millisecondsSinceEpoch,
        status: BookingStatus.broadcasted,
        isEmergency: true,
      );

      await ref.read(bookingNotifierProvider.notifier).createBooking(emergency);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Emergency alert sent! Caregivers have been notified.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error sending SOS: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }
}

// ── Promo banner slider ───────────────────────────────────────────────────────

class _PromoBannerSlider extends ConsumerStatefulWidget {
  const _PromoBannerSlider();

  @override
  ConsumerState<_PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends ConsumerState<_PromoBannerSlider> {
  final _pageCtrl = PageController();
  int _current = 0;
  Timer? _timer;

  static const _defaultColors = [
    Color(0xFF0D3B66),
    Color(0xFF53A548),
    Color(0xFF1E6091),
  ];

  static const _defaultMessages = [
    'Professional Care for Your Loved Ones',
    'Verified Caregivers at Your Service',
    'Safe · Reliable · Compassionate',
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final banners = ref.read(promoBannersProvider).value ?? [];
      final count = banners.isEmpty ? _defaultColors.length : banners.length;
      final next = (_current + 1) % count;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(promoBannersProvider);
    final imageUrls = bannersAsync.value ?? [];
    final count = imageUrls.isEmpty ? _defaultColors.length : imageUrls.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: count,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              if (imageUrls.isNotEmpty) {
                return _ImageBanner(url: imageUrls[i]);
              }
              return _ColorBanner(
                color: _defaultColors[i % _defaultColors.length],
                message: _defaultMessages[i % _defaultMessages.length],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _current ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _current
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ImageBanner extends StatelessWidget {
  final String url;
  const _ImageBanner({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }
}

class _ColorBanner extends StatelessWidget {
  final Color color;
  final String message;
  const _ColorBanner({required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.health_and_safety_rounded,
                color: Colors.white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KYC Meeting banner ────────────────────────────────────────────────────────

class _KycMeetingBanner extends StatelessWidget {
  final UserModel user;
  const _KycMeetingBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.kycMeetingDateMs == null || user.kycMeetingUrl == null) {
      return const SizedBox.shrink();
    }
    final date = DateTime.fromMillisecondsSinceEpoch(user.kycMeetingDateMs!);
    if (date.isBefore(DateTime.now())) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KYC Interview Scheduled',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(date),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Join',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Super Caregiver section ───────────────────────────────────────────────────

class _SuperCaregiverSection extends ConsumerWidget {
  const _SuperCaregiverSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiversAsync = ref.watch(caregiversProvider);

    return caregiversAsync.when(
      data: (caregivers) {
        final superstars = caregivers
            .where((c) => c.rating >= 4.8 && c.reviewCount >= 5)
            .toList();
        if (superstars.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'Super Caregivers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/find-caregiver'),
                      child: const Text('See all',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: superstars.length,
                  itemBuilder: (ctx, i) =>
                      _SuperCaregiverCard(user: superstars[i]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SuperCaregiverCard extends StatelessWidget {
  final UserModel user;
  const _SuperCaregiverCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Poppins',
                        ),
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              user.name.split(' ').first,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
              const SizedBox(width: 3),
              Text(
                user.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                ' (${user.reviewCount})',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () => context.push('/find-caregiver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600),
              ),
              child: const Text('Book'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client Home Tab ───────────────────────────────────────────────────────────

class _ClientHomeTab extends ConsumerWidget {
  const _ClientHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final bookingsAsync = ref.watch(clientBookingsProvider);
    final lang = ref.watch(homeLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const _SosFab(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(clientBookingsProvider),
        child: CustomScrollView(
          slivers: [
            _ClientSliverHeader(user: user, lang: lang),


            SliverToBoxAdapter(child: _KycMeetingBanner(user: user)),

            // Active care session
            bookingsAsync.when(
              data: (bookings) {
                final active = bookings
                    .where((b) => b.status == BookingStatus.inProgress)
                    .toList();
                if (active.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: _ActiveBookingCard(booking: active.first),
                );
              },
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            SliverToBoxAdapter(child: _QuickActions()),

            // Promo banners
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const SliverToBoxAdapter(child: _PromoBannerSlider()),

            // Super Caregivers
            const SliverToBoxAdapter(child: _SuperCaregiverSection()),

            SliverToBoxAdapter(
              child: bookingsAsync.when(
                data: (bookings) =>
                    _RecentBookings(bookings: bookings.take(3).toList()),
                loading: () => const _BookingsShimmer(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _ClientSliverHeader extends StatelessWidget {
  final UserModel user;
  final String lang;
  const _ClientSliverHeader({required this.user, required this.lang});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Poppins')),
                  const SizedBox(height: 2),
                  Text(
                    user.name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  _KycChip(status: user.kycStatus),
                ],
              ),
            ),
            // Language toggle button
            Consumer(
              builder: (ctx, ref, _) {
                final currentLang = ref.watch(homeLanguageProvider);
                return GestureDetector(
                  onTap: () async {
                    await ref.read(homeLanguageProvider.notifier).toggle();
                    final newLang = ref.read(homeLanguageProvider);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                          newLang == 'si'
                              ? 'භාෂාව සිංහල ලෙස වෙනස් කරන ලදී'
                              : 'Language changed to English',
                          style: const TextStyle(fontFamily: 'Poppins'),
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      currentLang == 'en' ? 'EN' : 'සිං',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KycChip extends StatelessWidget {
  final KycStatus status;
  const _KycChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      KycStatus.approved => ('Verified', AppColors.accent),
      KycStatus.rejected => ('Action Required', AppColors.error),
      _ => ('Under Review', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white54 ? Colors.white70 : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _KycBanner extends StatelessWidget {
  final KycStatus status;
  final bool isCaregiver;
  const _KycBanner({required this.status, required this.isCaregiver});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == KycStatus.rejected;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isRejected ? AppColors.error : AppColors.warning)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isRejected ? AppColors.error : AppColors.warning)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRejected ? Icons.cancel_outlined : Icons.info_outline_rounded,
            color: isRejected ? AppColors.error : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRejected
                  ? 'Your verification was rejected. Please re-submit.'
                  : 'Complete your profile verification to unlock all features.',
              style: TextStyle(
                fontSize: 12,
                color: isRejected ? AppColors.error : AppColors.warning,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push(
                isCaregiver ? '/caregiver-verification' : '/client-kyc'),
            child: Text(
              'Fix',
              style: TextStyle(
                fontSize: 12,
                color: isRejected ? AppColors.error : AppColors.warning,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  final Booking booking;
  const _ActiveBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Care Session',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, fontFamily: 'Poppins'),
                ),
                Text(
                  booking.elderId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime)),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/map/${booking.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accentDark,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Track',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(Icons.search_rounded, 'Find\nCaregiver', AppColors.primary,
          '/find-caregiver'),
      _Action(Icons.add_circle_outline_rounded, 'Create\nJob',
          AppColors.accent, '/create-job'),
      _Action(Icons.people_rounded, 'My\nElders', const Color(0xFF8B5CF6),
          '/elder-profile'),
      _Action(Icons.chat_bubble_outline_rounded, 'Messages',
          const Color(0xFF0EA5E9), '/bookings'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: actions
                .map((a) => Expanded(child: _ActionButton(action: a)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _Action(this.icon, this.label, this.color, this.route);
}

class _ActionButton extends StatelessWidget {
  final _Action action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => context.push(action.route),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: action.color.withValues(alpha: 0.2)),
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  final List<Booking> bookings;
  const _RecentBookings({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Bookings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              if (bookings.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/bookings'),
                  child: const Text('See all',
                      style: TextStyle(fontFamily: 'Poppins')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (bookings.isEmpty)
            _EmptyBookings()
          else
            ...bookings.map((b) => _BookingTile(booking: b)),
        ],
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'No bookings yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a job to get started',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 40,
            child: ElevatedButton(
              onPressed: () => context.push('/create-job'),
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Create Job',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(booking.status);
    final fmt = DateFormat('d MMM');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.elderId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime))} · ${booking.startTime}–${booking.endTime}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(booking.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _statusStyle(BookingStatus s) => switch (s) {
        BookingStatus.pending => (AppColors.statusPending, Icons.schedule_rounded),
        BookingStatus.broadcasted => (AppColors.statusPending, Icons.broadcast_on_personal_rounded),
        BookingStatus.broadcastAccepted => (AppColors.statusPending, Icons.how_to_reg_rounded),
        BookingStatus.accepted => (AppColors.statusActive, Icons.check_circle_outline_rounded),
        BookingStatus.inProgress => (AppColors.accent, Icons.favorite_rounded),
        BookingStatus.completed => (AppColors.statusCompleted, Icons.task_alt_rounded),
        BookingStatus.cancelled => (AppColors.statusCancelled, Icons.cancel_outlined),
        BookingStatus.rejected => (AppColors.statusCancelled, Icons.close_rounded),
        BookingStatus.declined => (AppColors.statusCancelled, Icons.thumb_down_outlined),
      };

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'Pending',
        BookingStatus.broadcasted => 'Open',
        BookingStatus.broadcastAccepted => 'Awaiting confirmation',
        BookingStatus.accepted => 'Accepted',
        BookingStatus.inProgress => 'Active',
        BookingStatus.completed => 'Done',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.declined => 'Declined',
      };
}

class _BookingsShimmer extends StatelessWidget {
  const _BookingsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
          2,
          (_) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(14),
                ),
              )),
    );
  }
}

// ── Job Feed Tab (Caregivers) ─────────────────────────────────────────────────

class _JobFeedTab extends ConsumerWidget {
  const _JobFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final jobsAsync = ref.watch(availableJobsProvider);
    final lang = ref.watch(homeLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(availableJobsProvider),
        child: CustomScrollView(
          slivers: [
            _CaregiverSliverHeader(user: user, lang: lang),
            if (user.kycStatus == KycStatus.pending ||
                user.kycStatus == KycStatus.rejected)
              SliverToBoxAdapter(
                child: _KycBanner(status: user.kycStatus, isCaregiver: true),
              ),
            SliverToBoxAdapter(child: _KycMeetingBanner(user: user)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      'Available Jobs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 8),
                    jobsAsync.when(
                      data: (list) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${list.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            jobsAsync.when(
              data: (jobs) => jobs.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyJobFeed())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _JobCard(booking: jobs[i]),
                        childCount: jobs.length,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => const _JobCardShimmer(),
                  childCount: 3,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _CaregiverSliverHeader extends StatelessWidget {
  final UserModel user;
  final String lang;
  const _CaregiverSliverHeader({required this.user, required this.lang});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Poppins')),
                  const SizedBox(height: 2),
                  Text(
                    user.name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  _KycChip(status: user.kycStatus),
                ],
              ),
            ),
            // Language toggle
            Consumer(
              builder: (ctx, ref, _) {
                final currentLang = ref.watch(homeLanguageProvider);
                return GestureDetector(
                  onTap: () async {
                    await ref.read(homeLanguageProvider.notifier).toggle();
                    final newLang = ref.read(homeLanguageProvider);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                          newLang == 'si'
                              ? 'භාෂාව සිංහල ලෙස වෙනස් කරන ලදී'
                              : 'Language changed to English',
                          style: const TextStyle(fontFamily: 'Poppins'),
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      currentLang == 'en' ? 'EN' : 'සිං',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  final Booking booking;
  const _JobCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bookingNotifierProvider.notifier);
    final user = ref.watch(currentUserProvider)!;
    final fmt = DateFormat('EEE, d MMM');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: booking.isEmergency
                  ? AppColors.error.withValues(alpha: 0.05)
                  : AppColors.primary.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.elderId,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (booking.isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EMERGENCY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'New Job',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusPending,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              children: [
                _JobDetail(Icons.location_on_outlined, booking.address),
                const SizedBox(height: 6),
                _JobDetail(
                    Icons.calendar_today_outlined,
                    '${fmt.format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime))} • ${booking.startTime}–${booking.endTime}'),
                if (booking.requestedTasks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _JobDetail(Icons.task_alt_outlined,
                      booking.requestedTasks.take(2).join(', ')),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins')),
                    Text(
                      'LKR ${NumberFormat('#,###').format(booking.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () async {
                    await notifier.updateStatus(
                        booking.id, BookingStatus.declined);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await notifier.acceptJob(booking.id, user.uid, user.hourlyRate ?? 1500.0);
                    NotificationService().scheduleJobReminders(
                      bookingId: booking.id,
                      scheduledTimeMs: booking.scheduledTime,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                        content: Text('Job accepted successfully!'),
                        backgroundColor: AppColors.accent,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobDetail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _JobDetail(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _JobCardShimmer extends StatelessWidget {
  const _JobCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 170,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptyJobFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.work_off_rounded, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No jobs available right now',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New job requests will appear here',
            style: TextStyle(
                fontSize: 12, color: AppColors.textHint, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

// ── Bookings Tab ──────────────────────────────────────────────────────────────

class _BookingsTab extends ConsumerStatefulWidget {
  const _BookingsTab();

  @override
  ConsumerState<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<_BookingsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final isCaregiver = user.isCaregiverOrNurse;
    final bookingsAsync = isCaregiver
        ? ref.watch(caregiverBookingsProvider)
        : ref.watch(clientBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          final upcoming = bookings
              .where((b) =>
                  b.status == BookingStatus.pending ||
                  b.status == BookingStatus.broadcasted ||
                  b.status == BookingStatus.broadcastAccepted ||
                  b.status == BookingStatus.accepted)
              .toList();
          final active = bookings
              .where((b) => b.status == BookingStatus.inProgress)
              .toList();
          final completed = bookings
              .where((b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.cancelled)
              .toList();

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _BookingList(
                  bookings: upcoming, emptyMessage: 'No upcoming bookings'),
              _BookingList(
                  bookings: active, emptyMessage: 'No active sessions'),
              _BookingList(
                  bookings: completed, emptyMessage: 'No completed bookings'),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading bookings: $e')),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyMessage;
  const _BookingList({required this.bookings, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 52, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) => _BookingCard(booking: bookings[i]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final (color, icon) = _statusStyle(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/care-log/${booking.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.elderId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime))} • ${booking.startTime}–${booking.endTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.address,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(booking.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'LKR ${NumberFormat('#,###').format(booking.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData) _statusStyle(BookingStatus s) => switch (s) {
        BookingStatus.pending => (AppColors.statusPending, Icons.schedule_rounded),
        BookingStatus.broadcasted => (AppColors.statusPending, Icons.broadcast_on_personal_rounded),
        BookingStatus.broadcastAccepted => (AppColors.statusPending, Icons.how_to_reg_rounded),
        BookingStatus.accepted => (AppColors.statusActive, Icons.check_circle_outline_rounded),
        BookingStatus.inProgress => (AppColors.accent, Icons.favorite_rounded),
        BookingStatus.completed => (AppColors.statusCompleted, Icons.task_alt_rounded),
        BookingStatus.cancelled => (AppColors.statusCancelled, Icons.cancel_outlined),
        BookingStatus.rejected => (AppColors.statusCancelled, Icons.close_rounded),
        BookingStatus.declined => (AppColors.statusCancelled, Icons.thumb_down_outlined),
      };

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'Pending',
        BookingStatus.broadcasted => 'Open',
        BookingStatus.broadcastAccepted => 'Awaiting confirmation',
        BookingStatus.accepted => 'Accepted',
        BookingStatus.inProgress => 'Active',
        BookingStatus.completed => 'Done',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.declined => 'Declined',
      };
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final isCaregiver = user.isCaregiverOrNurse;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.roleLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _KycChip(status: user.kycStatus),
                      if (user.isSuperCaregiver) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 12),
                              SizedBox(width: 3),
                              Text('Super',
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ProfileSection(
                    title: 'Account',
                    items: [
                      _ProfileItem(Icons.edit_outlined, 'Edit Profile',
                          () => context.push('/profile')),
                      _ProfileItem(
                        Icons.verified_user_outlined,
                        isCaregiver ? 'Verification' : 'Client Details',
                        () => context.push(isCaregiver
                            ? '/caregiver-verification'
                            : '/client-kyc'),
                        trailing: _kycTrailing(user.kycStatus),
                      ),
                      if (isCaregiver)
                        _ProfileItem(Icons.event_busy_outlined,
                            'Leave Requests',
                            () => context.push('/leave-requests')),
                      if (user.rating > 0)
                        _ProfileItem(
                          Icons.star_outline_rounded,
                          'My Rating',
                          null,
                          trailing: Text(
                            '${user.rating.toStringAsFixed(1)} (${user.reviewCount})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProfileSection(
                    title: 'Support',
                    items: [
                      _ProfileItem(Icons.settings_outlined, 'Settings',
                          () => context.push('/settings')),
                      _ProfileItem(Icons.help_outline_rounded, 'Help & Support',
                          () => _openLegalPage('mailto:it@goldenhandcaregivers.com')),
                      _ProfileItem(Icons.description_outlined,
                          'Terms & Conditions', () => _openLegalPage(
                              'https://ykingtech.github.io/GOLDEN-HAND-CAREGIVER/terms.html')),
                      _ProfileItem(Icons.privacy_tip_outlined, 'Privacy Policy',
                          () => _openLegalPage(
                              'https://ykingtech.github.io/GOLDEN-HAND-CAREGIVER/privacy.html')),
                      _ProfileItem(Icons.currency_exchange_rounded,
                          'Refund Policy', () => _openLegalPage(
                              'https://ykingtech.github.io/GOLDEN-HAND-CAREGIVER/refund.html')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded,
                          color: AppColors.error),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sign Out',
                                    style:
                                        TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(authProvider.notifier).signOut();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kycTrailing(KycStatus status) {
    final (label, color) = switch (status) {
      KycStatus.approved => ('Verified', AppColors.accent),
      KycStatus.rejected => ('Rejected', AppColors.error),
      _ => ('Pending', AppColors.warning),
    };
    return Text(
      label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Poppins'),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileItem> items;
  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins',
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading:
                        Icon(item.icon, color: AppColors.primary, size: 22),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    trailing: item.trailing ??
                        (item.onTap != null
                            ? const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textSecondary)
                            : null),
                    onTap: item.onTap,
                  ),
                  if (!isLast) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _ProfileItem(this.icon, this.label, this.onTap, {this.trailing});
}

// ── Placeholder tab ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _PlaceholderTab(
      {required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push(route),
              child: Text('Open $label'),
            ),
          ],
        ),
      ),
    );
  }
}
