import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Auth state listener ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        _showError(_friendlyMessage(next.message));
        setState(() => _isGoogleLoading = false);
      }
      if (next is AuthAuthenticated) {
        context.go('/home');
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading && !_isGoogleLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: FocusScope.of(context).unfocus,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _Logo(),
                const SizedBox(height: 32),
                _Header(),
                const SizedBox(height: 32),
                _LoginForm(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  passwordCtrl: _passwordCtrl,
                  obscurePassword: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onForgotPassword: () => _showForgotPasswordSheet(context),
                  onSubmit: isLoading ? null : _signIn,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 24),
                _Divider(),
                const SizedBox(height: 24),
                _GoogleButton(
                  isLoading: _isGoogleLoading,
                  onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 40),
                _SignUpLink(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    await ref.read(authProvider.notifier).signInWithGoogle();
    if (mounted) setState(() => _isGoogleLoading = false);
  }

  void _showForgotPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    return 'Sign in failed. Please try again.';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Welcome back',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue caring',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback? onSubmit;
  final bool isLoading;

  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
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

          // Password
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => onSubmit?.call(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Sign in button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onSubmit,
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Inline SVG path so no asset file is needed
    return CustomPaint(
      size: const Size(22, 22),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Blue arc (top-right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.57, 1.57, false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Red arc (top-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14, 1.57, false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.57, 0.79, false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Green arc (bottom-right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.36, 0.79, false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // White horizontal bar (G cutout)
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.5, cy - size.height * 0.12, r + 2, size.height * 0.24),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignUpLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        GestureDetector(
          onTap: () => context.push('/signup'),
          child: Text(
            'Sign Up',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Forgot Password Bottom Sheet ───────────────────────────────────────────────

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
      if (mounted) setState(() {_isLoading = false; _emailSent = true;});
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send reset email. Check the address and try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Reset Password',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (!_emailSent) ...[
            Text(
              'Enter your email and we\'ll send a reset link.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: Validators.email,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _send,
                child: _isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Send Reset Link'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Icon(Icons.mark_email_read_outlined,
                size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Reset link sent to\n${_emailCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }
}
