import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_view_model.dart';
import '../../domain/model/data_models.dart';
import '../widgets/glass_container.dart';
import '../widgets/caregiver_avatar.dart';

const Color colorBlue = Color(0xFF1E6091);
const Color colorGreen = Color(0xFF52BE80);
const Color colorLightBlue = Color(0xFF5DADE2);
const Color colorDarkNavy = Color(0xFF1A5276);
const Color colorBackground = Color(0xFFF4F8FB);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedBottomTab = 0;
  bool _isSinhala = false;

  // ignore: unused_field
  bool _showKycPrompt = false;
  // ignore: unused_field
  bool _showFeePrompt = false;
  bool _hasCheckedKyc = false;

  /// Returns [si] when Sinhala is active, [en] otherwise.
  String _t(String en, String si) => _isSinhala ? si : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().fetchUserData();
    });
  }

  void _handleKycChecks(User user) {
    if (!_hasCheckedKyc) {
      _hasCheckedKyc = true;
      if (!user.isVerified && user.nicNumber.isEmpty) {
        setState(() => _showKycPrompt = true);
      } else if (user.role == "CLIENT" &&
          user.kycStatus == "APPROVED" &&
          !user.isVerified) {
        setState(() => _showFeePrompt = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        final user = state.userData;

        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleKycChecks(user);
          });
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D3B66),
                  Color(0xFF1A5276),
                  Color(0xFF1E8BC3),
                  Color(0xFF52BE80),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : user == null
                    ? const Center(
                        child: Text("User not found",
                            style: TextStyle(color: Colors.white)))
                    : SafeArea(
                        bottom: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            children: [
                              _buildHeader(user, viewModel),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 24, 16, 0),
                                child: Column(
                                  children: [
                                    if ((user.role == "CAREGIVER" ||
                                        user.role == "NURSE"))
                                      _buildCaregiverGrid()
                                    else
                                      _buildClientGrid(),
                                    const SizedBox(height: 24),
                                    if (user.role == "CLIENT")
                                      _buildTopCaregivers(state, viewModel),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          floatingActionButton: user != null
              ? FloatingActionButton.extended(
                  onPressed: _showSosDialog,
                  backgroundColor: Colors.red.withOpacity(0.85),
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text("SOS",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : null,
          bottomNavigationBar: _buildGlassBottomNav(),
        );
      },
    );
  }

  Widget _buildGlassBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GlassContainer(
        borderRadius: 30,
        blur: 30,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, "Home", 0),
            _navItem(Icons.date_range_rounded, "Bookings", 1),
            _navItem(Icons.email_rounded, "Messages", 2),
            _navItem(Icons.person_rounded, "Profile", 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _selectedBottomTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBottomTab = index);
        if (index == 1) context.push('/bookings');
        if (index == 2) context.push('/messages');
        if (index == 3) context.push('/profile');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User user, HomeViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset('assets/brand_logo.jpeg',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      semanticLabel: 'Golden Hand Caregivers logo'),
                  SizedBox(width: 8),
                  Text("Golden Hand",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isSinhala = !_isSinhala),
                    child: Text(_isSinhala ? "EN" : "සිං",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () {
                      viewModel.logout();
                      context.go('/login');
                    },
                    icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _t("Hello, ${user.name.split(' ').first}!",
                "ආයුබෝවන්, ${user.name.split(' ').first}!"),
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _t("Find the best care for your loved ones",
                "ඔබේ ආදරණීයයන් සඳහා හොඳම සේවාව සොයා ගන්න"),
            style:
                TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push('/find_caregiver'),
            child: GlassContainer(
              borderRadius: 28,
              blur: 20,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                  const SizedBox(width: 12),
                  Text(
                    _t("Search for a caregiver or nurse...",
                        "සේවකයෙකු හෝ හෙදියක් සොයන්න..."),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t("Quick Actions", "ශීඝ්‍ර ක්‍රියා"),
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildGlassCard(
                  _t("Elder\nCare", "වැඩිහිටි\nසත්කාර"),
                  Icons.search,
                  colorBlue,
                  () => context.push('/find_caregiver')),
              const SizedBox(width: 12),
              _buildGlassCard(
                  _t("Patient\nProfiles", "රෝගී\nපැතිකඩ"),
                  Icons.favorite,
                  colorGreen,
                  () => context.push('/elder_profile')),
              const SizedBox(width: 12),
              _buildGlassCard(_t("Chats &\nMessages", "කතාබස් &\nපණිවිඩ"),
                  Icons.email, colorLightBlue, () => context.push('/messages')),
              const SizedBox(width: 12),
              _buildGlassCard(_t("Account\nSettings", "ගිණුම්\nසැකසීම්"),
                  Icons.person, colorDarkNavy, () => context.push('/profile')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t("Quick Actions", "ශීඝ්‍ර ක්‍රියා"),
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildGlassCard(
                  _t("Job\nRequests", "රැකියා\nඉල්ලීම්"),
                  Icons.notifications,
                  colorBlue,
                  () => context.push('/job_feed')),
              const SizedBox(width: 12),
              _buildGlassCard(_t("Live\nMap", "සජීවී\nසිතියම"), Icons.place,
                  colorLightBlue, () => context.push('/map')),
              const SizedBox(width: 12),
              _buildGlassCard(
                  _t("My\nEarnings", "මගේ\nඉපැයීම්"),
                  Icons.shopping_cart,
                  colorGreen,
                  () => context.push('/wallet')),
              const SizedBox(width: 12),
              _buildGlassCard(_t("My\nProfile", "මගේ\nපැතිකඩ"), Icons.person,
                  colorDarkNavy, () => context.push('/profile')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(
      String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 22,
        blur: 20,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCaregivers(HomeUiState state, HomeViewModel viewModel) {
    if (state.topCaregivers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_t("Top Rated Caregivers", "ඉහළ ශ්‍රේණිගත සේවකයින්"),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/find_caregiver'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(_t("View all", "සියල්ල බලන්න"),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.topCaregivers
                .map((c) => _buildCaregiverAvatar(c))
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _showSosDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A2A3A),
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.redAccent, size: 48),
        title: Text(
          _t("Emergency Call", "හදිසි ඇමතුම"),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _t(
            "This will call the emergency helpline (1990).\nAre you sure?",
            "මෙය හදිසි උදව් මාර්ගය (1990) ඇමතීමට පෙළඹේ.\nඔබට විශ්වාසද?",
          ),
          style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_t("Cancel", "අවලංගු කරන්න"),
                style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.call, color: Colors.white, size: 18),
            label: Text(_t("Call Now", "දැන් අමතන්න"),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // canLaunchUrl reports false for tel: on iOS without an
    // LSApplicationQueriesSchemes entry, so attempt the launch directly.
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse('tel:1990'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            _t(
              "Could not start the call. Please dial 1990 manually.",
              "ඇමතුම ආරම්භ කළ නොහැක. කරුණාකර 1990 අමතන්න.",
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCaregiverAvatar(User caregiver) {
    final bool isSuper = caregiver.rating >= 4.8 && caregiver.reviewCount >= 5;

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: GlassContainer(
        borderRadius: 16,
        blur: 16,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CaregiverAvatar(
              name: caregiver.name,
              imageUrl: caregiver.profileImageUrl,
              size: 64,
              isSuper: isSuper,
            ),
            const SizedBox(height: 8),
            Text(caregiver.name.split(' ').first,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(caregiver.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Icon(Icons.star, color: Colors.amber, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
