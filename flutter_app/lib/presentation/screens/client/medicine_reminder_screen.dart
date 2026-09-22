import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/elder_profile_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../domain/models/elder_profile_model.dart';

final _elderRepoProvider =
    Provider<ElderProfileRepository>((_) => ElderProfileRepository());

// Matches care2: medicines stored in elders/{elderId}.medicineList
class MedicineReminderScreen extends ConsumerStatefulWidget {
  final String elderId;
  const MedicineReminderScreen({super.key, required this.elderId});

  @override
  ConsumerState<MedicineReminderScreen> createState() =>
      _MedicineReminderScreenState();
}

class _MedicineReminderScreenState
    extends ConsumerState<MedicineReminderScreen> {
  List<MedicineReminder>? _medicines;
  bool _isLoading = true;
  String _elderName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref
        .read(_elderRepoProvider)
        .getProfile(widget.elderId);
    if (mounted) {
      setState(() {
        _elderName = profile?.name ?? '';
        _medicines = profile?.medicineList ?? [];
        _isLoading = false;
      });
      _rescheduleAll(_medicines!);
    }
  }

  Future<void> _saveList(List<MedicineReminder> list) async {
    await ref
        .read(_elderRepoProvider)
        .updateMedicineList(widget.elderId, list);
    if (mounted) setState(() => _medicines = list);
    _rescheduleAll(list);
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

  void _rescheduleAll(List<MedicineReminder> list) {
    final notif = NotificationService();
    for (final med in list) {
      final parts = med.time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      notif.scheduleDailyMedicine(
        id: _notifId(med.id),
        medicineName: med.name,
        elderName: _elderName,
        hour: hour,
        minute: minute,
      );
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedicineSheet(
        onSave: (med) {
          final updated = [...(_medicines ?? []), med];
          _saveList(updated);
        },
      ),
    );
  }

  void _delete(MedicineReminder med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medicine?',
            style: TextStyle(fontFamily: 'Poppins')),
        content: Text('Remove ${med.name} from reminders?',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              NotificationService().cancelReminder(_notifId(med.id));
              final updated = (_medicines ?? [])
                  .where((m) => m.id != med.id)
                  .toList();
              _saveList(updated);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Medicine Reminders',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Medicine',
            style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_medicines == null || _medicines!.isEmpty)
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _medicines!.length,
                  itemBuilder: (ctx, i) => _MedicineCard(
                    medicine: _medicines![i],
                    onDelete: () => _delete(_medicines![i]),
                  ),
                ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineReminder medicine;
  final VoidCallback onDelete;

  const _MedicineCard({required this.medicine, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget photoWidget;
    if (medicine.photoBase64.isNotEmpty) {
      final clean = medicine.photoBase64.contains(',')
          ? medicine.photoBase64.split(',').last
          : medicine.photoBase64;
      final bytes = base64Decode(clean);
      photoWidget = Image.memory(bytes, fit: BoxFit.cover);
    } else {
      photoWidget = const Icon(Icons.medication_rounded,
          color: AppColors.primary, size: 28);
    }

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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          clipBehavior: Clip.antiAlias,
          child: photoWidget,
        ),
        title: Text(
          medicine.name,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins'),
        ),
        subtitle: Text(
          'Time: ${medicine.time}',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Poppins'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 64, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'No medicines added',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: AppColors.textPrimary),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the button below to add a medicine reminder.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

// Sheet to add a new medicine (matches care2 fields)
class _AddMedicineSheet extends StatefulWidget {
  final ValueChanged<MedicineReminder> onSave;
  const _AddMedicineSheet({required this.onSave});

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _nameCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  File? _photoFile;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 400);
    if (xfile != null) setState(() => _photoFile = File(xfile.path));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Camera', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Gallery', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medicine name.')),
      );
      return;
    }
    setState(() => _isSaving = true);

    String base64Photo = '';
    if (_photoFile != null) {
      final bytes = await _photoFile!.readAsBytes();
      base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final med = MedicineReminder(
      id: const Uuid().v4(),
      time: _fmtTime(_time),
      name: name,
      photoBase64: base64Photo,
    );

    widget.onSave(med);
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add Medicine',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Medicine Name',
              prefixIcon: Icon(Icons.medication_outlined),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_rounded, color: AppColors.primary),
            title: Text(
              'Time: ${_fmtTime(_time)}',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            onTap: _pickTime,
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photoFile != null
                  ? Image.file(_photoFile!, fit: BoxFit.cover)
                  : const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            ),
            title: const Text('Medicine Photo (optional)',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: _showPhotoOptions,
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Save',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
