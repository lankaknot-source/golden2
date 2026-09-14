import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'care_log_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class CareLogScreen extends StatefulWidget {
  final String bookingId;
  final String elderId;

  const CareLogScreen({super.key, required this.bookingId, required this.elderId});

  @override
  State<CareLogScreen> createState() => _CareLogScreenState();
}

class _CareLogScreenState extends State<CareLogScreen> {
  final _bpController = TextEditingController();
  final _sugarController = TextEditingController();
  final _tempController = TextEditingController();
  final _mealController = TextEditingController();
  final _notesController = TextEditingController();
  bool _medicationGiven = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CareLogViewModel>().loadLogsForBooking(widget.bookingId);
    });
  }

  @override
  void dispose() {
    _bpController.dispose();
    _sugarController.dispose();
    _tempController.dispose();
    _mealController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Daily Care Logs', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: darkBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              // TODO: Implement PDF generation
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Generation coming soon!")));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: logoGreen,
        onPressed: () => _showAddLogDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Consumer<CareLogViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }

          final logs = viewModel.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No care logs recorded yet.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
              final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Divider(),
                      if (log.bloodPressure.isNotEmpty) Text("BP: ${log.bloodPressure}"),
                      if (log.sugarLevel.isNotEmpty) Text("Sugar: ${log.sugarLevel}"),
                      if (log.temperature.isNotEmpty) Text("Temp: ${log.temperature}"),
                      if (log.mealStatus.isNotEmpty) Text("Meals: ${log.mealStatus}"),
                      Text("Medication Given: ${log.medicationGiven ? 'Yes' : 'No'}"),
                      if (log.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text("Notes: ${log.notes}", style: const TextStyle(color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add Care Log"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: _bpController, decoration: const InputDecoration(labelText: "Blood Pressure (e.g. 120/80)")),
                    TextField(controller: _sugarController, decoration: const InputDecoration(labelText: "Sugar Level")),
                    TextField(controller: _tempController, decoration: const InputDecoration(labelText: "Temperature")),
                    TextField(controller: _mealController, decoration: const InputDecoration(labelText: "Meal Status (e.g. Ate well)")),
                    SwitchListTile(
                      title: const Text("Medication Given?"),
                      value: _medicationGiven,
                      onChanged: (val) => setState(() => _medicationGiven = val),
                    ),
                    TextField(controller: _notesController, decoration: const InputDecoration(labelText: "Additional Notes"), maxLines: 3),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    context.read<CareLogViewModel>().addLog(
                      bookingId: widget.bookingId,
                      elderId: widget.elderId,
                      bloodPressure: _bpController.text,
                      sugarLevel: _sugarController.text,
                      temperature: _tempController.text,
                      mealStatus: _mealController.text,
                      medicationGiven: _medicationGiven,
                      notes: _notesController.text,
                      onResult: (success, msg) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        if (success) {
                          _bpController.clear();
                          _sugarController.clear();
                          _tempController.clear();
                          _mealController.clear();
                          _notesController.clear();
                          _medicationGiven = false;
                        }
                      }
                    );
                  },
                  child: const Text("Save Log"),
                )
              ],
            );
          }
        );
      }
    );
  }
}
