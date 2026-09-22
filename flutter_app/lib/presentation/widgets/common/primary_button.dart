import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [icon!, const SizedBox(width: 8), Text(label)],
                )
              : Text(label),
    );
  }
}
