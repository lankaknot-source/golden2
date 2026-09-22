import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String caregiverId;

  const RatingScreen({
    super.key,
    required this.bookingId,
    required this.caregiverId,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen>
    with SingleTickerProviderStateMixin {
  double _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  late final AnimationController _starAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _starAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _starAnim, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _starAnim.dispose();
    super.dispose();
  }

  void _selectRating(double val) {
    setState(() => _rating = val);
    _starAnim.forward(from: 0);
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a star rating',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final clientId = ref.read(currentUserProvider)?.uid ?? '';
      await ref.read(bookingNotifierProvider.notifier).submitRating(
            bookingId: widget.bookingId,
            caregiverId: widget.caregiverId,
            clientId: clientId,
            rating: _rating,
            comment: _reviewCtrl.text.trim(),
          );
      if (mounted) {
        // Redirect to home
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thank you for your review!',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Rate & Review',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Main card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar with gradient background
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'How was your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your rating helps families find great caregivers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 5-star selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starVal = i + 1.0;
                      final isFilled = _rating >= starVal;
                      return GestureDetector(
                        onTap: () => _selectRating(starVal),
                        child: AnimatedBuilder(
                          animation: _starAnim,
                          builder: (ctx, child) {
                            final scale = _rating == starVal
                                ? _scaleAnim.value
                                : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: Icon(
                                    isFilled
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    key: ValueKey(isFilled),
                                    color: isFilled
                                        ? Colors.amber
                                        : AppColors.border,
                                    size: 50,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Rating label
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _ratingLabel(),
                      key: ValueKey(_rating),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _rating > 0
                            ? Colors.amber.shade700
                            : AppColors.textHint,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Review text field
                  TextField(
                    controller: _reviewCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(fontFamily: 'Poppins'),
                    decoration: InputDecoration(
                      hintText: 'Share your experience (optional)…',
                      hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textHint),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Submit Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Skip button
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel() {
    return switch (_rating.toInt()) {
      1 => 'Poor',
      2 => 'Fair',
      3 => 'Good',
      4 => 'Very Good',
      5 => 'Excellent!',
      _ => 'Tap a star to rate',
    };
  }
}
