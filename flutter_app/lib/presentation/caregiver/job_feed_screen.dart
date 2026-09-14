import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'job_feed_view_model.dart';
import '../../domain/model/data_models.dart';
import '../auth/login_screen.dart'; // For colors

class JobFeedScreen extends StatelessWidget {
  const JobFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<JobFeedViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('Job Feed', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : state.errorMessage != null
                  ? Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)))
                  : state.jobs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("No new job requests", style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.jobs.length,
                          itemBuilder: (context, index) {
                            final job = state.jobs[index];
                            return _buildJobCard(context, job, viewModel);
                          },
                        ),
        );
      },
    );
  }

  Widget _buildJobCard(BuildContext context, Booking job, JobFeedViewModel viewModel) {
    final isEmergency = job.isEmergency;
    final isDirect = job.status == "PENDING" && job.caregiverId?.isNotEmpty == true;
    
    String formattedTime = "ASAP";
    if (job.scheduledTime > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(job.scheduledTime);
      formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isEmergency ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
      ),
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
                  decoration: BoxDecoration(
                    color: isEmergency ? Colors.red : (isDirect ? Colors.orange : Colors.lightBlue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEmergency ? "EMERGENCY" : (isDirect ? "DIRECT REQUEST" : "NEW JOB"),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  job.isSubscriptionBooking ? "Subscription Job" : "LKR ${job.totalAmount}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: job.isSubscriptionBooking ? Colors.purple : Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(job.careCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(formattedTime, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text("Est. Hours: ${job.estimatedHours}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            const Text("Tasks:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(job.requestedTasks.join(', '), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            if (job.jobDescription.isNotEmpty) ...[
              const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(job.jobDescription, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      viewModel.rejectJob(job.id, (success, msg) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      });
                    },
                    child: const Text("Reject"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: logoGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      viewModel.acceptJob(job.id, (success, msg) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        if (success) {
                          // Job accepted, optionally pop or redirect
                        }
                      });
                    },
                    child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
