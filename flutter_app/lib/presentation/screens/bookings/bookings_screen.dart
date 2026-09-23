import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/stored_image.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

double _computeHours(Booking b) {
  if (b.startTime == null) return b.estimatedHours.toDouble();
  final end = b.endTime ?? DateTime.now().millisecondsSinceEpoch;
  return ((end - b.startTime!) / (1000 * 60 * 60)).clamp(0.0, 24.0);
}

// ── Main screen ───────────────────────────────────────────────────────────────

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
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
        title: const Text('My Bookings',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isCaregiver)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New Booking',
              onPressed: () => context.push('/create-job'),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
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
          final active =
              bookings.where((b) => b.status == BookingStatus.inProgress).toList();
          final history = bookings
              .where((b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.rejected ||
                  b.status == BookingStatus.declined ||
                  b.status == BookingStatus.cancelled)
              .toList();

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _BookingList(
                  bookings: upcoming,
                  emptyMessage: 'No upcoming bookings',
                  user: user),
              _BookingList(
                  bookings: active,
                  emptyMessage: 'No active sessions right now',
                  user: user),
              _BookingList(
                  bookings: history,
                  emptyMessage: 'No completed bookings yet',
                  user: user),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load bookings',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(clientBookingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Booking list ──────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyMessage;
  final UserModel user;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded,
                size: 52, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) => _BookingCard(booking: bookings[i], user: user),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  final Booking booking;
  final UserModel user;
  const _BookingCard({required this.booking, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy');
    final (color, icon) = _statusStyle(booking.status);
    final isCaregiver = user.isCaregiverOrNurse;
    final hasAcceptedThisJob = booking.jobAcceptances
        .any((acceptance) => acceptance.caregiverId == user.uid);
    final canEnterStartCode = isCaregiver &&
        (booking.caregiverId == user.uid || hasAcceptedThisJob);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
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
                          Text(booking.elderId,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Poppins')),
                          const SizedBox(height: 3),
                          Text(
                            fmt.format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime)),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(booking.status),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontFamily: 'Poppins')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Address + amount
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(booking.address,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontFamily: 'Poppins'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                        'LKR ${NumberFormat('#,###').format(booking.totalAmount)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            fontFamily: 'Poppins')),
                  ],
                ),

                // Broadcast queue confirmation (shared with the Android
                // client). A primary caregiver confirms attendance before
                // the backend locks the job and issues the start code.
                if (isCaregiver) ...[
                  ...(() {
                    final own = booking.jobAcceptances
                        .where((a) => a.caregiverId == user.uid)
                        .toList();
                    if (own.isEmpty ||
                        own.first.confirmationStatus != 'PENDING' ||
                        !own.first.isPrimary) {
                      return <Widget>[];
                    }
                    return <Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(bookingRepositoryProvider)
                                  .confirmPreJobAttendance(
                                      booking.id, user.uid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Attendance confirmed.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not confirm: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.event_available_rounded),
                          label: const Text('Confirm attendance'),
                        ),
                      ),
                    ];
                  })(),
                ],

                // ── Start code section (accepted status) ──────────────────
                if ((!isCaregiver && booking.status == BookingStatus.accepted) ||
                    (canEnterStartCode &&
                        booking.status != BookingStatus.inProgress &&
                        booking.status != BookingStatus.completed &&
                        booking.status != BookingStatus.cancelled)) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (!isCaregiver)
                    _StartCodeClientView(booking: booking)
                  else
                    _StartCodeCaregiverEntry(
                        booking: booking, caregiverId: user.uid),
                ],

                // ── Active booking actions ────────────────────────────────
                if (booking.status == BookingStatus.inProgress) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/map/${booking.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(0, 36),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Track',
                              style: TextStyle(
                                  fontSize: 12, fontFamily: 'Poppins')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/care-log/${booking.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(0, 36),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.notes_rounded, size: 16),
                          label: const Text('Log',
                              style: TextStyle(
                                  fontSize: 12, fontFamily: 'Poppins')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Task proof upload (caregiver only)
                      if (isCaregiver)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showTaskProofSheet(context, booking),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded,
                                size: 16),
                            label: const Text('Proof',
                                style: TextStyle(
                                    fontSize: 12, fontFamily: 'Poppins')),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _EndJobSection(booking: booking, isCaregiver: isCaregiver),
                ],

                // ── Task approvals (client, active booking) ───────────────
                if (!isCaregiver &&
                    booking.status == BookingStatus.inProgress &&
                    booking.taskProofs.isNotEmpty)
                  _TaskProofsClientView(booking: booking),

                // ── Invoice (completed) ───────────────────────────────────
                if (booking.status == BookingStatus.completed) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showInvoiceDialog(context, booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.receipt_long_rounded,
                              size: 16),
                          label: const Text('View Invoice',
                              style: TextStyle(
                                  fontSize: 12, fontFamily: 'Poppins')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Report issue button (both roles)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showComplaintDialog(context, ref, booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Report Issue',
                              style: TextStyle(
                                  fontSize: 12, fontFamily: 'Poppins')),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Rate & review (completed, not yet rated, client only) ─
                if (!isCaregiver &&
                    booking.status == BookingStatus.completed &&
                    !booking.isRated &&
                    booking.caregiverId != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/rating/${booking.id}',
                          extra: booking.caregiverId),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Rate & Review',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskProofSheet(BuildContext context, Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskProofUploadSheet(booking: booking),
    );
  }

  // ── Invoice dialog ─────────────────────────────────────────────────────────

  void _showInvoiceDialog(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => _InvoiceDialog(booking: booking),
    );
  }

  // ── Complaint dialog ───────────────────────────────────────────────────────

  void _showComplaintDialog(
      BuildContext context, WidgetRef ref, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => _ComplaintDialog(booking: booking),
    );
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  (Color, IconData) _statusStyle(BookingStatus s) => switch (s) {
        BookingStatus.pending =>
          (AppColors.statusPending, Icons.schedule_rounded),
        BookingStatus.broadcasted =>
          (AppColors.warning, Icons.broadcast_on_personal_rounded),
        BookingStatus.broadcastAccepted =>
          (AppColors.warning, Icons.how_to_reg_rounded),
        BookingStatus.accepted =>
          (AppColors.statusActive, Icons.check_circle_outline_rounded),
        BookingStatus.inProgress => (AppColors.accent, Icons.favorite_rounded),
        BookingStatus.completed =>
          (AppColors.statusCompleted, Icons.task_alt_rounded),
        BookingStatus.cancelled =>
          (AppColors.statusCancelled, Icons.cancel_outlined),
        BookingStatus.rejected =>
          (AppColors.error, Icons.do_not_disturb_on_outlined),
        BookingStatus.declined =>
          (AppColors.error, Icons.thumb_down_outlined),
      };

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'Pending',
        BookingStatus.broadcasted => 'Broadcasted',
        BookingStatus.broadcastAccepted => 'Awaiting confirmation',
        BookingStatus.accepted => 'Accepted',
        BookingStatus.inProgress => 'Active',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.declined => 'Declined',
      };
}

// ── Invoice dialog ────────────────────────────────────────────────────────────

class _InvoiceDialog extends StatelessWidget {
  final Booking booking;
  const _InvoiceDialog({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fmtDate = DateFormat('d MMM yyyy');
    final fmtDateTime = DateFormat('d MMM yyyy, HH:mm');
    final hours = _computeHours(b);
    // Derive rate: totalAmount / hours (avoid division by zero)
    final rate = hours > 0 ? b.totalAmount / hours : 0.0;
    final moneyFmt = NumberFormat('#,##0.00');
    final intFmt = NumberFormat('#,###');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'INVOICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PAID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ref: #${b.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Elder & dates
                  _InvoiceRow(
                    label: 'Elder / Patient',
                    value: b.elderId,
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  _InvoiceRow(
                    label: 'Service Date',
                    value: fmtDate.format(DateTime.fromMillisecondsSinceEpoch(b.requestedTime)),
                  ),
                  if (b.startTime != null) ...[
                    const SizedBox(height: 8),
                    _InvoiceRow(
                      label: 'Job Started',
                      value: fmtDateTime.format(DateTime.fromMillisecondsSinceEpoch(b.startTime!)),
                    ),
                  ],
                  if (b.endTime != null) ...[
                    const SizedBox(height: 8),
                    _InvoiceRow(
                      label: 'Job Ended',
                      value: fmtDateTime.format(DateTime.fromMillisecondsSinceEpoch(b.endTime!)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InvoiceRow(
                    label: 'Address',
                    value: b.address,
                  ),
                  if (b.careCategory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InvoiceRow(
                      label: 'Care Category',
                      value: b.careCategory,
                    ),
                  ],
                  const Divider(height: 24),

                  // Billing breakdown
                  _InvoiceRow(
                    label: 'Duration',
                    value: '${hours.toStringAsFixed(1)} hours',
                  ),
                  const SizedBox(height: 8),
                  _InvoiceRow(
                    label: 'Hourly Rate',
                    value: 'LKR ${moneyFmt.format(rate)}',
                  ),
                  const Divider(height: 24),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'LKR ${intFmt.format(b.totalAmount)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tasks completed
                  if (b.completedTasks.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tasks Completed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: b.completedTasks
                          .map((t) => Chip(
                                label: Text(t,
                                    style: const TextStyle(
                                        fontSize: 11, fontFamily: 'Poppins')),
                                backgroundColor:
                                    AppColors.accent.withValues(alpha: 0.1),
                                side: BorderSide(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.3)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _InvoiceRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins')),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      ],
    );
  }
}

// ── Complaint dialog ──────────────────────────────────────────────────────────

class _ComplaintDialog extends ConsumerStatefulWidget {
  final Booking booking;
  const _ComplaintDialog({required this.booking});

  @override
  ConsumerState<_ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends ConsumerState<_ComplaintDialog> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      // Save to Firestore — update the booking's complaintNote and set status disputed
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .update({
        'complaintNote': text,
        'status': BookingStatus.cancelled.name,
      });
      // Also create a dedicated complaint document
      await FirebaseFirestore.instance.collection('complaints').add({
        'bookingId': widget.booking.id,
        'clientId': widget.booking.clientId,
        'caregiverId': widget.booking.caregiverId,
        'elderName': widget.booking.elderId,
        'note': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Report submitted. Our team will review shortly.',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.flag_outlined, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Report an Issue',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe the issue with this booking for ${widget.booking.elderId}.',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe what happened...',
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontFamily: 'Poppins'),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Submit',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Start code — client view ───────────────────────────────────────────────────

class _StartCodeClientView extends ConsumerWidget {
  final Booking booking;
  const _StartCodeClientView({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (booking.startCode == null) {
      return ElevatedButton.icon(
        onPressed: () async {
          final code = await ref
              .read(bookingNotifierProvider.notifier)
              .generateStartCode(booking.id);
          if (context.mounted && code != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Start code generated: $code',
                  style: const TextStyle(fontFamily: 'Poppins')),
              backgroundColor: AppColors.accent,
            ));
          }
        },
        icon: const Icon(Icons.lock_open_rounded, size: 18),
        label: const Text('Generate Start Code',
            style: TextStyle(fontFamily: 'Poppins')),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start Code (share with caregiver)',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins')),
                Text(
                  booking.startCode!,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Poppins',
                      letterSpacing: 8),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: booking.startCode!));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Code copied to clipboard',
                    style: TextStyle(fontFamily: 'Poppins')),
                duration: Duration(seconds: 2),
              ));
            },
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Start code — caregiver OTP dialog entry ───────────────────────────────────

class _StartCodeCaregiverEntry extends ConsumerStatefulWidget {
  final Booking booking;
  final String caregiverId;
  const _StartCodeCaregiverEntry({
    required this.booking,
    required this.caregiverId,
  });

  @override
  ConsumerState<_StartCodeCaregiverEntry> createState() =>
      _StartCodeCaregiverEntryState();
}

class _StartCodeCaregiverEntryState
    extends ConsumerState<_StartCodeCaregiverEntry> {
  bool _loading = false;

  void _openOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OtpDialog(
        onSubmit: (code) async {
          Navigator.pop(ctx);
          setState(() => _loading = true);
          final ok = await ref
              .read(bookingNotifierProvider.notifier)
              .verifyAndStartJob(widget.booking.id, code);
          if (ok) {
            // Start immediately after the client code is verified. The global
            // Riverpod watcher also keeps this alive after the booking stream
            // refreshes, while this call avoids waiting for that refresh
            // before the first location permission prompt/fix.
            try {
              await LocationTrackingService()
                  .startForCaregiver(widget.caregiverId);
            } catch (_) {
              // A denied location prompt must not undo a successfully started
              // job. The provider will retry when permissions are enabled.
            }
          }
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                ok ? 'Job started successfully!' : 'Invalid code. Try again.',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: ok ? AppColors.accent : AppColors.error,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _openOtpDialog,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.play_circle_outline_rounded, size: 18),
        label: Text(
          _loading ? 'Verifying...' : 'Enter Start Code',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}

// ── 4-digit OTP dialog ────────────────────────────────────────────────────────

class _OtpDialog extends StatefulWidget {
  final Future<void> Function(String code) onSubmit;
  const _OtpDialog({required this.onSubmit});

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _submit() async {
    final code = _code;
    if (code.length < 4) return;
    setState(() => _submitting = true);
    await widget.onSubmit(code);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_open_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter Start Code',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask the client for the 4-digit code\nto begin the session.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
                height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          return SizedBox(
            width: 52,
            height: 60,
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: AppColors.primary),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.primary.withValues(alpha: 0.04),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (val) {
                if (val.isNotEmpty && i < 3) {
                  _focusNodes[i + 1].requestFocus();
                } else if (val.isEmpty && i > 0) {
                  _focusNodes[i - 1].requestFocus();
                }
                setState(() {});
                if (_code.length == 4) _submit();
              },
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(
                  fontFamily: 'Poppins', color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: (_code.length < 4 || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Start Job',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: Colors.white)),
        ),
      ],
    );
  }
}

// ── End job section ───────────────────────────────────────────────────────────

class _EndJobSection extends ConsumerWidget {
  final Booking booking;
  final bool isCaregiver;
  const _EndJobSection({required this.booking, required this.isCaregiver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isCaregiver) {
      // Client side
      if (booking.isClientEnded) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'End request sent — waiting for caregiver confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontFamily: 'Poppins'),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmEndJob(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            minimumSize: const Size(double.infinity, 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('End Job',
              style: TextStyle(fontFamily: 'Poppins')),
        ),
      );
    }

    // Caregiver side — show "Accept End" if client has ended
    if (booking.isClientEnded && !booking.isCaregiverAcceptedEnd) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await ref
                .read(bookingNotifierProvider.notifier)
                .caregiverAcceptEnd(booking.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Job completed successfully!',
                    style: TextStyle(fontFamily: 'Poppins')),
                backgroundColor: AppColors.accent,
              ));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size(double.infinity, 40),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Accept Job End',
              style: TextStyle(fontFamily: 'Poppins')),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _confirmEndJob(BuildContext context, WidgetRef ref) {
    final b = booking;
    final completedCount = b.completedTasks.length;
    final totalCount = b.requestedTasks.length;
    final pendingTasks = b.requestedTasks
        .where((t) => !b.completedTasks.contains(t))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Job?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will notify the caregiver that the session is ending. They must confirm to complete.',
              style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
            ),
            if (totalCount > 0) ...[
              const SizedBox(height: 14),
              const Text(
                'Task Summary',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              // Completed tasks
              ...b.completedTasks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  )),
              // Pending tasks
              ...pendingTasks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.radio_button_unchecked,
                            color: AppColors.textHint, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: completedCount == totalCount
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completedCount of $totalCount tasks completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: completedCount == totalCount
                        ? AppColors.accent
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(bookingNotifierProvider.notifier)
                  .clientEndJob(booking.id);
            },
            child: const Text('Confirm End',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Task proofs — client approval view ───────────────────────────────────────

class _TaskProofsClientView extends ConsumerWidget {
  final Booking booking;
  const _TaskProofsClientView({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Task Proofs',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins')),
        const SizedBox(height: 8),
        ...booking.taskProofs.map((proof) {
          final approved =
              booking.clientApprovedTasks.contains(proof.taskName);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      approved ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _viewPhoto(context, proof.photoUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: proof.photoUrl.startsWith('data:')
                        ? Image.memory(
                            Uri.parse(proof.photoUrl).data!.contentAsBytes(),
                            width: 52, height: 52, fit: BoxFit.cover)
                        : proof.photoUrl.isNotEmpty
                            ? Image(image: storedImageProvider(proof.photoUrl),
                                width: 52, height: 52, fit: BoxFit.cover)
                            : Container(
                                width: 52, height: 52,
                                color: AppColors.background,
                                child: const Icon(Icons.image_not_supported_outlined, size: 24)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(proof.taskName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                              color: AppColors.textPrimary)),
                      Text(DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(proof.timestamp)),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'Poppins')),
                    ],
                  ),
                ),
                if (!approved)
                  TextButton(
                    onPressed: () => ref
                        .read(bookingNotifierProvider.notifier)
                        .approveTask(booking.id, proof.taskName),
                    child: const Text('Approve',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12)),
                  )
                else
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.accent, size: 22),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _viewPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(image: storedImageProvider(url)),
        ),
      ),
    );
  }
}

// ── Task proof upload sheet (caregiver) ───────────────────────────────────────

class _TaskProofUploadSheet extends ConsumerStatefulWidget {
  final Booking booking;
  const _TaskProofUploadSheet({required this.booking});

  @override
  ConsumerState<_TaskProofUploadSheet> createState() =>
      _TaskProofUploadSheetState();
}

class _TaskProofUploadSheetState
    extends ConsumerState<_TaskProofUploadSheet> {
  String? _selectedTask;
  File? _selectedImage;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _upload() async {
    if (_selectedTask == null || _selectedImage == null) return;
    setState(() => _uploading = true);
    try {
      final uid = ref.read(currentUserProvider)?.uid ?? 'unknown';
      final url = await StorageService().uploadImage(
        _selectedImage!,
        'task_proofs/${widget.booking.id}/$uid',
      );
      final proof = TaskProofEntry(
        taskName: _selectedTask!,
        photoUrl: url,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await ref
          .read(bookingNotifierProvider.notifier)
          .addTaskProof(widget.booking.id, proof);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task proof uploaded!',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.booking.requestedTasks;
    // Tasks already have proof uploaded
    final proofedTasks =
        widget.booking.taskProofs.map((p) => p.taskName).toSet();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          const Text('Upload Task Proof',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          const Text(
            'Take a photo to document task completion.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),

          // Task selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _selectedTask,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Select Task',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textHint)),
              items: tasks.map((t) {
                final done = proofedTasks.contains(t);
                return DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: done ? AppColors.accent : AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Text(t,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: done
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: done ? TextDecoration.lineThrough : null,
                          )),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedTask = v),
            ),
          ),
          const SizedBox(height: 16),

          // Photo picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.border, style: BorderStyle.solid),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded,
                            size: 36, color: AppColors.textHint),
                        SizedBox(height: 8),
                        Text('Tap to take a photo',
                            style: TextStyle(
                                color: AppColors.textHint,
                                fontFamily: 'Poppins')),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_selectedTask == null ||
                      _selectedImage == null ||
                      _uploading)
                  ? null
                  : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Upload Proof',
                      style: TextStyle(fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }
}
