import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'create_job_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class CreateJobScreen extends StatefulWidget {
  final String? caregiverId;
  final String? caregiverName;

  const CreateJobScreen({super.key, this.caregiverId, this.caregiverName});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _tasksController = TextEditingController();

  String _selectedElderId = '';
  String _selectedCategory = 'Elder Care';
  String _selectedServiceType = 'Basic Assistance';
  String _selectedDuration = 'Hourly';
  bool _isEmergency = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.caregiverId != null) {
        context.read<CreateJobViewModel>().fetchCaregiverRate(widget.caregiverId);
      }
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _hoursController.dispose();
    _tasksController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  void _handleSubmit(CreateJobViewModel viewModel) {
    if (_selectedElderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a patient")));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select date and time")));
      return;
    }
    
    final hours = int.tryParse(_hoursController.text) ?? 1;
    final tasksList = _tasksController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final scheduledDateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    ).millisecondsSinceEpoch;

    // TODO: Get actual location. Using defaults for porting phase.
    const double defaultLat = 6.9271;
    const double defaultLng = 79.8612;

    viewModel.createJobRequest(
      lat: defaultLat,
      lng: defaultLng,
      description: _descController.text.trim(),
      isEmergency: _isEmergency,
      elderId: _selectedElderId,
      selectedCaregiverId: widget.caregiverId,
      scheduledTimeMs: scheduledDateTime,
      careCategory: _selectedCategory,
      serviceType: _selectedServiceType,
      durationType: _selectedDuration,
      requestedTasks: tasksList,
      estimatedHours: hours,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CreateJobViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.isSuccess) {
            viewModel.resetSuccessState();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job request submitted successfully!")));
            context.go('/home');
          }
        });

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('Create Job Request', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.caregiverName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text("Booking: ${widget.caregiverName}", style: const TextStyle(fontWeight: FontWeight.bold, color: darkBlue)),
                              const Spacer(),
                              Text("Rs.${state.selectedCaregiverRate}/hr", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Elder Selection
                      const Text("Select Patient", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedElderId.isEmpty ? null : _selectedElderId,
                        items: state.elders.map((e) => DropdownMenuItem(value: e.id, child: Text("${e.name} (${e.age}y)"))).toList(),
                        onChanged: (val) => setState(() => _selectedElderId = val ?? ''),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        hint: const Text("Choose a profile"),
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text("Care Category", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: ['Elder Care', 'Patient Care', 'Post-Surgery', 'Special Needs'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? ''),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),

                      // Date and Time
                      const Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDateTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(_selectedDate == null ? "Select Date & Time" : "${_selectedDate!.toLocal().toString().split(' ')[0]} ${_selectedTime!.format(context)}"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration & Hours
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Duration Type", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedDuration,
                                  items: ['Hourly', 'Daily', 'Weekly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (val) => setState(() => _selectedDuration = val ?? ''),
                                  decoration: const InputDecoration(border: OutlineInputBorder()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Estimated Hours", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _hoursController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "e.g. 4"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tasks
                      const Text("Specific Tasks (comma separated)", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tasksController,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "e.g. Feeding, Bathing, Medication"),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text("Additional Notes", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Any other details..."),
                      ),
                      const SizedBox(height: 16),

                      // Emergency Checkbox
                      Row(
                        children: [
                          Checkbox(value: _isEmergency, onChanged: (val) => setState(() => _isEmergency = val ?? false)),
                          const Text("This is an Emergency", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),

                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => _handleSubmit(viewModel),
                          child: const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
