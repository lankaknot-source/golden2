import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/storage_service.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _rateCtrl;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider)!;
    _nameCtrl = TextEditingController(text: user.name);
    _phoneCtrl = TextEditingController(text: user.phone);
    _rateCtrl = TextEditingController(text: user.hourlyRate?.toStringAsFixed(0) ?? '');
    _photoUrl = user.profileImageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final url = await StorageService().uploadFile(File(image.path), 'profiles/${user.uid}');
      setState(() => _photoUrl = url);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider)!;
    setState(() => _isSaving = true);
    try {
      final rate = double.tryParse(_rateCtrl.text.trim());
      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_photoUrl != null) 'photoUrl': _photoUrl,
        if (user.isCaregiverOrNurse && rate != null) 'hourlyRate': rate,
      });
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.accent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Edit', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoUrl == null
                          ? Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: 'Poppins',
                              ),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.roleLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
              if (user.rating > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${user.rating.toStringAsFixed(1)} (${user.reviewCount} reviews)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),

              // Fields
              _FieldCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      enabled: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => Validators.minLength(v, 2, 'Name'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: user.email,
                      enabled: false,
                      style: const TextStyle(fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phone,
                    ),
                    if (user.isCaregiverOrNurse) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _rateCtrl,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'Poppins'),
                        decoration: const InputDecoration(
                          labelText: 'Hourly Rate (LKR)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KYC status
              _FieldCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                  title: const Text(
                    'Verification Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  trailing: _KycStatus(status: user.kycStatus),
                  onTap: () => context.push(
                    user.isCaregiverOrNurse
                        ? '/caregiver-verification'
                        : '/client-kyc',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_isEditing)
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Widget child;
  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KycStatus extends StatelessWidget {
  final KycStatus status;
  const _KycStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      KycStatus.approved => ('Verified', AppColors.accent),
      KycStatus.rejected => ('Rejected', AppColors.error),
      _ => ('Pending', AppColors.warning),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
