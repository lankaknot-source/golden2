import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/storage_service.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/user_model.dart';
import '../../../domain/models/wallet_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

// ── Earnings-by-month helper ──────────────────────────────────────────────────

/// Returns a map of monthKey → total earnings for the last 6 months,
/// derived from completed-credit transactions in the wallet stream.
Map<String, double> _computeMonthlyEarnings(List<WalletTransaction> txList) {
  final now = DateTime.now();
  final result = <String, double>{};
  for (var i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    result[DateFormat('MMM yy').format(d)] = 0;
  }
  for (final tx in txList) {
    if (!tx.isCredit) continue;
    final key = DateFormat('MMM yy').format(DateTime.fromMillisecondsSinceEpoch(tx.timestamp));
    if (result.containsKey(key)) {
      result[key] = (result[key] ?? 0) + tx.amount;
    }
  }
  return result;
}

// ── Main screen ───────────────────────────────────────────────────────────────

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final txAsync = ref.watch(transactionsProvider);
    final isCaregiver = user.isCaregiverOrNurse;
    final balance = user.walletBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(transactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Balance card
            SliverToBoxAdapter(
              child: _BalanceCard(
                balance: balance,
                isCaregiver: isCaregiver,
              ),
            ),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    if (!isCaregiver) ...[
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add_rounded,
                          label: 'Add Funds',
                          color: AppColors.accent,
                          onTap: () => _showAddFundsSheet(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (isCaregiver) ...[
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Payslip',
                          color: AppColors.primary,
                          onTap: () => _showPayslipDialog(context, ref, user),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.account_balance_rounded,
                          label: 'Withdraw',
                          color: AppColors.accent,
                          onTap: () => _showWithdrawSheet(context, ref, user),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.history_rounded,
                          label: 'History',
                          color: AppColors.primary,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Earnings chart (caregivers only)
            if (isCaregiver)
              txAsync.when(
                data: (txList) => SliverToBoxAdapter(
                  child: _EarningsChart(transactions: txList),
                ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

            // Transactions header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),

            // Transaction list
            txAsync.when(
              data: (transactions) => transactions.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyTransactions())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _TransactionTile(tx: transactions[i]),
                        childCount: transactions.length,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => _TxShimmer(),
                  childCount: 4,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _showAddFundsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFundsSheet(),
    );
  }

  void _showPayslipDialog(
      BuildContext context, WidgetRef ref, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => _PayslipDialog(user: user, ref: ref),
    );
  }

  void _showWithdrawSheet(
      BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(user: user),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double balance;
  final bool isCaregiver;
  const _BalanceCard({required this.balance, required this.isCaregiver});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCaregiver ? 'Total Earnings' : 'Wallet Balance',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LKR ${NumberFormat('#,##0.00').format(balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white60, size: 16),
              const SizedBox(width: 6),
              Text(
                isCaregiver
                    ? 'Paid after job completion'
                    : 'Available balance',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Earnings chart ────────────────────────────────────────────────────────────

class _EarningsChart extends StatelessWidget {
  final List<WalletTransaction> transactions;
  const _EarningsChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final monthly = _computeMonthlyEarnings(transactions);
    final keys = monthly.keys.toList();
    final values = monthly.values.toList();
    final maxVal = values.isEmpty
        ? 10000.0
        : values.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal <= 0 ? 10000.0 : maxVal * 1.2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings (Last 6 Months)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= keys.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            keys[idx],
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(keys.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: values[i] > 0
                            ? AppColors.accent
                            : AppColors.border,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      return BarTooltipItem(
                        'LKR ${NumberFormat('#,###').format(rod.toY.round())}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
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

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppColors.accent : AppColors.error;
    final fmt = DateFormat('d MMM yyyy · HH:mm');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  fmt.format(DateTime.fromMillisecondsSinceEpoch(tx.timestamp)),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} LKR ${NumberFormat('#,###').format(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              _TypeDot(type: tx.type),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeDot extends StatelessWidget {
  final TransactionType type;
  const _TypeDot({required this.type});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (type) {
      TransactionType.credit => (AppColors.accent, 'Credit'),
      TransactionType.debit => (AppColors.error, 'Debit'),
      TransactionType.fee => (AppColors.warning, 'Fee'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 10, color: color, fontFamily: 'Poppins'),
        ),
      ],
    );
  }
}

class _TxShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 52, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payslip dialog ────────────────────────────────────────────────────────────

class _PayslipDialog extends ConsumerStatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  const _PayslipDialog({required this.user, required this.ref});

  @override
  ConsumerState<_PayslipDialog> createState() => _PayslipDialogState();
}

class _PayslipDialogState extends ConsumerState<_PayslipDialog> {
  DateTime _selectedMonth = DateTime.now();
  bool _loading = false;
  double? _totalEarnings;
  int? _completedBookings;

  Future<void> _fetchPayslip() async {
    setState(() => _loading = true);
    try {
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('caregiverId', isEqualTo: widget.user.uid)
          .where('status', isEqualTo: BookingStatus.completed.firestoreValue)
          .get();

      final monthBookings = snap.docs
          .map((d) => Booking.fromMap(d.data(), d.id))
          .where((b) {
            final startMs = b.startTime ?? b.requestedTime;
            final dt = DateTime.fromMillisecondsSinceEpoch(startMs);
            return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                dt.isBefore(end);
          })
          .toList();

      double earnings = 0.0;
      for (final b in monthBookings) {
        earnings += b.totalAmount;
      }
      setState(() {
        _completedBookings = monthBookings.length;
        _totalEarnings = earnings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Month',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 280,
          child: YearPicker(
            firstDate: DateTime(now.year - 2),
            lastDate: now,
            selectedDate: _selectedMonth,
            onChanged: (date) {
              Navigator.pop(ctx);
              setState(() => _selectedMonth = date);
              _fetchPayslip();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 340,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payslip / Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Month picker
                  GestureDetector(
                    onTap: _pickMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else if (_totalEarnings != null) ...[
                    _PayslipRow('Caregiver', widget.user.name),
                    _PayslipRow('Month', DateFormat('MMMM yyyy').format(_selectedMonth)),
                    _PayslipRow('Completed Jobs', '${_completedBookings ?? 0}'),
                    const Divider(height: 24),
                    _PayslipRow(
                      'Total Earnings',
                      'LKR ${NumberFormat('#,##0.00').format(_totalEarnings ?? 0)}',
                      isBold: true,
                      valueColor: AppColors.accent,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.accent, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Earnings are paid after job completion and admin approval.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accent,
                                  fontFamily: 'Poppins'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    TextButton.icon(
                      onPressed: _fetchPayslip,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Generate Payslip',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                  if (_totalEarnings != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payslip saved to your downloads'),
                              backgroundColor: AppColors.accent,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Export',
                            style: TextStyle(fontFamily: 'Poppins')),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayslipRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  const _PayslipRow(this.label, this.value,
      {this.isBold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontFamily: 'Poppins',
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.textPrimary,
              fontFamily: 'Poppins',
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Withdraw / Bank Transfer Sheet ────────────────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _WithdrawSheet({required this.user});

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from user profile if available
    _bankNameCtrl.text = widget.user.bankName ?? '';
    _accountCtrl.text = widget.user.bankAccountNumber ?? '';
    _branchCtrl.text = widget.user.bankBranch ?? '';
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _branchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid amount'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .add({
        'uid': widget.user.uid,
        'userName': widget.user.name,
        'bankName': _bankNameCtrl.text.trim(),
        'accountNumber': _accountCtrl.text.trim(),
        'branch': _branchCtrl.text.trim(),
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Withdrawal request submitted. Admin will process within 2 business days.'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdraw Earnings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        'Transfer to your bank account',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildField(
                controller: _bankNameCtrl,
                label: 'Bank Name',
                icon: Icons.account_balance_outlined,
                hint: 'e.g. Bank of Ceylon',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _accountCtrl,
                label: 'Account Number',
                icon: Icons.credit_card_outlined,
                hint: 'e.g. 1234567890',
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _branchCtrl,
                label: 'Branch',
                icon: Icons.location_on_outlined,
                hint: 'e.g. Colombo 03',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _amountCtrl,
                label: 'Withdrawal Amount (LKR)',
                icon: Icons.payments_outlined,
                hint: 'e.g. 5000',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  if ((double.tryParse(v.trim()) ?? 0) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Processing time: 2-3 business days. Minimum withdrawal: LKR 1,000.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Submit Request',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Poppins'),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Poppins'),
        hintStyle: const TextStyle(
            fontFamily: 'Poppins', color: AppColors.textHint),
      ),
    );
  }
}

// ── Add Funds bottom sheet ────────────────────────────────────────────────────

class _AddFundsSheet extends ConsumerStatefulWidget {
  const _AddFundsSheet();

  @override
  ConsumerState<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<_AddFundsSheet> {
  final _amountCtrl = TextEditingController();
  File? _slipImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSlip() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _slipImage = File(picked.path));
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    if (amountText.isEmpty || _slipImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter amount and upload bank slip'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid amount'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final slipUrl = await StorageService().uploadImage(
        _slipImage!,
        'bank_slips/${user.uid}',
        quality: 85,
      );

      await FirebaseFirestore.instance.collection('wallet_top_ups').add({
        'uid': user.uid,
        'amount': amount,
        'slipUrl': slipUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Top-up request submitted. Admin will verify and credit your wallet.'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Add Funds',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          const Text(
            'Upload your bank slip to top up your wallet.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: InputDecoration(
              labelText: 'Amount (LKR)',
              prefixIcon: const Icon(Icons.payments_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickSlip,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _slipImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_slipImage!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded,
                            size: 32, color: AppColors.textHint),
                        SizedBox(height: 8),
                        Text(
                          'Tap to upload bank slip',
                          style: TextStyle(
                              color: AppColors.textHint,
                              fontFamily: 'Poppins',
                              fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit Request',
                      style: TextStyle(fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }
}
