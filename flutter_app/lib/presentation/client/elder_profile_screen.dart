import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'elder_profile_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class ElderProfileScreen extends StatefulWidget {
  const ElderProfileScreen({super.key});

  @override
  State<ElderProfileScreen> createState() => _ElderProfileScreenState();
}

class _ElderProfileScreenState extends State<ElderProfileScreen> {
  void _showAddElderDialog(BuildContext context, ElderProfileViewModel viewModel) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final conditionsController = TextEditingController();
    final contactController = TextEditingController();
    String selectedGender = 'Male';
    String selectedLang = 'English';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Add Patient Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
                    const SizedBox(height: 12),
                    TextField(controller: ageController, decoration: const InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setModalState(() => selectedGender = val!),
                      decoration: const InputDecoration(labelText: "Gender"),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: conditionsController, decoration: const InputDecoration(labelText: "Medical Conditions (comma separated)")),
                    const SizedBox(height: 12),
                    TextField(controller: contactController, decoration: const InputDecoration(labelText: "Emergency Contact"), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLang,
                      items: ['English', 'Sinhala', 'Tamil'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setModalState(() => selectedLang = val!),
                      decoration: const InputDecoration(labelText: "Preferred Language"),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (nameController.text.isEmpty || ageController.text.isEmpty) return;
                          viewModel.addElder(
                            nameController.text.trim(),
                            ageController.text.trim(),
                            selectedGender,
                            conditionsController.text.trim(),
                            contactController.text.trim(),
                            selectedLang,
                            (success, msg) {
                              context.pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          );
                        },
                        child: const Text("Save Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ElderProfileViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('Patient Profiles', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: logoGreen,
            onPressed: () => _showAddElderDialog(context, viewModel),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.errorMessage != null
                  ? Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)))
                  : state.elders.isEmpty
                      ? const Center(child: Text("No patient profiles added yet.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.elders.length,
                          itemBuilder: (context, index) {
                            final elder = state.elders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(elder.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => viewModel.deleteElder(elder.id),
                                        )
                                      ],
                                    ),
                                    Text("Age: ${elder.age} | ${elder.gender}", style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    if (elder.medicalConditions.isNotEmpty)
                                      Text("Conditions: ${elder.medicalConditions.join(', ')}", style: const TextStyle(color: Colors.red, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text("Contact: ${elder.emergencyContact}", style: const TextStyle(fontSize: 13)),
                                    Text("Lang: ${elder.requiredLanguage}", style: const TextStyle(fontSize: 13)),
                                    const Divider(height: 24),
                                    const Text("Medicine Reminders:", style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (elder.medicineList.isEmpty)
                                      const Text("No reminders set.", style: TextStyle(color: Colors.grey, fontSize: 12))
                                    else
                                      Column(
                                        children: elder.medicineList.map((med) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: med.photoBase64.isNotEmpty 
                                              ? Image.memory(base64Decode(med.photoBase64.split(',').last), width: 40, height: 40, fit: BoxFit.cover)
                                              : const Icon(Icons.medication),
                                          title: Text(med.name),
                                          subtitle: Text(med.time),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                            onPressed: () => viewModel.removeMedicineReminder(elder.id, elder.medicineList, med),
                                          ),
                                        )).toList(),
                                      ),
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: Open medicine reminder add sheet
                                      },
                                      icon: const Icon(Icons.add_alarm, color: Colors.blue),
                                      label: const Text("Add Reminder", style: TextStyle(color: Colors.blue)),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        );
      },
    );
  }
}
