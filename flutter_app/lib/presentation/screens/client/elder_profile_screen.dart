import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/elder_profile_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../domain/models/elder_profile_model.dart';
import '../../providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final elderProfileRepositoryProvider =
    Provider((_) => ElderProfileRepository());

final elderProfilesProvider =
    StreamProvider<List<ElderProfile>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(elderProfileRepositoryProvider)
      .streamClientProfiles(user.uid);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ElderProfileScreen extends ConsumerWidget {
  const ElderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(elderProfilesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Elders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Elder',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      ),
      body: profilesAsync.when(
        data: (profiles) => profiles.isEmpty
            ? _EmptyState(onAdd: () => _showAddEditSheet(context, ref))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(elderProfilesProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: profiles.length,
                  itemBuilder: (ctx, i) => _ElderCard(
                    profile: profiles[i],
                    onEdit: () => _showAddEditSheet(context, ref, profile: profiles[i]),
                    onDelete: () => _confirmDelete(context, ref, profiles[i]),
                    onMedicines: () => _showMedicinesSheet(context, ref, profiles[i]),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {ElderProfile? profile}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ElderFormSheet(existing: profile),
    );
  }

  void _showMedicinesSheet(BuildContext context, WidgetRef ref, ElderProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicineRemindersSheet(profile: profile),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ElderProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Elder Profile'),
        content: Text('Remove ${profile.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(elderProfileRepositoryProvider).deleteProfile(profile.id);
    }
  }
}

// ── Elder card ────────────────────────────────────────────────────────────────

class _ElderCard extends StatelessWidget {
  final ElderProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMedicines;

  const _ElderCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onMedicines,
  });

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    profile.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.primary, fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary, fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${profile.age} years · ${profile.gender}',
                        style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Poppins',
                        ),
                      ),
                      if (profile.medicalConditions.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          profile.medicalConditions.join(', '),
                          style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint, fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit();
                    } else if (v == 'medicines') {
                      onMedicines();
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'medicines',
                      child: Row(
                        children: [
                          Icon(Icons.medication_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Medicine Reminders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Medical conditions
          if (profile.medicalConditions.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ...profile.medicalConditions.take(3).map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _InfoChip(Icons.medical_services_outlined, c, AppColors.primary),
                        ),
                      ),
                ],
              ),
            ),
          ],
          // Medicine reminders pill
          if (profile.medicineList.isNotEmpty) ...[
            const Divider(height: 1),
            GestureDetector(
              onTap: onMedicines,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${profile.medicineList.length} medicine reminder${profile.medicineList.length > 1 ? 's' : ''}: '
                        '${profile.medicineList.take(2).map((r) => r.name).join(', ')}'
                        '${profile.medicineList.length > 2 ? '...' : ''}',
                        style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8B5CF6), fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ],
          // Emergency contact
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.emergency_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${profile.emergencyContactPerson} · ${profile.emergencyContact}',
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11, color: color,
              fontFamily: 'Poppins', fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medicine Reminders Sheet ───────────────────────────────────────────────────

class _MedicineRemindersSheet extends ConsumerStatefulWidget {
  final ElderProfile profile;
  const _MedicineRemindersSheet({required this.profile});

  @override
  ConsumerState<_MedicineRemindersSheet> createState() => _MedicineRemindersSheetState();
}

class _MedicineRemindersSheetState extends ConsumerState<_MedicineRemindersSheet> {
  late List<MedicineReminder> _reminders;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _reminders = List.from(widget.profile.medicineList);
    // Ensure existing reminders are (re)scheduled on this device.
    for (final r in _reminders) {
      _scheduleReminder(r);
    }
  }

  // Stable 31-bit notification id from the medicine UUID — deterministic across
  // app restarts so reminders can be overwritten / cancelled reliably.
  int _notifId(String medId) {
    var h = 0;
    for (final c in medId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  void _scheduleReminder(MedicineReminder med) {
    final parts = med.time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    NotificationService().scheduleDailyMedicine(
      id: _notifId(med.id),
      medicineName: med.name,
      elderName: widget.profile.name,
      hour: hour,
      minute: minute,
    );
  }

  Future<void> _addReminder() async {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medicine Name', style: TextStyle(fontFamily: 'Poppins')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Poppins'),
          decoration: const InputDecoration(
            labelText: 'Medicine name',
            prefixIcon: Icon(Icons.medication_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();

    if (name == null || name.isEmpty) return;

    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final reminder = MedicineReminder(
      id: const Uuid().v4(),
      time: formatted,
      name: name,
    );

    setState(() => _reminders.add(reminder));
    await _persist();
    _scheduleReminder(reminder);
  }

  Future<void> _deleteReminder(String id) async {
    NotificationService().cancelReminder(_notifId(id));
    setState(() => _reminders.removeWhere((r) => r.id == id));
    await _persist();
  }

  Future<void> _persist() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(elderProfileRepositoryProvider).updateProfile(
        widget.profile.id,
        {'medicineList': _reminders.map((r) => r.toMap()).toList()},
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
          Row(
            children: [
              const Icon(Icons.medication_rounded, color: Color(0xFF8B5CF6), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medicine Reminders – ${widget.profile.name}',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins', color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'A reminder notification will alert you on this device at each scheduled time.',
            style: TextStyle(fontSize: 11, color: AppColors.textHint, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: _reminders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No medicine reminders yet.\nTap + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, color: AppColors.textHint, fontFamily: 'Poppins', height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _reminders.length,
                    itemBuilder: (ctx, i) {
                      final r = _reminders[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.time,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Color(0xFF8B5CF6), fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary, fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: () => _deleteReminder(r.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _addReminder,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text(
                'Add Reminder',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add/Edit bottom sheet ─────────────────────────────────────────────────────

class _ElderFormSheet extends ConsumerStatefulWidget {
  final ElderProfile? existing;
  const _ElderFormSheet({this.existing});

  @override
  ConsumerState<_ElderFormSheet> createState() => _ElderFormSheetState();
}

class _ElderFormSheetState extends ConsumerState<_ElderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _medicalCtrl;
  late final TextEditingController _specialNeedsCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  String _gender = 'Male';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _ageCtrl = TextEditingController(text: e?.age.toString() ?? '');
    _medicalCtrl = TextEditingController(text: e?.medicalConditions.join(', ') ?? '');
    _specialNeedsCtrl = TextEditingController(text: e?.specialCareRequirements ?? '');
    _emergencyNameCtrl = TextEditingController(text: e?.emergencyContactPerson ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: e?.emergencyContact ?? '');
    _gender = e?.gender ?? 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _medicalCtrl.dispose();
    _specialNeedsCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider)!;
    setState(() => _isSaving = true);

    final repo = ref.read(elderProfileRepositoryProvider);
    try {
      final medList = _medicalCtrl.text.trim().isEmpty
          ? <String>[]
          : _medicalCtrl.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      if (widget.existing == null) {
        final profile = ElderProfile(
          id: const Uuid().v4(),
          clientId: user.uid,
          name: _nameCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
          gender: _gender,
          medicalConditions: medList,
          specialCareRequirements: _specialNeedsCtrl.text.trim(),
          emergencyContactPerson: _emergencyNameCtrl.text.trim(),
          emergencyContact: _emergencyPhoneCtrl.text.trim(),
        );
        await repo.addProfile(profile);
      } else {
        await repo.updateProfile(widget.existing!.id, {
          'name': _nameCtrl.text.trim(),
          'age': int.tryParse(_ageCtrl.text.trim()) ?? 0,
          'gender': _gender,
          'medicalConditions': medList,
          'specialCareRequirements': _specialNeedsCtrl.text.trim(),
          'emergencyContactPerson': _emergencyNameCtrl.text.trim(),
          'emergencyContact': _emergencyPhoneCtrl.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;

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
          Text(
            isEditing ? 'Edit Elder Profile' : 'Add Elder Profile',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              fontFamily: 'Poppins', color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            style: const TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _gender,
                            onChanged: (v) => setState(() => _gender = v!),
                            items: ['Male', 'Female', 'Other']
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g, style: const TextStyle(fontFamily: 'Poppins')),
                                    ))
                                .toList(),
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.wc_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _medicalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medical Conditions',
                        hintText: 'e.g. Diabetes, Hypertension',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specialNeedsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Special Care Requirements',
                        hintText: 'e.g. Wheelchair, oxygen support',
                        prefixIcon: Icon(Icons.accessibility_new_rounded),
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary, fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emergencyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        prefixIcon: Icon(Icons.emergency_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emergencyPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
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
                  : Text(isEditing ? 'Save Changes' : 'Add Elder'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: 20),
            const Text(
              'No elder profiles yet',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary, fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your loved one\'s profile to start\nbooking care services',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, color: AppColors.textHint,
                fontFamily: 'Poppins', height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Elder Profile'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
