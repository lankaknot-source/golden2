import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';

// ── Language preference provider ──────────────────────────────────────────────

final isSinhalaProvider = StateNotifierProvider<_LangNotifier, bool>((ref) {
  return _LangNotifier();
});

class _LangNotifier extends StateNotifier<bool> {
  _LangNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('is_sinhala') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sinhala', state);
  }
}

// ── Settings screen ───────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // Profile card
          _ProfileCard(user: user),
          const SizedBox(height: 8),

          // ── Account section ───────────────────────────────────────────────
          _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.account_circle_outlined,
            iconColor: AppColors.primary,
            title: 'Edit Profile',
            subtitle: 'Update name, phone and photo',
            onTap: () => context.push('/profile'),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.primary,
            title: 'Verification Status',
            subtitle: _kycLabel(user.kycStatus),
            trailing: _KycBadge(status: user.kycStatus),
            onTap: () => context.push(
              user.isCaregiverOrNurse
                  ? '/caregiver-verification'
                  : '/client-kyc',
            ),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.primary,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const SizedBox(height: 8),

          // ── Preferences section ───────────────────────────────────────────
          _SectionHeader('Preferences'),
          _SettingsTile(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.accent,
            title: 'Wallet',
            subtitle: 'View balance and transactions',
            onTap: () => context.push('/wallet'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.warning,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () => _showNotificationsSheet(context),
          ),
          _LanguageTile(),
          const SizedBox(height: 8),

          // ── Support section ───────────────────────────────────────────────
          _SectionHeader('Support'),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            iconColor: AppColors.info,
            title: 'Help',
            subtitle: 'FAQs and how-to guides',
            onTap: () => _launchUrl('https://kinacare.lk/help'),
          ),
          _SettingsTile(
            icon: Icons.chat_outlined,
            iconColor: AppColors.info,
            title: 'Contact Us',
            subtitle: 'support@kinacare.lk',
            onTap: () => _showContactSheet(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Privacy Policy',
            onTap: () => _launchUrl('https://kinacare.lk/privacy'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Terms of Service',
            onTap: () => _launchUrl('https://kinacare.lk/terms'),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: 'App Version',
            subtitle: '1.3.0 (build 4)',
            onTap: null,
          ),
          const SizedBox(height: 8),

          // ── Danger zone ───────────────────────────────────────────────────
          _SectionHeader('Danger Zone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    subtitle: const Text(
                      'You will be returned to the login screen',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.error),
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently remove your account and data',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.error),
                    onTap: () =>
                        _confirmDeleteAccount(context, ref, user),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _kycLabel(KycStatus s) => switch (s) {
        KycStatus.approved => 'Verified',
        KycStatus.rejected => 'Rejected — re-submit',
        _ => 'Under review',
      };

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email to receive a password reset link.',
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await ref
                    .read(authProvider.notifier)
                    .sendPasswordReset(ctrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password reset email sent!'),
                    backgroundColor: AppColors.accent,
                  ));
                }
              }
            },
            child: const Text('Send', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notification Settings',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 16),
            _NotifToggleTile(
                label: 'Booking Alerts',
                subtitle: 'New bookings, status changes',
                prefKey: 'notif_bookings'),
            _NotifToggleTile(
                label: 'Chat Messages',
                subtitle: 'Messages from clients/caregivers',
                prefKey: 'notif_chat'),
            _NotifToggleTile(
                label: 'Wallet Updates',
                subtitle: 'Payment confirmations',
                prefKey: 'notif_wallet'),
            _NotifToggleTile(
                label: 'Promotions',
                subtitle: 'App updates and offers',
                prefKey: 'notif_promo'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done',
                    style: TextStyle(fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact Us',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 6),
            const Text(
              'We\'re here to help. Reach out through any channel below.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 20),
            _ContactOptionTile(
              icon: Icons.email_outlined,
              color: AppColors.primary,
              title: 'Email Support',
              subtitle: 'support@kinacare.lk',
              onTap: () => _launchUrl('mailto:support@kinacare.lk'),
            ),
            const SizedBox(height: 12),
            _ContactOptionTile(
              icon: Icons.phone_outlined,
              color: AppColors.accent,
              title: 'Phone / WhatsApp',
              subtitle: '+94 77 000 0000',
              onTap: () => _launchUrl('tel:+94770000000'),
            ),
            const SizedBox(height: 12),
            _ContactOptionTile(
              icon: Icons.web_outlined,
              color: AppColors.info,
              title: 'Website',
              subtitle: 'www.kinacare.lk',
              onTap: () => _launchUrl('https://kinacare.lk'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, UserModel user) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Delete Account',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is PERMANENT and cannot be undone. All your data, bookings, and earnings history will be deleted.',
              style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type "DELETE" to confirm:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.error)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.error, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (confirmCtrl.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please type DELETE to confirm'),
                  backgroundColor: AppColors.warning,
                ));
                return;
              }
              Navigator.pop(ctx);
              await _deleteAccount(context, ref, user);
            },
            child: const Text('Delete',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(
      BuildContext context, WidgetRef ref, UserModel user) async {
    try {
      // Soft-delete: mark as deleted in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      // Delete Firebase Auth account
      await FirebaseAuth.instance.currentUser?.delete();
      // Sign out
      await ref.read(authProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Delete failed. You may need to re-login first. Error: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            backgroundImage:
                user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
            child: user.profileImageUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (user.isSuperCaregiver) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.amber, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'Super',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.edit_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint)
                : null),
        onTap: onTap,
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  final KycStatus status;
  const _KycBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      KycStatus.approved => (AppColors.accent, Icons.verified_rounded),
      KycStatus.rejected => (AppColors.error, Icons.cancel_rounded),
      _ => (AppColors.warning, Icons.hourglass_top_rounded),
    };
    return Icon(icon, color: color, size: 22);
  }
}

// ── Language toggle tile ──────────────────────────────────────────────────────

class _LanguageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSinhala = ref.watch(isSinhalaProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.language_rounded,
              color: AppColors.primary, size: 20),
        ),
        title: const Text(
          'Language / භාෂාව',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Text(
          isSinhala ? 'සිංහල' : 'English',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: isSinhala ? AppColors.textHint : AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: isSinhala,
              onChanged: (_) async {
                await ref.read(isSinhalaProvider.notifier).toggle();
                if (context.mounted) {
                  final newVal = ref.read(isSinhalaProvider);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      newVal
                          ? 'භාෂාව සිංහල ලෙස වෙනස් කරන ලදී'
                          : 'Language changed to English',
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              activeThumbColor: AppColors.accent,
              activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 2),
            Text(
              'සිං',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: isSinhala ? AppColors.accent : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification toggle tile ──────────────────────────────────────────────────

class _NotifToggleTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final String prefKey;
  const _NotifToggleTile({
    required this.label,
    required this.subtitle,
    required this.prefKey,
  });

  @override
  State<_NotifToggleTile> createState() => _NotifToggleTileState();
}

class _NotifToggleTileState extends State<_NotifToggleTile> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _enabled = prefs.getBool(widget.prefKey) ?? true);
  }

  Future<void> _toggle(bool val) async {
    setState(() => _enabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefKey, val);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.notifications_outlined,
            color: AppColors.warning, size: 18),
      ),
      title: Text(
        widget.label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFamily: 'Poppins',
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFamily: 'Poppins'),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
        activeThumbColor: AppColors.accent,
      ),
    );
  }
}

// ── Contact option tile ───────────────────────────────────────────────────────

class _ContactOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
