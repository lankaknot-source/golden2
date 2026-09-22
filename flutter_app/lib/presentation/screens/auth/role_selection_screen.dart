import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Shown when an authenticated user has no role set yet (e.g. first Google sign-in).
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _selected;
  bool _isLoading = false;

  Future<void> _confirm() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your role to continue.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUser(user.uid, {'role': _selected!.name.toUpperCase()});
      if (mounted) {
        final isWorker = _selected == UserRole.caregiver || _selected == UserRole.nurse;
        context.go(isWorker ? '/job-feed' : '/home');
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text('One last step',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Tell us who you are so we can personalise your experience.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _RoleOption(
                icon: Icons.elderly_rounded,
                title: 'Client',
                subtitle: 'I need professional care for my loved one',
                color: AppColors.primary,
                isSelected: _selected == UserRole.client,
                onTap: () => setState(() => _selected = UserRole.client),
              ),
              const SizedBox(height: 16),
              _RoleOption(
                icon: Icons.medical_services_rounded,
                title: 'Caregiver',
                subtitle: 'I provide professional healthcare services',
                color: AppColors.accent,
                isSelected: _selected == UserRole.caregiver,
                onTap: () => setState(() => _selected = UserRole.caregiver),
              ),
              const SizedBox(height: 16),
              _RoleOption(
                icon: Icons.local_hospital_rounded,
                title: 'Nurse',
                subtitle: 'I provide nursing care and medical assistance',
                color: const Color(0xFF8B5CF6),
                isSelected: _selected == UserRole.nurse,
                onTap: () => setState(() => _selected = UserRole.nurse),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirm,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? color.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon,
                      size: 28,
                      color: isSelected ? Colors.white : color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected ? Colors.white : AppColors.border,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
