import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _leaveRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('leave_requests')
      .where('caregiverId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  final List<DateTime> _selectedDates = [];
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (!_selectedDates.any((d) =>
        d.year == picked.year && d.month == picked.month && d.day == picked.day)) {
      setState(() => _selectedDates.add(picked));
    }
  }

  Future<void> _submit() async {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one leave date'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please provide a reason for leave'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final dates = _selectedDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList()..sort();

      await FirebaseFirestore.instance.collection('leave_requests').add({
        'caregiverId': user.uid,
        'caregiverName': user.name,
        'reason': _reasonCtrl.text.trim(),
        'dates': dates,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _selectedDates.clear();
          _reasonCtrl.clear();
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Leave request submitted successfully'),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(_leaveRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leave Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // New request form
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Request Leave',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  const SizedBox(height: 16),

                  // Selected dates
                  if (_selectedDates.isNotEmpty) ...[
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _selectedDates.map((d) {
                        return Chip(
                          label: Text(DateFormat('d MMM').format(d),
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => setState(() => _selectedDates.remove(d)),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          deleteIconColor: AppColors.primary,
                          labelStyle: const TextStyle(color: AppColors.primary),
                          side: const BorderSide(color: Colors.transparent),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: const Text('Add Date', style: TextStyle(fontFamily: 'Poppins')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'Poppins'),
                    decoration: InputDecoration(
                      labelText: 'Reason for leave',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Request', style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // History header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Previous Requests',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary, fontFamily: 'Poppins', letterSpacing: 0.3)),
            ),
          ),

          // Request list
          requestsAsync.when(
            data: (requests) => requests.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No leave requests yet',
                            style: TextStyle(color: AppColors.textHint, fontFamily: 'Poppins')),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _LeaveRequestTile(data: requests[i]),
                      childCount: requests.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _LeaveRequestTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LeaveRequestTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final dates = List<String>.from(data['dates'] as List? ?? []);
    final reason = data['reason'] as String? ?? '';

    final (color, icon) = switch (status) {
      'approved' => (AppColors.accent, Icons.check_circle_rounded),
      'rejected' => (AppColors.error, Icons.cancel_rounded),
      _ => (AppColors.warning, Icons.hourglass_top_rounded),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dates.length == 1 ? dates.first : '${dates.first} + ${dates.length - 1} more',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 2),
                Text(reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }
}
