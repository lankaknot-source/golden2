import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _pageController = PageController();
  int _step = 0; // 0 = role, 1 = info, 2 = password

  // Step 1 — role
  UserRole? _selectedRole;

  // Step 2 — personal info
  final _infoFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 3 — password
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0 && _selectedRole == null) {
      _showError('Please select your role to continue.');
      return;
    }
    if (_step == 1 && !_infoFormKey.currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _selectedRole!,
        );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('weak-password')) return 'Password is too weak. Use at least 8 characters.';
    if (raw.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Sign up failed. Please try again.';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthError) _showError(_friendlyMessage(next.message));
      if (next is AuthAuthenticated) {
        context.go('/home');
      }
    });

    final isLoading = ref.watch(authProvider) is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: _step, onBack: _prevStep),
            _StepIndicator(currentStep: _step),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RoleStep(
                    selected: _selectedRole,
                    onSelect: (role) => setState(() => _selectedRole = role),
                  ),
                  _InfoStep(
                    formKey: _infoFormKey,
                    nameCtrl: _nameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    onNext: _nextStep,
                  ),
                  _PasswordStep(
                    formKey: _passwordFormKey,
                    passwordCtrl: _passwordCtrl,
                    confirmCtrl: _confirmCtrl,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    onSubmit: isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
            _BottomBar(
              step: _step,
              isLoading: isLoading,
              onNext: isLoading ? null : _nextStep,
            ),
            if (_step == 0) _SignInLink(),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const _TopBar({required this.step, required this.onBack});

  static const _titles = ['Create Account', 'Your Details', 'Set Password'];
  static const _subtitles = [
    'What describes you best?',
    'Tell us a bit about yourself',
    'Keep your account secure',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[step],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                _subtitles[step],
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.accent
                      : isActive
                          ? AppColors.primary
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: Role ───────────────────────────────────────────────────────────────

class _RoleStep extends StatelessWidget {
  final UserRole? selected;
  final ValueChanged<UserRole> onSelect;

  const _RoleStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _RoleCard(
            role: UserRole.client,
            icon: Icons.elderly_rounded,
            title: 'I\'m a Client',
            subtitle: 'I need professional care\nfor my loved one',
            color: AppColors.primary,
            isSelected: selected == UserRole.client,
            onTap: () => onSelect(UserRole.client),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: UserRole.caregiver,
            icon: Icons.medical_services_rounded,
            title: 'I\'m a Caregiver',
            subtitle: 'I provide professional\nhealthcare services',
            color: AppColors.accent,
            isSelected: selected == UserRole.caregiver,
            onTap: () => onSelect(UserRole.caregiver),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: UserRole.nurse,
            icon: Icons.local_hospital_rounded,
            title: 'I\'m a Nurse',
            subtitle: 'I provide nursing care\nand medical assistance',
            color: const Color(0xFF8B5CF6),
            isSelected: selected == UserRole.nurse,
            onTap: () => onSelect(UserRole.nurse),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
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
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.textSecondary,
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.white : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, size: 14, color: color)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Personal info ──────────────────────────────────────────────────────

class _InfoStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onNext;

  const _InfoStep({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => Validators.minLength(v, 2, 'Full name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              onFieldSubmitted: (_) => onNext(),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+1 234 567 8900',
              ),
              validator: Validators.phone,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Password ───────────────────────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback? onSubmit;

  const _PasswordStep({
    required this.formKey,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmCtrl,
              obscureText: obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit?.call(),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onToggleConfirm,
                ),
              ),
              validator: (v) =>
                  Validators.confirmPassword(v, passwordCtrl.text),
            ),
            const SizedBox(height: 20),
            _PasswordStrengthBar(controller: passwordCtrl),
            const SizedBox(height: 12),
            _TermsNotice(),
          ],
        ),
      ),
    );
  }
}

// ── Password strength bar ──────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordStrengthBar({required this.controller});

  @override
  State<_PasswordStrengthBar> createState() => _PasswordStrengthBarState();
}

class _PasswordStrengthBarState extends State<_PasswordStrengthBar> {
  int _strength = 0;

  static int _calculateStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?]').hasMatch(password)) score++;
    return score.clamp(0, 4);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() => setState(() => _strength = _calculateStrength(widget.controller.text));

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  static const _labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
  static const _colors = [
    Colors.transparent,
    AppColors.error,
    AppColors.warning,
    AppColors.info,
    AppColors.accent,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.controller.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < _strength;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled ? _colors[_strength] : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _labels[_strength],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _colors[_strength],
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// ── Terms notice ───────────────────────────────────────────────────────────────

class _TermsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
        children: const [
          TextSpan(text: 'By creating an account you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final bool isLoading;
  final VoidCallback? onNext;

  const _BottomBar({
    required this.step,
    required this.isLoading,
    required this.onNext,
  });

  static const _labels = ['Continue', 'Continue', 'Create Account'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onNext,
          child: isLoading && step == 2
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(_labels[step]),
        ),
      ),
    );
  }
}

// ── Sign-in link ───────────────────────────────────────────────────────────────

class _SignInLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              'Sign In',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
