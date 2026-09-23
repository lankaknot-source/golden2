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

class ClientKycScreen extends ConsumerStatefulWidget {
  const ClientKycScreen({super.key});

  @override
  ConsumerState<ClientKycScreen> createState() => _ClientKycScreenState();
}

class _ClientKycScreenState extends ConsumerState<ClientKycScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1 — Identity
  final _nicCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Male';

  // Step 2 — Documents
  File? _nicFront;
  File? _nicBack;
  File? _selfie;

  // Step 3 — Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  bool _isSaving = false;

  static const _stepTitles = ['Identity', 'Documents', 'Address'];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nicCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
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
    final user = ref.read(currentUserProvider)!;
    final storage = ref.read(_storageProvider);
    setState(() => _isSaving = true);

    try {
      final results = await Future.wait([
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
      ]);

      final fullAddress =
          [_addressCtrl.text.trim(), _cityCtrl.text.trim()]
              .where((s) => s.isNotEmpty)
              .join(', ');

      // Client details are informational and do not require manual review.
      // Keep the verification workflow for caregivers/nurses only.
      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'kycStatus': KycStatus.approved.name.toUpperCase(),
        'isVerified': true,
        'nicNumber': _nicCtrl.text.trim(),
        'dob': _dob?.toIso8601String(),
        'gender': _gender,
        'address': fullAddress,
        'nicFrontUrl': results[0],
        'nicBackUrl': results[1],
        'selfieUrl': results[2],
      });

      if (mounted) {
        _snack('Your details were submitted and your account is approved.');
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
    // Client details are always editable. Only caregiver/nurse KYC is a
    // reviewed, locked workflow; a stale client PENDING value must not disable
    // the Next or Submit buttons.
    const isLocked = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Client Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _prev,
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, titles: _stepTitles),

          // Status banners
          if (user.kycStatus == KycStatus.rejected)
            _Banner(
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              text: 'Your previous submission was rejected. Please re-submit.',
            ),
          if (user.kycStatus == KycStatus.approved)
            _Banner(
              icon: Icons.verified_rounded,
              color: AppColors.accent,
              text: 'Your details are saved and your account is approved.',
            ),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1: Identity
                _Step1Identity(
                  nicCtrl: _nicCtrl,
                  dob: _dob,
                  gender: _gender,
                  onDobPicked: (d) => setState(() => _dob = d),
                  onGenderChanged: (g) => setState(() => _gender = g),
                ),

                // Step 2: Documents
                _Step2Documents(
                  nicFront: _nicFront,
                  nicBack: _nicBack,
                  selfie: _selfie,
                  existingNicFrontUrl: user.nicFrontUrl,
                  existingNicBackUrl: user.nicBackUrl,
                  existingSelfieUrl: user.selfieUrl,
                  onPicked: (type, file) => setState(() {
                    switch (type) {
                      case 'nicFront':
                        _nicFront = file;
                      case 'nicBack':
                        _nicBack = file;
                      case 'selfie':
                        _selfie = file;
                    }
                  }),
                ),

                // Step 3: Address
                _Step3Address(
                  addressCtrl: _addressCtrl,
                  cityCtrl: _cityCtrl,
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
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, color: color, fontFamily: 'Poppins'),
            ),
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

// ── Step 1: Identity ──────────────────────────────────────────────────────────

class _Step1Identity extends StatelessWidget {
  final TextEditingController nicCtrl;
  final DateTime? dob;
  final String gender;
  final ValueChanged<DateTime> onDobPicked;
  final ValueChanged<String> onGenderChanged;

  const _Step1Identity({
    required this.nicCtrl,
    required this.dob,
    required this.gender,
    required this.onDobPicked,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.badge_rounded, color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text(
                  'Identity Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Provide your NIC number, date of birth and gender.',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: nicCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'NIC / National ID Number *',
              prefixIcon: Icon(Icons.credit_card_outlined),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // DOB picker
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime(1990),
                firstDate: DateTime(1940),
                lastDate:
                    DateTime.now().subtract(const Duration(days: 365 * 18)),
              );
              if (d != null) onDobPicked(d);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date of Birth *',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins'),
                      ),
                      Text(
                        dob != null
                            ? DateFormat('d MMM yyyy').format(dob!)
                            : 'Select your date of birth',
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
          const SizedBox(height: 16),

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
              labelText: 'Gender *',
              prefixIcon: Icon(Icons.wc_rounded),
              filled: true,
              fillColor: Colors.white,
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
  final String? existingNicFrontUrl;
  final String? existingNicBackUrl;
  final String? existingSelfieUrl;
  final void Function(String type, File file) onPicked;

  const _Step2Documents({
    required this.nicFront,
    required this.nicBack,
    required this.selfie,
    required this.existingNicFrontUrl,
    required this.existingNicBackUrl,
    required this.existingSelfieUrl,
    required this.onPicked,
  });

  Future<void> _pick(BuildContext context, String type,
      {bool camera = false}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85);
    if (xfile != null) onPicked(type, File(xfile.path));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text(
                  'Identity Documents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload clear photos of your NIC and a selfie with your NIC.',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _DocTile(
            label: 'NIC – Front Side *',
            icon: Icons.credit_card_outlined,
            file: nicFront,
            existingUrl: existingNicFrontUrl,
            onGallery: () => _pick(context, 'nicFront'),
            onCamera: () => _pick(context, 'nicFront', camera: true),
          ),
          _DocTile(
            label: 'NIC – Back Side *',
            icon: Icons.credit_card_outlined,
            file: nicBack,
            existingUrl: existingNicBackUrl,
            onGallery: () => _pick(context, 'nicBack'),
            onCamera: () => _pick(context, 'nicBack', camera: true),
          ),
          _DocTile(
            label: 'Selfie with NIC *',
            icon: Icons.face_outlined,
            file: selfie,
            existingUrl: existingSelfieUrl,
            onGallery: () => _pick(context, 'selfie'),
            onCamera: () => _pick(context, 'selfie', camera: true),
            preferCamera: true,
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
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final bool preferCamera;

  const _DocTile({
    required this.label,
    required this.icon,
    required this.file,
    required this.existingUrl,
    required this.onGallery,
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hasFile
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: file != null
              ? ClipOval(child: Image.file(file!, fit: BoxFit.cover))
              : Icon(
                  hasFile ? Icons.check_circle_rounded : icon,
                  color: hasFile ? AppColors.accent : AppColors.textSecondary,
                  size: 22,
                ),
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
            color: hasFile ? AppColors.accent : AppColors.textHint,
          ),
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
              onPressed: onGallery,
              tooltip: 'From gallery',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Address ───────────────────────────────────────────────────────────

class _Step3Address extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;

  const _Step3Address({
    required this.addressCtrl,
    required this.cityCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text(
                  'Address Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Provide your current residential address for verification.',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: addressCtrl,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Street Address *',
              hintText: 'e.g. No. 42, Flower Road',
              prefixIcon: Icon(Icons.home_outlined),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: cityCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'City / District *',
              hintText: 'e.g. Colombo',
              prefixIcon: Icon(Icons.location_city_outlined),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.info, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your address will be used for verification purposes only '
                    'and will not be shared with caregivers.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontFamily: 'Poppins',
                      height: 1.5,
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
                  step < totalSteps - 1 ? 'Next' : 'Submit Details',
                  style: const TextStyle(
                      fontSize: 16, fontFamily: 'Poppins'),
                ),
        ),
      ),
    );
  }
}
