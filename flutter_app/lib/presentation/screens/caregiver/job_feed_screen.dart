import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/stored_image.dart';
import '../../../data/services/notification_service.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/elder_profile_model.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

// ── Elder profile provider (family by elderProfileId) ─────────────────────────

final _elderProfileFutureProvider =
    FutureProvider.family<ElderProfile?, String>((ref, profileId) async {
  if (profileId.isEmpty) return null;
  final db = FirebaseFirestore.instance;
  final doc = await db.collection('elders').doc(profileId).get();
  if (!doc.exists) return null;
  return ElderProfile.fromMap(doc.data()!, doc.id);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class JobFeedScreen extends ConsumerWidget {
  const JobFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    // Real-time stream via StreamProvider
    final pendingAsync = ref.watch(availableJobsProvider);
    final caregiverAsync = ref.watch(caregiverBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(availableJobsProvider);
          ref.invalidate(caregiverBookingsProvider);
        },
        child: CustomScrollView(
          slivers: [
            _CaregiverHeader(user: user),

            // KYC warning
            if (user.kycStatus != KycStatus.approved)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Complete verification to accept jobs.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning, fontFamily: 'Poppins'),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/caregiver-verification'),
                        child: const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 12, color: AppColors.warning,
                            fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Active job banner
            caregiverAsync.when(
              data: (bookings) {
                final active = bookings.where((b) => b.status == BookingStatus.inProgress).toList();
                if (active.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: _ActiveJobBanner(booking: active.first),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, s) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // Section header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Available Jobs',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),

            // Real-time job list
            pendingAsync.when(
              data: (jobs) {
                // Filter out jobs already handled or rejected by this caregiver
                final available = jobs.where((j) {
                  final alreadyAssigned = j.caregiverId != null && j.caregiverId!.isNotEmpty;
                  final rejectedByMe = (j.toMap()['rejectedBy'] as List?)
                          ?.contains(user.uid) ??
                      false;
                  return !alreadyAssigned && !rejectedByMe;
                }).toList();

                if (available.isEmpty) {
                  return const SliverFillRemaining(child: _EmptyJobState());
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _JobCard(booking: available[i], caregiver: user),
                    childCount: available.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _JobShimmer(),
                  childCount: 3,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Error loading jobs: $e',
                        style: const TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CaregiverHeader extends StatelessWidget {
  final UserModel user;
  const _CaregiverHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
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
                  Text(
                    greeting,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.work_outline_rounded, color: Colors.white60, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        'Caregiver',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins'),
                      ),
                      if (user.kycStatus == KycStatus.approved) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text('Verified', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: user.profileImageUrl != null ? storedImageProvider(user.profileImageUrl!) : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w700, fontFamily: 'Poppins',
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

// ── Active job banner ─────────────────────────────────────────────────────────

class _ActiveJobBanner extends StatelessWidget {
  final Booking booking;
  const _ActiveJobBanner({required this.booking});

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
          const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Job',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins'),
                ),
                Text(
                  booking.elderId,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  booking.startTime != null
                      ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(booking.startTime!))
                      : DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime)),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/bookings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accentDark,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Job card ──────────────────────────────────────────────────────────────────

class _JobCard extends ConsumerStatefulWidget {
  final Booking booking;
  final UserModel caregiver;
  const _JobCard({required this.booking, required this.caregiver});

  @override
  ConsumerState<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<_JobCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  // ── Earnings estimate ─────────────────────────────────────────────────────

  double _computeEarnings() {
    final b = widget.booking;
    final rate = widget.caregiver.hourlyRate ?? 0.0;
    if (b.totalAmount > 0) return b.totalAmount;
    return rate * b.estimatedHours;
  }

  double _hoursFromTimes() {
    final b = widget.booking;
    if (b.startTime == null) return b.estimatedHours.toDouble();
    final end = b.endTime ?? DateTime.now().millisecondsSinceEpoch;
    return ((end - b.startTime!) / (1000 * 60 * 60)).clamp(0.0, 24.0);
  }

  // ── Accept ────────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    if (widget.caregiver.kycStatus != KycStatus.approved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Complete KYC verification before accepting jobs.',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _isAccepting = true);
    try {
      await ref.read(bookingRepositoryProvider).acceptJob(
            widget.booking.id,
            widget.caregiver.uid,
            widget.caregiver.hourlyRate ?? 1500.0,
          );
      NotificationService().scheduleJobReminders(
        bookingId: widget.booking.id,
        scheduledTimeMs: widget.booking.scheduledTime,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job accepted! Check My Bookings.',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<void> _reject() async {
    setState(() => _isRejecting = true);
    try {
      await ref.read(bookingRepositoryProvider).updateBooking(
        widget.booking.id,
        {'rejectedBy': FieldValue.arrayUnion([widget.caregiver.uid])},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job skipped.',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  void _viewChat() {
    final roomId = '${widget.booking.clientId}_${widget.caregiver.uid}';
    context.push('/chat/$roomId');
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final fmt = DateFormat('d MMM yyyy');
    final earnings = _computeEarnings();
    final hours = _hoursFromTimes();
    final hourlyRate = widget.caregiver.hourlyRate;

    // Fetch elder profile for medical conditions
    final elderProfileAsync = ref.watch(_elderProfileFutureProvider(b.elderId));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            b.elderId,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary, fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b.status == BookingStatus.broadcasted ? 'BROADCAST' : 'NEW',
                              style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: AppColors.accent, fontFamily: 'Poppins',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            fmt.format(DateTime.fromMillisecondsSinceEpoch(b.requestedTime)),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${b.estimatedHours}h',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Earnings estimate column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LKR ${NumberFormat('#,###').format(earnings)}',
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.accent, fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      hourlyRate != null && earnings > 0
                          ? '${hours.toStringAsFixed(1)}h × LKR ${NumberFormat('#,###').format(hourlyRate)}'
                          : 'earnings',
                      style: const TextStyle(fontSize: 9, color: AppColors.textHint, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.address,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Elder medical conditions (from elder profile)
                elderProfileAsync.when(
                  data: (profile) {
                    if (profile == null || profile.medicalConditions.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.medical_information_outlined,
                                size: 14, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Medical Conditions',
                                    style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600,
                                      color: AppColors.error, fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.medicalConditions.join(', '),
                                    style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary,
                                      fontFamily: 'Poppins',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (profile.medicalConditions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Conditions: ${profile.medicalConditions.join(', ')}',
                                  style: const TextStyle(
                                    fontSize: 12, color: AppColors.warning,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 12,
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.shimmerBase,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  error: (e, s) => const SizedBox.shrink(),
                ),

                // Tasks
                if (b.requestedTasks.isNotEmpty) ...[
                  const Text(
                    'Required Tasks',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary, fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: b.requestedTasks.take(4).map((t) => _TaskChip(t)).toList()
                      ..addAll(b.requestedTasks.length > 4
                          ? [_TaskChip('+${b.requestedTasks.length - 4} more', isMore: true)]
                          : []),
                  ),
                  const SizedBox(height: 12),
                ],

                // Notes
                if (b.jobDescription.isNotEmpty) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_outlined, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.jobDescription,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          // Action buttons: Chat | Reject | Accept
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                // Chat button
                OutlinedButton.icon(
                  onPressed: _viewChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat', style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
                ),
                const SizedBox(width: 8),
                // Reject button
                OutlinedButton.icon(
                  onPressed: (_isRejecting || _isAccepting) ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isRejecting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(color: AppColors.error, strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Skip', style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
                ),
                const SizedBox(width: 8),
                // Accept button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isAccepting || _isRejecting) ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isAccepting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isAccepting ? 'Accepting...' : 'Accept Job',
                      style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task chip ─────────────────────────────────────────────────────────────────

class _TaskChip extends StatelessWidget {
  final String label;
  final bool isMore;
  const _TaskChip(this.label, {this.isMore = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMore
            ? AppColors.textHint.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMore
              ? AppColors.textHint.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Poppins',
          color: isMore ? AppColors.textHint : AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

class _JobShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyJobState extends StatelessWidget {
  const _EmptyJobState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.work_off_outlined, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No jobs available',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New job requests will appear here.\nPull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary,
                fontFamily: 'Poppins', height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
