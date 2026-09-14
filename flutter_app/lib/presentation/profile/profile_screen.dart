import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'profile_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rateController = TextEditingController();
  bool _isInit = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        final user = state.userData;

        if (user != null && !_isInit) {
          _nameController.text = user.name;
          _phoneController.text = user.phone;
          _rateController.text = user.hourlyRate.toString();
          _isInit = true;
        }

        if (state.isSaveSuccess) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
            viewModel.resetSaveSuccess();
          });
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: state.isLoading || user == null
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: user.profileImageUrl.isNotEmpty
                                ? MemoryImage(base64Decode(user.profileImageUrl.split(',').last))
                                : null,
                            child: user.profileImageUrl.isEmpty
                                ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40, color: Colors.grey))
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(user.email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),

                      // KYC Status
                      if (user.role == "CAREGIVER" || user.role == "NURSE")
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: user.kycStatus == "APPROVED" ? Colors.green[100] : Colors.orange[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "KYC Status: ${user.kycStatus}",
                            style: TextStyle(
                              color: user.kycStatus == "APPROVED" ? Colors.green[800] : Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),

                      // Form Fields
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      if (user.role == "CAREGIVER" || user.role == "NURSE")
                        TextField(
                          controller: _rateController,
                          decoration: const InputDecoration(labelText: "Hourly Rate (LKR)", border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: state.isSaving
                              ? null
                              : () {
                                  final hourlyRate = double.tryParse(_rateController.text) ?? user.hourlyRate;
                                  viewModel.updateProfileFull(
                                    _nameController.text.trim(),
                                    _phoneController.text.trim(),
                                    hourlyRate,
                                    "", // TODO: Implement Base64 image picking in Flutter
                                  );
                                },
                          child: state.isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
