import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'bookings_view_model.dart';
import '../../domain/model/data_models.dart';
import '../auth/login_screen.dart'; // For colors

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingsViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('My Bookings', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : state.errorMessage != null
                  ? Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)))
                  : state.bookings.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("No bookings found", style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.bookings.length,
                          itemBuilder: (context, index) {
                            final booking = state.bookings[index];
                            return _buildBookingCard(context, booking, viewModel);
                          },
                        ),
        );
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, BookingsViewModel viewModel) {
    Color statusColor;
    switch (booking.status) {
      case "PENDING":
      case "BROADCASTED":
        statusColor = Colors.orange;
        break;
      case "ACCEPTED":
        statusColor = Colors.blue;
        break;
      case "IN_PROGRESS":
        statusColor = Colors.green;
        break;
      case "COMPLETED":
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    String formattedTime = "ASAP";
    if (booking.scheduledTime > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(booking.scheduledTime);
      formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    }

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(booking.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (booking.isEmergency)
                  const Icon(Icons.warning, color: Colors.red, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(booking.careCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(formattedTime, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("LKR ${booking.totalAmount}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            if (booking.status == "ACCEPTED")
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    // Logic for caregiver to start or client to view code
                    _showStartJobDialog(context, booking, viewModel);
                  },
                  child: const Text("Start Job / View Code", style: TextStyle(color: Colors.white)),
                ),
              ),

            if (booking.status == "IN_PROGRESS")
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text("Chat", style: TextStyle(color: Colors.white)),
                          onPressed: () => context.push('/chat', extra: booking.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          icon: const Icon(Icons.notes, color: Colors.white),
                          label: const Text("Care Log", style: TextStyle(color: Colors.white)),
                          onPressed: () => context.push('/care_log', extra: {'bookingId': booking.id, 'elderId': booking.clientId}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        _showEndJobDialog(context, booking, viewModel);
                      },
                      child: const Text("End Job", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              
            if (booking.status == "COMPLETED" && !booking.isRated)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Show Rating Dialog
                  },
                  child: const Text("Rate Caregiver"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStartJobDialog(BuildContext context, Booking booking, BookingsViewModel viewModel) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Start Job"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ask the client for the start code, or if you are the client, provide this code to the caregiver:"),
              const SizedBox(height: 12),
              Text(booking.startCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: "Enter Start Code (Caregiver)", border: OutlineInputBorder()),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                viewModel.startJob(booking.id, booking.startCode, codeController.text, (success, msg) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                });
              },
              child: const Text("Start"),
            )
          ],
        );
      }
    );
  }

  void _showEndJobDialog(BuildContext context, Booking booking, BookingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("End Job"),
          content: const Text("Are you sure you want to end this job now?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                viewModel.endJobByClientWithVerification(
                  bookingId: booking.id,
                  approvedTasks: booking.completedTasks,
                  hasComplaint: false,
                  complaintNotes: "",
                  totalAmount: booking.totalAmount,
                  onResult: (success, msg) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                );
              },
              child: const Text("End Job", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }
    );
  }
}
