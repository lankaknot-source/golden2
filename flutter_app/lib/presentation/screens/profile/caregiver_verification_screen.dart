import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/storage_service.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _storageProvider = Provider((_) => StorageService());

// ── Screen ────────────────────────────────────────────────────────────────────

class CaregiverVerificationScreen extends ConsumerStatefulWidget {
  const CaregiverVerificationScreen({super.key});

  @override
  ConsumerState<CaregiverVerificationScreen> createState() =>
      _CaregiverVerificationScreenState();
}

class _CaregiverVerificationScreenState
    extends ConsumerState<CaregiverVerificationScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1 — Personal
  final _nicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Male';

  // Step 2 — Documents
  File? _nicFront;
  File? _nicBack;
  File? _selfie;
  File? _policeClearance;
  File? _bankBook;
  File? _medicalFitness;

  // Step 3 — Professional
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _qualificationsCtrl = TextEditingController();
  bool _vaccinationStatus = false;
  final Set<String> _selectedCategories = {};

  // Step 4 — Financial
  final _bankNameCtrl = TextEditingController();
  final _accountNumCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  // Step 5 — Preferences
  bool _liveIn = false;
  bool _liveOut = true;
  final Set<String> _selectedDistricts = {};
  bool _termsAgreed = false;
  bool _isSaving = false;

  static const _stepTitles = [
    'Personal',
    'Documents',
    'Professional',
    'Financial',
    'Preferences',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nicCtrl.dispose();
    _addressCtrl.dispose();
    _experienceCtrl.dispose();
    _skillsCtrl.dispose();
    _qualificationsCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumCtrl.dispose();
    _branchCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 0: // Personal
        if (_nicCtrl.text.trim().isEmpty) {
          _snack('Please enter your NIC number', isError: true);
          return false;
        }
        if (_dob == null) {
          _snack('Please select your date of birth', isError: true);
          return false;
        }
        if (_addressCtrl.text.trim().isEmpty) {
          _snack('Please enter your address', isError: true);
          return false;
        }
        return true;
      case 1: // Documents
        final user = ref.read(currentUserProvider)!;
        final hasNicFront = _nicFront != null || (user.nicFrontUrl ?? '').isNotEmpty;
        final hasNicBack  = _nicBack  != null || (user.nicBackUrl  ?? '').isNotEmpty;
        final hasSelfie   = _selfie   != null || (user.selfieUrl   ?? '').isNotEmpty;
        if (!hasNicFront) { _snack('Please upload NIC front photo', isError: true); return false; }
        if (!hasNicBack)  { _snack('Please upload NIC back photo',  isError: true); return false; }
        if (!hasSelfie)   { _snack('Please upload a selfie photo',  isError: true); return false; }
        return true;
      case 2: // Professional
        if (_selectedCategories.isEmpty) {
          _snack('Please select at least one care category', isError: true);
          return false;
        }
        return true;
      case 3: // Financial
        if (_bankNameCtrl.text.trim().isEmpty) {
          _snack('Please enter your bank name', isError: true);
          return false;
        }
        if (_accountNumCtrl.text.trim().isEmpty) {
          _snack('Please enter your bank account number', isError: true);
          return false;
        }
        return true;
      case 4: // Preferences
        if (!_liveIn && !_liveOut) {
          _snack('Please select at least one service type', isError: true);
          return false;
        }
        if (_selectedDistricts.isEmpty) {
          _snack('Please select at least one preferred district', isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step < 4) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    if (!_termsAgreed) {
      _snack('Please agree to the Terms & Conditions', isError: true);
      return;
    }
    final user = ref.read(currentUserProvider)!;
    final storage = ref.read(_storageProvider);
    setState(() => _isSaving = true);

    try {
      // Upload documents in parallel
      final futures = await Future.wait([
        if (_nicFront != null)
          storage.uploadImage(_nicFront!, 'kyc/${user.uid}')
        else
          Future.value(user.nicFrontUrl ?? ''),
        if (_nicBack != null)
          storage.uploadImage(_nicBack!, 'kyc/${user.uid}')
        else
          Future.value(user.nicBackUrl ?? ''),
        if (_selfie != null)
          storage.uploadImage(_selfie!, 'kyc/${user.uid}')
        else
          Future.value(user.selfieUrl ?? ''),
        if (_policeClearance != null)
          storage.uploadFile(_policeClearance!, 'kyc/${user.uid}')
        else
          Future.value(user.policeClearanceUrl ?? ''),
        if (_bankBook != null)
          storage.uploadImage(_bankBook!, 'kyc/${user.uid}')
        else
          Future.value(user.bankBookUrl ?? ''),
        if (_medicalFitness != null)
          storage.uploadFile(_medicalFitness!, 'kyc/${user.uid}')
        else
          Future.value(user.medicalFitnessUrl ?? ''),
      ]);

      final serviceTypes = [
        if (_liveIn) 'Live-in',
        if (_liveOut) 'Live-out',
      ];

      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'kycStatus': KycStatus.pending.name,
        'nicNumber': _nicCtrl.text.trim(),
        'dob': _dob?.toIso8601String(),
        'gender': _gender,
        'address': _addressCtrl.text.trim(),
        'nicFrontUrl': futures[0],
        'nicBackUrl': futures[1],
        'selfieUrl': futures[2],
        'policeClearanceUrl': futures[3],
        'bankBookUrl': futures[4],
        'medicalFitnessUrl': futures[5],
        'experienceYears': _experienceCtrl.text.trim(),
        'specialSkills': _skillsCtrl.text.trim(),
        'qualifications': _qualificationsCtrl.text.trim(),
        'vaccinationStatus': _vaccinationStatus,
        'categories': _selectedCategories.toList(),
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccountNumber': _accountNumCtrl.text.trim(),
        'bankBranch': _branchCtrl.text.trim(),
        'expectedSalary': double.tryParse(_salaryCtrl.text.trim()) ?? 0,
        'preferredServiceTypes': serviceTypes,
        'preferredDistricts': _selectedDistricts.toList(),
      });

      if (mounted) {
        _snack('Verification submitted! Under review.');
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: isError ? AppColors.error : AppColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final isLocked = user.kycStatus == KycStatus.pending ||
        user.kycStatus == KycStatus.approved;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _prev,
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, titles: _stepTitles),
          if (user.kycStatus == KycStatus.rejected)
            _Banner(
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              text: 'Your previous submission was rejected. Please re-submit.',
            ),
          if (user.kycStatus == KycStatus.pending)
            _Banner(
              icon: Icons.hourglass_top_rounded,
              color: AppColors.warning,
              text: 'Verification submitted and under review.',
            ),
          if (user.kycStatus == KycStatus.approved)
            _Banner(
              icon: Icons.verified_rounded,
              color: AppColors.accent,
              text: 'Verification approved! You can accept jobs.',
            ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Personal(
                  nicCtrl: _nicCtrl,
                  addressCtrl: _addressCtrl,
                  dob: _dob,
                  gender: _gender,
                  onDobPicked: (d) => setState(() => _dob = d),
                  onGenderChanged: (g) => setState(() => _gender = g),
                ),
                _Step2Documents(
                  nicFront: _nicFront,
                  nicBack: _nicBack,
                  selfie: _selfie,
                  policeClearance: _policeClearance,
                  bankBook: _bankBook,
                  medicalFitness: _medicalFitness,
                  existingNicFrontUrl: user.nicFrontUrl,
                  existingNicBackUrl: user.nicBackUrl,
                  existingSelfieUrl: user.selfieUrl,
                  existingPoliceClearanceUrl: user.policeClearanceUrl,
                  onPicked: (type, file) => setState(() {
                    switch (type) {
                      case 'nicFront': _nicFront = file;
                      case 'nicBack': _nicBack = file;
                      case 'selfie': _selfie = file;
                      case 'police': _policeClearance = file;
                      case 'bankBook': _bankBook = file;
                      case 'medical': _medicalFitness = file;
                    }
                  }),
                ),
                _Step3Professional(
                  experienceCtrl: _experienceCtrl,
                  skillsCtrl: _skillsCtrl,
                  qualificationsCtrl: _qualificationsCtrl,
                  vaccinationStatus: _vaccinationStatus,
                  selectedCategories: _selectedCategories,
                  onVaccinationChanged: (v) =>
                      setState(() => _vaccinationStatus = v),
                  onCategoryToggled: (c) => setState(() {
                    _selectedCategories.contains(c)
                        ? _selectedCategories.remove(c)
                        : _selectedCategories.add(c);
                  }),
                ),
                _Step4Financial(
                  bankNameCtrl: _bankNameCtrl,
                  accountNumCtrl: _accountNumCtrl,
                  branchCtrl: _branchCtrl,
                  salaryCtrl: _salaryCtrl,
                ),
                _Step5Preferences(
                  liveIn: _liveIn,
                  liveOut: _liveOut,
                  selectedDistricts: _selectedDistricts,
                  termsAgreed: _termsAgreed,
                  onLiveInChanged: (v) => setState(() => _liveIn = v),
                  onLiveOutChanged: (v) => setState(() => _liveOut = v),
                  onDistrictToggled: (d) => setState(() {
                    _selectedDistricts.contains(d)
                        ? _selectedDistricts.remove(d)
                        : _selectedDistricts.add(d);
                  }),
                  onTermsChanged: (v) => setState(() => _termsAgreed = v),
                ),
              ],
            ),
          ),
          _BottomBar(
            step: _step,
            totalSteps: _stepTitles.length,
            isSaving: _isSaving,
            isDisabled: isLocked,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Banner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: color, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> titles;
  const _StepIndicator({required this.current, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: List.generate(titles.length, (i) {
          final isActive = i == current;
          final isDone = i < current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.accent
                              : isActive
                                  ? AppColors.primary
                                  : AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone || isActive
                                ? Colors.transparent
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded,
                                  size: 13, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        titles[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < titles.length - 1)
                  Container(
                    height: 2,
                    width: 8,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isDone ? AppColors.accent : AppColors.border,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: Personal ──────────────────────────────────────────────────────────

class _Step1Personal extends StatelessWidget {
  final TextEditingController nicCtrl;
  final TextEditingController addressCtrl;
  final DateTime? dob;
  final String gender;
  final ValueChanged<DateTime> onDobPicked;
  final ValueChanged<String> onGenderChanged;

  const _Step1Personal({
    required this.nicCtrl,
    required this.addressCtrl,
    required this.dob,
    required this.gender,
    required this.onDobPicked,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: nicCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'NIC / National ID Number',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime(1990),
                firstDate: DateTime(1940),
                lastDate: DateTime.now()
                    .subtract(const Duration(days: 365 * 18)),
              );
              if (d != null) onDobPicked(d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date of Birth',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'Poppins')),
                      Text(
                        dob != null
                            ? DateFormat('d MMM yyyy').format(dob!)
                            : 'Select date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: dob != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: gender,
            onChanged: (v) => onGenderChanged(v!),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g,
                        style: const TextStyle(fontFamily: 'Poppins'))))
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.wc_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: addressCtrl,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Permanent Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Documents ────────────────────────────────────────────────────────

class _Step2Documents extends StatelessWidget {
  final File? nicFront;
  final File? nicBack;
  final File? selfie;
  final File? policeClearance;
  final File? bankBook;
  final File? medicalFitness;
  final String? existingNicFrontUrl;
  final String? existingNicBackUrl;
  final String? existingSelfieUrl;
  final String? existingPoliceClearanceUrl;
  final void Function(String type, File file) onPicked;

  const _Step2Documents({
    required this.nicFront,
    required this.nicBack,
    required this.selfie,
    required this.policeClearance,
    required this.bankBook,
    required this.medicalFitness,
    required this.existingNicFrontUrl,
    required this.existingNicBackUrl,
    required this.existingSelfieUrl,
    required this.existingPoliceClearanceUrl,
    required this.onPicked,
  });

  Future<void> _pick(BuildContext context, String type,
      {bool camera = false}) async {
    final picker = ImagePicker();
    final source = camera ? ImageSource.camera : ImageSource.gallery;
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile != null) onPicked(type, File(xfile.path));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Required Documents',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
              'Clear photos are required for verification. Max 2MB each.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 16),
          _DocTile(
            label: 'NIC – Front Side *',
            icon: Icons.credit_card_outlined,
            file: nicFront,
            existingUrl: existingNicFrontUrl,
            onTap: () => _pick(context, 'nicFront'),
            onCamera: () => _pick(context, 'nicFront', camera: true),
          ),
          _DocTile(
            label: 'NIC – Back Side *',
            icon: Icons.credit_card_outlined,
            file: nicBack,
            existingUrl: existingNicBackUrl,
            onTap: () => _pick(context, 'nicBack'),
            onCamera: () => _pick(context, 'nicBack', camera: true),
          ),
          _DocTile(
            label: 'Selfie with NIC *',
            icon: Icons.face_outlined,
            file: selfie,
            existingUrl: existingSelfieUrl,
            onTap: () => _pick(context, 'selfie'),
            onCamera: () => _pick(context, 'selfie', camera: true),
            preferCamera: true,
          ),
          _DocTile(
            label: 'Police Clearance Certificate',
            icon: Icons.security_outlined,
            file: policeClearance,
            existingUrl: existingPoliceClearanceUrl,
            onTap: () => _pick(context, 'police'),
            onCamera: () => _pick(context, 'police', camera: true),
          ),
          _DocTile(
            label: 'Bank Book / Passbook',
            icon: Icons.account_balance_outlined,
            file: bankBook,
            existingUrl: null,
            onTap: () => _pick(context, 'bankBook'),
            onCamera: () => _pick(context, 'bankBook', camera: true),
          ),
          _DocTile(
            label: 'Medical Fitness Certificate',
            icon: Icons.medical_services_outlined,
            file: medicalFitness,
            existingUrl: null,
            onTap: () => _pick(context, 'medical'),
            onCamera: () => _pick(context, 'medical', camera: true),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final String? existingUrl;
  final VoidCallback onTap;
  final VoidCallback onCamera;
  final bool preferCamera;

  const _DocTile({
    required this.label,
    required this.icon,
    required this.file,
    required this.existingUrl,
    required this.onTap,
    required this.onCamera,
    this.preferCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null || existingUrl != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: hasFile
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: file != null
              ? ClipOval(child: Image.file(file!, fit: BoxFit.cover))
              : Icon(hasFile ? Icons.check_circle_rounded : icon,
                  color:
                      hasFile ? AppColors.accent : AppColors.textSecondary,
                  size: 22),
        ),
        title: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins')),
        subtitle: Text(
          hasFile ? 'Uploaded ✓' : 'Tap to upload',
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'Poppins',
              color: hasFile ? AppColors.accent : AppColors.textHint),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary, size: 20),
              onPressed: onCamera,
              tooltip: 'Take photo',
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary, size: 20),
              onPressed: onTap,
              tooltip: 'From gallery',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Professional ──────────────────────────────────────────────────────

class _Step3Professional extends StatelessWidget {
  final TextEditingController experienceCtrl;
  final TextEditingController skillsCtrl;
  final TextEditingController qualificationsCtrl;
  final bool vaccinationStatus;
  final Set<String> selectedCategories;
  final ValueChanged<bool> onVaccinationChanged;
  final ValueChanged<String> onCategoryToggled;

  const _Step3Professional({
    required this.experienceCtrl,
    required this.skillsCtrl,
    required this.qualificationsCtrl,
    required this.vaccinationStatus,
    required this.selectedCategories,
    required this.onVaccinationChanged,
    required this.onCategoryToggled,
  });

  static const _categories = [
    'Elderly Care', 'Dementia Care', 'Post-Surgery', 'Disability Care',
    'Palliative Care', 'Pediatric Care', 'Physiotherapy', 'Nursing',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: experienceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Years of Experience',
              prefixIcon: Icon(Icons.work_history_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: skillsCtrl,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Special Skills',
              hintText: 'e.g. First Aid, CPR, Physiotherapy',
              prefixIcon: Icon(Icons.psychology_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: qualificationsCtrl,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Qualifications',
              hintText: 'e.g. Diploma in Nursing, BSc Health',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            value: vaccinationStatus,
            onChanged: onVaccinationChanged,
            activeThumbColor: AppColors.accent,
            title: const Text('Fully Vaccinated',
                style: TextStyle(fontSize: 14, fontFamily: 'Poppins')),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          const Text('Care Categories',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final sel = selectedCategories.contains(cat);
              return FilterChip(
                label: Text(cat,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color:
                            sel ? Colors.white : AppColors.textPrimary)),
                selected: sel,
                onSelected: (_) => onCategoryToggled(cat),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: sel ? AppColors.primary : AppColors.border),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Financial ─────────────────────────────────────────────────────────

class _Step4Financial extends StatelessWidget {
  final TextEditingController bankNameCtrl;
  final TextEditingController accountNumCtrl;
  final TextEditingController branchCtrl;
  final TextEditingController salaryCtrl;

  const _Step4Financial({
    required this.bankNameCtrl,
    required this.accountNumCtrl,
    required this.branchCtrl,
    required this.salaryCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: bankNameCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Bank Name',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: accountNumCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Account Number',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: branchCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Branch Name',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: salaryCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Expected Monthly Salary (LKR)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 5: Preferences ───────────────────────────────────────────────────────

class _Step5Preferences extends StatelessWidget {
  final bool liveIn;
  final bool liveOut;
  final Set<String> selectedDistricts;
  final bool termsAgreed;
  final ValueChanged<bool> onLiveInChanged;
  final ValueChanged<bool> onLiveOutChanged;
  final ValueChanged<String> onDistrictToggled;
  final ValueChanged<bool> onTermsChanged;

  const _Step5Preferences({
    required this.liveIn,
    required this.liveOut,
    required this.selectedDistricts,
    required this.termsAgreed,
    required this.onLiveInChanged,
    required this.onLiveOutChanged,
    required this.onDistrictToggled,
    required this.onTermsChanged,
  });

  static const _districts = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale',
    'Nuwara Eliya', 'Galle', 'Matara', 'Hambantota', 'Jaffna',
    'Kilinochchi', 'Mannar', 'Vavuniya', 'Mullaitivu', 'Batticaloa',
    'Ampara', 'Trincomalee', 'Kurunegala', 'Puttalam', 'Anuradhapura',
    'Polonnaruwa', 'Badulla', 'Moneragala', 'Ratnapura', 'Kegalle',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Service Type',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: AppColors.textPrimary)),
          CheckboxListTile(
            value: liveIn,
            onChanged: (v) => onLiveInChanged(v ?? false),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: const Text('Live-In',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            subtitle: const Text('Stay at client\'s home',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ),
          CheckboxListTile(
            value: liveOut,
            onChanged: (v) => onLiveOutChanged(v ?? false),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: const Text('Live-Out',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            subtitle: const Text('Visit for scheduled hours',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 16),
          const Text('Preferred Districts',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _districts.map((d) {
              final sel = selectedDistricts.contains(d);
              return FilterChip(
                label: Text(d,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color:
                            sel ? Colors.white : AppColors.textPrimary)),
                selected: sel,
                onSelected: (_) => onDistrictToggled(d),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: sel ? AppColors.primary : AppColors.border),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: CheckboxListTile(
              value: termsAgreed,
              onChanged: (v) => onTermsChanged(v ?? false),
              activeColor: AppColors.primary,
              title: const Text('I agree to the Terms & Conditions',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins')),
              subtitle: const Text(
                  'By submitting, I confirm all information provided is accurate.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool isSaving;
  final bool isDisabled;
  final VoidCallback onNext;

  const _BottomBar({
    required this.step,
    required this.totalSteps,
    required this.isSaving,
    required this.isDisabled,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (isSaving || isDisabled) ? null : onNext,
          child: isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  step < totalSteps - 1 ? 'Next' : 'Submit Verification',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}
