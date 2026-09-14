import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_view_model.dart';

const Color darkBlue = Color(0xFF0D3B66);
const Color logoGreen = Color(0xFF53A548);
const Color bgColor = Color(0xFFF8FAFC);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
      // You may need to provide the webClientId here if required for your setup
      // clientId: "YOUR_WEB_CLIENT_ID_HERE",
      );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isNotEmpty && password.isNotEmpty) {
      context.read<AuthViewModel>().login(email, password);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null && accessToken != null && mounted) {
        context.read<AuthViewModel>().loginWithGoogle(idToken, accessToken);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Login Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to navigate
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final state = authViewModel.state;

        // Navigation effects based on state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.isSuccess) {
            context.go('/home'); // Ensure you have this route defined
          } else if (state.needsRoleSelection) {
            context.go('/role_selection');
          }
        });

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/brand_logo.jpeg',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        semanticLabel: 'Golden Hand Caregivers logo'),
                    const Text(
                      "GOLDEN HAND",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: darkBlue,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "CAREGIVERS",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: logoGreen,
                        letterSpacing: 6.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Welcome Back!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email, color: darkBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: logoGreen, width: 2),
                        ),
                        floatingLabelStyle: const TextStyle(color: logoGreen),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: darkBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: logoGreen, width: 2),
                        ),
                        floatingLabelStyle: const TextStyle(color: logoGreen),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Implement forgot password
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: logoGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Message
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          state.errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isLoading && !state.needsRoleSelection
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Sign In",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("OR",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 16),

                    // Google Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: state.isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isLoading && !state.needsRoleSelection
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: darkBlue,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Sign in with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/brand_logo.jpeg',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            semanticLabel: 'Golden Hand Caregivers logo'),
                        const Text("Don't have an account? ",
                            style: TextStyle(color: Colors.grey)),
                        GestureDetector(
                          onTap: () {
                            context.push(
                                '/signup'); // Ensure this route is defined
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: logoGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
