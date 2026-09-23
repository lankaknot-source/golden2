import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/elder_profile_repository.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/elder_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _elderProfileRepoProvider = Provider((_) => ElderProfileRepository());

final _elderProfilesProvider =
    FutureProvider.family<List<ElderProfile>, String>(
  (ref, clientId) =>
      ref.watch(_elderProfileRepoProvider).getClientProfiles(clientId),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateJobScreen extends ConsumerStatefulWidget {
  final String? preselectedCaregiverId;
  const CreateJobScreen({super.key, this.preselectedCaregiverId});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  ElderProfile? _selectedElder;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1500');
  final _customTaskCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _fetchingLocation = false;

  // Care category
  String _careCategory = 'Elderly Care';
  static const _careCategories = [
    'Elderly Care',
    'Patient Care',
    'Baby Care',
    'Special Needs',
    'Post-Surgery',
    'Palliative Care',
  ];

  // Service type
  String _serviceType = 'Live-out';
  static const _serviceTypes = ['Live-out', 'Live-in'];

  // Duration type
  String _durationType = 'Short-term';
  static const _durationTypes = ['Short-term', 'Long-term'];

  // Tasks
  final List<String> _defaultTasks = [
    'Bathing & Hygiene',
    'Meal Preparation',
    'Medication Reminders',
    'Physical Therapy',
    'Companionship',
    'Light Housekeeping',
    'Transportation',
    'Doctor Visits',
  ];
  final List<String> _customTasks = [];
  final Set<String> _selectedTasks = {};

  bool _isEmergency = false;
  bool _broadcastToAll = true;
  bool _isSubmitting = false;

  List<String> get _allTasks => [..._defaultTasks, ..._customTasks];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _rateCtrl.dispose();
    _customTaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Location services are disabled');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack('Location permission denied');
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressCtrl.text =
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}';
      });
      _snack('Location captured!', success: true);
    } catch (e) {
      _snack('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _addCustomTask() {
    final task = _customTaskCtrl.text.trim();
    if (task.isEmpty) return;
    setState(() {
      _customTasks.add(task);
      _selectedTasks.add(task);
      _customTaskCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_selectedElder == null) {
      _snack('Please select an elder profile');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTasks.isEmpty) {
      _snack('Please select at least one required task');
      return;
    }

    final user = ref.read(currentUserProvider)!;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final startHours = _startTime.hour + _startTime.minute / 60;
    final endHours = _endTime.hour + _endTime.minute / 60;
    final hours = (endHours - startHours).clamp(0, 24).toDouble();
    final total = rate * hours;

    final address = _addressCtrl.text.trim().isEmpty
        ? ''
        : _addressCtrl.text.trim();

    final now = DateTime.now().millisecondsSinceEpoch;
    final startDt = DateTime(
      _startDate.year, _startDate.month, _startDate.day,
      _startTime.hour, _startTime.minute,
    );
    final endDt = DateTime(
      _endDate.year, _endDate.month, _endDate.day,
      _endTime.hour, _endTime.minute,
    );

    final booking = Booking(
      id: const Uuid().v4(),
      clientId: user.uid,
      caregiverId: _broadcastToAll ? null : widget.preselectedCaregiverId,
      elderId: _selectedElder!.id,
      address: address,
      locationLat: _lat ?? 0.0,
      locationLng: _lng ?? 0.0,
      requestedTime: now,
      scheduledTime: startDt.millisecondsSinceEpoch,
      startTime: startDt.millisecondsSinceEpoch,
      endTime: endDt.millisecondsSinceEpoch,
      totalAmount: total,
      hourlyRate: rate,
      estimatedHours: hours.round(),
      requestedTasks: _selectedTasks.toList(),
      jobDescription: _notesCtrl.text.trim(),
      isEmergency: _isEmergency,
      careCategory: _careCategory,
      serviceType: _serviceType,
      durationType: _durationType,
      status: _broadcastToAll
          ? BookingStatus.broadcasted
          : BookingStatus.pending,
    );

    setState(() => _isSubmitting = true);
    final id =
        await ref.read(bookingNotifierProvider.notifier).createBooking(booking);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (id != null) {
      _snack('Job posted successfully!', success: true);
      context.pop();
    } else {
      _snack('Failed to post job. Please try again.');
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: success ? AppColors.accent : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final eldersAsync = ref.watch(_elderProfilesProvider(user.uid));
    final fmt = DateFormat('EEE, d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post a Job'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Emergency + Broadcast ─────────────────────────────────────
            _Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _isEmergency,
                    onChanged: (v) => setState(() => _isEmergency = v),
                    title: const Text('Emergency / SOS Request',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins')),
                    subtitle: const Text('High priority – notify all caregivers',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins')),
                    activeThumbColor: AppColors.error,
                    secondary: Icon(Icons.emergency_rounded,
                        color: _isEmergency
                            ? AppColors.error
                            : AppColors.textSecondary),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _broadcastToAll,
                    onChanged: (v) => setState(() => _broadcastToAll = v),
                    title: const Text('Broadcast to All Caregivers',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins')),
                    subtitle: const Text(
                        'Let any available caregiver apply',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins')),
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(Icons.broadcast_on_personal_rounded,
                        color: AppColors.primary),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Care category ─────────────────────────────────────────────
            _SectionTitle('Care Category'),
            const SizedBox(height: 8),
            _Card(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _careCategories.map((cat) {
                  final sel = _careCategory == cat;
                  return ChoiceChip(
                    label: Text(cat,
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            color: sel
                                ? Colors.white
                                : AppColors.textPrimary)),
                    selected: sel,
                    onSelected: (_) =>
                        setState(() => _careCategory = cat),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                    side: BorderSide(
                        color: sel
                            ? AppColors.primary
                            : AppColors.border),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Service + Duration type ───────────────────────────────────
            _SectionTitle('Service & Duration Type'),
            const SizedBox(height: 8),
            _Card(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Service Type',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'Poppins')),
                        const SizedBox(height: 6),
                        RadioGroup<String>(
                          groupValue: _serviceType,
                          onChanged: (v) =>
                              setState(() => _serviceType = v!),
                          child: Column(
                            children: _serviceTypes
                                .map((t) => RadioListTile<String>(
                                      value: t,
                                      activeColor: AppColors.primary,
                                      title: Text(t,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Poppins')),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 80, color: AppColors.border),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Duration Type',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Poppins')),
                        ),
                        const SizedBox(height: 6),
                        RadioGroup<String>(
                          groupValue: _durationType,
                          onChanged: (v) =>
                              setState(() => _durationType = v!),
                          child: Column(
                            children: _durationTypes
                                .map((t) => RadioListTile<String>(
                                      value: t,
                                      activeColor: AppColors.primary,
                                      title: Text(t,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Poppins')),
                                      contentPadding:
                                          const EdgeInsets.only(left: 8),
                                      dense: true,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Elder profile ─────────────────────────────────────────────
            _SectionTitle('Select Elder Profile'),
            const SizedBox(height: 8),
            eldersAsync.when(
              data: (elders) => elders.isEmpty
                  ? _Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_rounded,
                            color: AppColors.primary),
                        title: const Text('No elder profiles yet',
                            style: TextStyle(
                                fontSize: 14, fontFamily: 'Poppins')),
                        subtitle: const Text('Add an elder profile first',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Poppins')),
                        trailing: TextButton(
                          onPressed: () async {
                            await context.push('/elder-profile');
                            if (mounted) {
                              ref.invalidate(_elderProfilesProvider(user.uid));
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ),
                    )
                  : _Card(
                      child: RadioGroup<ElderProfile>(
                        groupValue: _selectedElder,
                        onChanged: (v) =>
                            setState(() => _selectedElder = v),
                        child: Column(
                        children: elders.map((e) {
                          final isSel = _selectedElder?.id == e.id;
                          return RadioListTile<ElderProfile>(
                            value: e,
                            activeColor: AppColors.primary,
                            title: Text(e.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins')),
                            subtitle: Text(
                                '${e.age} years · ${e.gender}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Poppins')),
                            secondary: CircleAvatar(
                              backgroundColor: isSel
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.background,
                              child: Text(e.name[0].toUpperCase(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isSel
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontFamily: 'Poppins')),
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
              loading: () => const _CardShimmer(),
              error: (error, _) => _Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  title: const Text('Could not load elder profiles',
                      style: TextStyle(fontSize: 14, fontFamily: 'Poppins')),
                  subtitle: Text(
                    error.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins'),
                  ),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(_elderProfilesProvider(user.uid)),
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Schedule ──────────────────────────────────────────────────
            _SectionTitle('Schedule'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeButton(
                          label: 'Start Date',
                          value: fmt.format(_startDate),
                          icon: Icons.calendar_today_outlined,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimeButton(
                          label: 'End Date',
                          value: fmt.format(_endDate),
                          icon: Icons.event_outlined,
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeButton(
                          label: 'Start Time',
                          value: _startTime.format(context),
                          icon: Icons.access_time_rounded,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimeButton(
                          label: 'End Time',
                          value: _endTime.format(context),
                          icon: Icons.timer_outlined,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Location & Rate ───────────────────────────────────────────
            _SectionTitle('Location & Rate'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                children: [
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Service Address',
                      hintText: "Leave empty to use elder's address",
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: _fetchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: Icon(Icons.my_location_rounded,
                                  color: _lat != null
                                      ? AppColors.accent
                                      : AppColors.primary),
                              tooltip: 'Use current location',
                              onPressed: _getCurrentLocation,
                            ),
                    ),
                    style: const TextStyle(fontFamily: 'Poppins'),
                    maxLines: 2,
                  ),
                  if (_lat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'GPS location captured',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hourly Rate (LKR)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: 'Poppins'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Required tasks ────────────────────────────────────────────
            _SectionTitle('Required Tasks'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allTasks.map((task) {
                      final selected = _selectedTasks.contains(task);
                      return FilterChip(
                        label: Text(task,
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                        selected: selected,
                        onSelected: (v) => setState(() => v
                            ? _selectedTasks.add(task)
                            : _selectedTasks.remove(task)),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border),
                        deleteIcon: _customTasks.contains(task)
                            ? const Icon(Icons.close, size: 14)
                            : null,
                        onDeleted: _customTasks.contains(task)
                            ? () => setState(() {
                                  _customTasks.remove(task);
                                  _selectedTasks.remove(task);
                                })
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customTaskCtrl,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Add custom task…',
                            hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.textHint),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addCustomTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addCustomTask,
                        icon: const Icon(Icons.add_circle_rounded,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ─────────────────────────────────────────────────────
            _SectionTitle('Additional Notes'),
            const SizedBox(height: 8),
            _Card(
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Any special instructions or requirements…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style:
                    const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Post Job'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Poppins'));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );
}

class _CardShimmer extends StatelessWidget {
  const _CardShimmer();

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(16)),
      );
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins')),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Poppins'),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
