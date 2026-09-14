import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'wallet_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('My Wallet', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : Column(
                  children: [
                    // Balance Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.green, darkBlue]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      width: double.infinity,
                      child: Column(
                        children: [
                          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("LKR ${state.balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Transaction History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                      ),
                    ),
                    // Transactions List
                    Expanded(
                      child: state.transactions.isEmpty
                          ? const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.transactions.length,
                              itemBuilder: (context, index) {
                                final tx = state.transactions[index];
                                final isCredit = tx.type == "CREDIT";
                                final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
                                final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCredit ? Colors.green[100] : Colors.red[100],
                                      child: Icon(
                                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                        color: isCredit ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    trailing: Text(
                                      "${isCredit ? '+' : '-'} LKR ${tx.amount}",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
