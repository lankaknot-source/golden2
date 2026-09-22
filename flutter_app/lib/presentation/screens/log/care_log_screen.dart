import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/care_log_repository.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/daily_care_log_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final careLogRepositoryProvider = Provider((_) => CareLogRepository());

final careLogsProvider =
    StreamProvider.family<List<DailyCareLog>, String>((ref, bookingId) {
  return ref.watch(careLogRepositoryProvider).streamBookingLogs(bookingId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CareLogScreen extends ConsumerWidget {
  final String bookingId;
  const CareLogScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    final logsAsync = ref.watch(careLogsProvider(bookingId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Care Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          logsAsync.when(
            data: (logs) => logs.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export PDF',
                    onPressed: () => _exportPdf(context, bookingAsync.value, logs),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: user.isCaregiverOrNurse
          ? FloatingActionButton.extended(
              onPressed: () => _showAddLogSheet(context, ref, bookingId, user.uid),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Log',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              ),
            )
          : null,
      body: Column(
        children: [
          bookingAsync.when(
            data: (booking) => _BookingHeader(booking: booking),
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) => logs.isEmpty
                  ? _EmptyState(isCaregiver: user.isCaregiverOrNurse)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: logs.length,
                      itemBuilder: (ctx, i) => _CareLogCard(log: logs[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLogSheet(BuildContext context, WidgetRef ref, String bookingId, String caregiverId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLogSheet(bookingId: bookingId, caregiverId: caregiverId),
    );
  }

  Future<void> _exportPdf(BuildContext context, Booking? booking, List<DailyCareLog> logs) async {
    try {
      final pdf = pw.Document();
      final fmt = DateFormat('d MMM yyyy');
      final timeFmt = DateFormat('HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GOLDEN HAND CAREGIVERS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0D3B66'),
                    ),
                  ),
                  pw.Text(
                    'Daily Care Log Report',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Divider(color: PdfColor.fromHex('#0D3B66'), thickness: 1.5),
              pw.SizedBox(height: 4),
              if (booking != null) ...[
                pw.Text(
                  'Elder ID: ${booking.elderId}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Location: ${booking.address}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Period: ${fmt.format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime))}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
              ],
            ],
          ),
          build: (ctx) => logs.map((log) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        fmt.format(DateTime.fromMillisecondsSinceEpoch(log.timestamp)),
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Recorded: ${timeFmt.format(DateTime.fromMillisecondsSinceEpoch(log.timestamp))}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  pw.SizedBox(height: 4),
                  // Vitals row
                  if (log.bloodPressure.isNotEmpty || log.temperature.isNotEmpty || log.sugarLevel.isNotEmpty)
                    pw.Row(
                      children: [
                        if (log.bloodPressure.isNotEmpty)
                          _pdfVitalChip('BP', log.bloodPressure),
                        if (log.temperature.isNotEmpty)
                          _pdfVitalChip('Temp', log.temperature),
                        if (log.sugarLevel.isNotEmpty)
                          _pdfVitalChip('Sugar', log.sugarLevel),
                      ],
                    ),
                  if (log.mealStatus.isNotEmpty)
                    _pdfRow('Meal Status', log.mealStatus),
                  _pdfRow('Medication Given', log.medicationGiven ? 'Yes' : 'No'),
                  _pdfRow('Medication Given', log.medicationGiven ? 'Yes' : 'No'),
                  if (log.notes.isNotEmpty) _pdfRow('Notes', log.notes),
                ],
              ),
            );
          }).toList(),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'care_log_${booking?.elderId ?? 'report'}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfVitalChip(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 8, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E8F4FD'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColor.fromHex('#90CAF9')),
      ),
      child: pw.Text(
        '$label: $value',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D3B66')),
      ),
    );
  }
}

// ── Booking header ────────────────────────────────────────────────────────────

class _BookingHeader extends StatelessWidget {
  final Booking booking;
  const _BookingHeader({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elder: ${booking.elderId}',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary, fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(booking.requestedTime)),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          _StatusBadge(status: booking.status),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      BookingStatus.inProgress => (AppColors.accent, 'Active'),
      BookingStatus.completed => (AppColors.statusCompleted, 'Done'),
      BookingStatus.pending => (AppColors.statusPending, 'Pending'),
      BookingStatus.accepted => (AppColors.statusActive, 'Accepted'),
      _ => (AppColors.textSecondary, 'Other'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: color, fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ── Care log card ─────────────────────────────────────────────────────────────

class _CareLogCard extends StatelessWidget {
  final DailyCareLog log;
  const _CareLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.assignment_outlined, color: AppColors.accent, size: 20),
        ),
        title: Text(
          DateFormat('EEEE, d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(log.timestamp)),
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary, fontFamily: 'Poppins',
          ),
        ),
        subtitle: Text(
          DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(log.timestamp)),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Vitals row
          if (log.bloodPressure.isNotEmpty || log.temperature.isNotEmpty || log.sugarLevel.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (log.bloodPressure.isNotEmpty)
                  _VitalChip(Icons.favorite_outline_rounded, 'BP', log.bloodPressure, AppColors.error),
                if (log.temperature.isNotEmpty)
                  _VitalChip(Icons.thermostat_outlined, 'Temp', log.temperature, AppColors.warning),
                if (log.sugarLevel.isNotEmpty)
                  _VitalChip(Icons.water_drop_outlined, 'Sugar', log.sugarLevel, const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Meal & medication
          if (log.mealStatus.isNotEmpty)
            _LogRow(Icons.restaurant_menu_rounded, 'Meal Status', log.mealStatus),
          _LogRow(
            log.medicationGiven ? Icons.check_circle_rounded : Icons.cancel_rounded,
            'Medication Given',
            log.medicationGiven ? 'Yes' : 'No',
            valueColor: log.medicationGiven ? AppColors.accent : AppColors.error,
          ),
          if (log.notes.isNotEmpty)
            _LogRow(Icons.note_outlined, 'Notes', log.notes),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _VitalChip(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9, color: color.withValues(alpha: 0.8),
                  fontFamily: 'Poppins', fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12, color: color,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _LogRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary, fontFamily: 'Poppins',
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add log bottom sheet ──────────────────────────────────────────────────────

class _AddLogSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String caregiverId;
  const _AddLogSheet({required this.bookingId, required this.caregiverId});

  @override
  ConsumerState<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends ConsumerState<_AddLogSheet> {
  // Health vitals
  final _bpCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  bool _medicationGiven = false;
  String _mealStatus = 'Good';

  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _bpCtrl.dispose();
    _tempCtrl.dispose();
    _sugarCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final booking = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
    final log = DailyCareLog(
      id: const Uuid().v4(),
      bookingId: widget.bookingId,
      caregiverId: widget.caregiverId,
      elderId: booking?.elderId ?? '',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      bloodPressure: _bpCtrl.text.trim(),
      temperature: _tempCtrl.text.trim(),
      sugarLevel: _sugarCtrl.text.trim(),
      medicationGiven: _medicationGiven,
      mealStatus: _mealStatus,
      notes: _notesCtrl.text.trim(),
    );
    await ref.read(careLogRepositoryProvider).addLog(log);
    if (mounted) Navigator.pop(context);
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Care Log',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              fontFamily: 'Poppins', color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Health Vitals section ──────────────────────────────
                  _SectionLabel('Health Vitals', Icons.monitor_heart_outlined, AppColors.error),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LogField('Blood Pressure', Icons.favorite_outline_rounded, _bpCtrl,
                            hint: '120/80'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LogField('Temperature', Icons.thermostat_outlined, _tempCtrl,
                            hint: '98.6°F'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _LogField('Sugar Level', Icons.water_drop_outlined, _sugarCtrl, hint: '120 mg/dL'),
                  const SizedBox(height: 10),

                  // Medication given
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      value: _medicationGiven,
                      onChanged: (v) => setState(() => _medicationGiven = v),
                      activeThumbColor: AppColors.accent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: const Text(
                        'Medication Given',
                        style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
                      ),
                      secondary: Icon(
                        Icons.medication_rounded,
                        color: _medicationGiven ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Meal status
                  _DropdownField(
                    label: 'Meal Status',
                    value: _mealStatus,
                    options: const ['Good', 'Poor', 'Refused'],
                    onChanged: (v) => setState(() => _mealStatus = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Notes section ──────────────────────────────────────
                  _SectionLabel('General Notes', Icons.assignment_outlined, AppColors.primary),
                  const SizedBox(height: 8),
                  _LogField('Notes', Icons.note_outlined, _notesCtrl, maxLines: 3),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Save Log'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: color, fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _LogField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final int maxLines;
  final String? hint;
  const _LogField(this.label, this.icon, this.controller,
      {this.maxLines = 1, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      onChanged: (v) => onChanged(v!),
      items: options
          .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              ))
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isCaregiver;
  const _EmptyState({required this.isCaregiver});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No care logs yet',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCaregiver ? 'Add your first daily log' : 'Logs will appear here',
            style: const TextStyle(fontSize: 13, color: AppColors.textHint, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}
