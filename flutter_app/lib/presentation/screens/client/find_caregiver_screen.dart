import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class FindCaregiverScreen extends ConsumerStatefulWidget {
  const FindCaregiverScreen({super.key});

  @override
  ConsumerState<FindCaregiverScreen> createState() => _FindCaregiverScreenState();
}

class _FindCaregiverScreenState extends ConsumerState<FindCaregiverScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _category = 'All'; // All, Caregiver, Nurse
  String _filter = 'All';   // All, Verified, Available, Top Rated

  static const _categories = ['All', 'Caregiver', 'Nurse'];
  static const _filters = ['All', 'Verified', 'Available', 'Top Rated'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caregiversAsync = ref.watch(caregiversProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find Caregivers & Nurses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
          // Category tabs (All / Caregiver / Nurse)
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final sel = _category == cat;
                  final label = cat == 'Caregiver'
                      ? 'Caregivers'
                      : cat == 'Nurse'
                          ? 'Nurses'
                          : cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? AppColors.primary
                                    : Colors.white)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Status filter chips
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final sel = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              sel ? Colors.white : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? AppColors.primary
                                    : Colors.white)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: caregiversAsync.when(
              data: (caregivers) {
                var filtered = caregivers.where((c) =>
                    _searchQuery.isEmpty ||
                    c.name.toLowerCase().contains(_searchQuery) ||
                    c.email.toLowerCase().contains(_searchQuery)).toList();

                // Apply role category filter
                if (_category == 'Caregiver') {
                  filtered = filtered.where((c) => c.role == UserRole.caregiver).toList();
                } else if (_category == 'Nurse') {
                  filtered = filtered.where((c) => c.role == UserRole.nurse).toList();
                }

                // Apply status filter
                switch (_filter) {
                  case 'Verified':
                    filtered = filtered
                        .where((c) => c.kycStatus == KycStatus.approved)
                        .toList();
                  case 'Available':
                    filtered =
                        filtered.where((c) => !c.isBusy).toList();
                  case 'Top Rated':
                    filtered = filtered
                        .where((c) => c.rating >= 4.0)
                        .toList()
                      ..sort((a, b) => b.rating.compareTo(a.rating));
                }

                if (filtered.isEmpty) {
                  return _EmptyState(hasQuery: _searchQuery.isNotEmpty);
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(caregiversProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _CaregiverCard(caregiver: filtered[i]),
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: 4,
                itemBuilder: (context, index) => const _CaregiverCardShimmer(),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load caregivers',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.toString(),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontFamily: 'Poppins',
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(caregiversProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name…',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── Caregiver card ────────────────────────────────────────────────────────────

class _CaregiverCard extends ConsumerWidget {
  final UserModel caregiver;
  const _CaregiverCard({required this.caregiver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isFav = currentUser?.favoriteCaregivers.contains(caregiver.uid) ?? false;
    final c = caregiver;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProfile(context, c),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: c.profileImageUrl != null ? NetworkImage(c.profileImageUrl!) : null,
                      child: c.profileImageUrl == null
                          ? Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: 'Poppins',
                              ),
                            )
                          : null,
                    ),
                    if (!c.isBusy)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    // Super-caregiver badge
                    if (c.isSuperCaregiver)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.kycStatus == KycStatus.approved)
                            const Icon(Icons.verified_rounded, color: AppColors.info, size: 16),
                          if (c.isSuperCaregiver) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Super',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (c.role == UserRole.nurse
                                      ? AppColors.info
                                      : AppColors.accent)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.role == UserRole.nurse ? 'Nurse' : 'Caregiver',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: c.role == UserRole.nurse
                                    ? AppColors.info
                                    : AppColors.accent,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                          const SizedBox(width: 3),
                          Text(
                            c.rating > 0
                                ? '${c.rating.toStringAsFixed(1)} (${c.reviewCount})'
                                : 'New',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (c.hourlyRate != null) ...[
                            Container(width: 3, height: 3,
                                decoration: const BoxDecoration(
                                    color: AppColors.border, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(
                              'LKR ${c.hourlyRate!.toStringAsFixed(0)}/hr',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !c.isBusy ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          color: !c.isBusy ? AppColors.accent : AppColors.textHint,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                // Favorite + hire
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleFavorite(ref, currentUser?.uid, c.uid, isFav),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.error : AppColors.border,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.push('/create-job', extra: c.uid),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      ),
                      child: const Text('Hire'),
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

  Future<void> _toggleFavorite(WidgetRef ref, String? uid, String caregiverId, bool isFav) async {
    if (uid == null) return;
    await ref.read(userRepositoryProvider).toggleFavorite(uid, caregiverId, add: !isFav);
  }

  void _showProfile(BuildContext context, UserModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CaregiverProfileSheet(caregiver: c),
    );
  }
}

// ── Caregiver profile bottom sheet ───────────────────────────────────────────

class _CaregiverProfileSheet extends StatelessWidget {
  final UserModel caregiver;
  const _CaregiverProfileSheet({required this.caregiver});

  @override
  Widget build(BuildContext context) {
    final c = caregiver;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            backgroundImage: c.profileImageUrl != null ? NetworkImage(c.profileImageUrl!) : null,
                            child: c.profileImageUrl == null
                                ? Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                                        color: AppColors.primary, fontFamily: 'Poppins'),
                                  )
                                : null,
                          ),
                          if (c.isSuperCaregiver)
                            Positioned(
                              top: 0, right: 0,
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.amber, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(c.name, style: const TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                                ),
                                if (c.kycStatus == KycStatus.approved)
                                  const Icon(Icons.verified_rounded, color: AppColors.info, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (c.role == UserRole.nurse
                                            ? AppColors.info
                                            : AppColors.accent)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.role == UserRole.nurse ? 'Nurse' : 'Caregiver',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: c.role == UserRole.nurse
                                          ? AppColors.info
                                          : AppColors.accent,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                if (c.isSuperCaregiver) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rounded, size: 11, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text('Super', style: TextStyle(fontSize: 10,
                                            fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  c.rating > 0
                                      ? '${c.rating.toStringAsFixed(1)} · ${c.reviewCount} reviews'
                                      : 'No reviews yet',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                                ),
                              ],
                            ),
                            if (c.hourlyRate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'LKR ${c.hourlyRate!.toStringAsFixed(0)} / hour',
                                style: const TextStyle(fontSize: 13, color: AppColors.primary,
                                    fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status badges row
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _Chip(Icons.circle,
                          !c.isBusy ? 'Available' : 'Unavailable',
                          !c.isBusy ? AppColors.accent : AppColors.textHint),
                      if (c.kycStatus == KycStatus.approved)
                        _Chip(Icons.verified_rounded, 'KYC Verified',
                            AppColors.info),
                      if (c.policeClearanceUrl != null &&
                          c.policeClearanceUrl!.isNotEmpty)
                        _Chip(Icons.security_rounded, 'Police Cleared',
                            AppColors.accent),
                      if (c.vaccinationStatus != null &&
                          c.vaccinationStatus!.isNotEmpty)
                        _Chip(Icons.vaccines_rounded, 'Vaccinated',
                            AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Contact
                  _InfoRow(Icons.email_outlined, 'Email', c.email),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.phone_outlined, 'Phone', c.phone),
                  if (c.experienceYears != null &&
                      c.experienceYears!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(Icons.work_history_outlined, 'Experience',
                        '${c.experienceYears} years'),
                  ],
                  if (c.specialSkills != null &&
                      c.specialSkills!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(Icons.psychology_outlined, 'Skills',
                        c.specialSkills!),
                  ],
                  if (c.qualifications != null &&
                      c.qualifications!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(Icons.school_outlined, 'Qualifications',
                        c.qualifications!),
                  ],
                  if (c.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Care Categories',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.categories
                          .map((cat) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Text(cat,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Poppins',
                                        color: AppColors.primary)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (c.preferredDistricts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Preferred Districts',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(c.preferredDistricts.join(', '),
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/create-job', extra: c.uid);
                  },
                  icon: const Icon(Icons.work_outline_rounded),
                  label: Text('Hire This ${c.role == UserRole.nurse ? 'Nurse' : 'Caregiver'}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

class _CaregiverCardShimmer extends StatelessWidget {
  const _CaregiverCardShimmer();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(16)),
      );
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasQuery ? Icons.search_off_rounded : Icons.people_outline_rounded,
                  size: 56, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                hasQuery ? 'No caregivers match your search' : 'No caregivers available',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 8),
              Text(
                hasQuery ? 'Try a different search term' : 'Check back later for available caregivers',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textHint, fontFamily: 'Poppins'),
              ),
            ],
          ),
        ),
      );
}
