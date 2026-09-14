import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_view_model.dart';
import 'login_screen.dart'; // For colors

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final state = authViewModel.state;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.isSuccess) {
            context.go('/home'); // Ensure you have this route defined
          }
        });

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Complete Account",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please select how you will be joining Golden Hand Caregivers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (state.isLoading)
                      const CircularProgressIndicator(color: logoGreen)
                    else ...[
                      _buildRoleButton(
                        context,
                        title: "I am a Client",
                        color: darkBlue,
                        onPressed: () => context.read<AuthViewModel>().saveGoogleUserRole("CLIENT"),
                      ),
                      const SizedBox(height: 16),
                      const Text("OR", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 16),

                      _buildRoleButton(
                        context,
                        title: "I am a Caregiver",
                        color: logoGreen,
                        onPressed: () => context.read<AuthViewModel>().saveGoogleUserRole("CAREGIVER"),
                      ),
                      const SizedBox(height: 16),
                      const Text("OR", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 16),

                      _buildRoleButton(
                        context,
                        title: "I am a Nurse",
                        color: const Color(0xFF8B5CF6), // Purple from Android
                        onPressed: () => context.read<AuthViewModel>().saveGoogleUserRole("NURSE"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleButton(BuildContext context, {required String title, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
