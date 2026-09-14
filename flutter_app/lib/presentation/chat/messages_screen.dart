import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/glass_container.dart';
import '../widgets/caregiver_avatar.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildGlassAppBar(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D3B66),
              Color(0xFF1A5276),
              Color(0xFF1E8BC3),
              Color(0xFF52BE80),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: uid == null
            ? const Center(child: Text("Not signed in", style: TextStyle(color: Colors.white)))
            : SafeArea(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('clientId', isEqualTo: uid)
                      .orderBy('requestedTime', descending: true)
                      .snapshots(),
                  builder: (context, clientSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bookings')
                          .where('caregiverId', isEqualTo: uid)
                          .orderBy('requestedTime', descending: true)
                          .snapshots(),
                      builder: (context, caregiverSnap) {
                        if (clientSnap.connectionState == ConnectionState.waiting ||
                            caregiverSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }

                        // Merge both streams, deduplicate by booking id
                        final allDocs = [
                          ...?clientSnap.data?.docs,
                          ...?caregiverSnap.data?.docs,
                        ];
                        final seen = <String>{};
                        final bookings = allDocs.where((d) => seen.add(d.id)).toList();

                        if (bookings.isEmpty) {
                          return _emptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: bookings.length,
                          itemBuilder: (context, i) {
                            final data = bookings[i].data() as Map<String, dynamic>;
                            final bookingId = bookings[i].id;
                            return _buildConversationTile(context, bookingId, data, uid);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: Colors.white.withOpacity(0.12),
            elevation: 0,
            title: const Text(
              'Messages',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: Colors.white.withOpacity(0.25)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
    String uid,
  ) {
    final isClient = data['clientId'] == uid;
    // Show the other party's name: caregiver sees client name and vice versa
    final otherName = isClient
        ? (data['caregiverName'] as String? ?? 'Caregiver')
        : (data['clientName'] as String? ?? 'Client');
    final otherImageUrl = isClient
        ? (data['caregiverImageUrl'] as String? ?? '')
        : (data['clientImageUrl'] as String? ?? '');
    final status = data['status'] as String? ?? 'PENDING';
    final category = data['careCategory'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 18,
        blur: 20,
        child: InkWell(
          onTap: () => context.push('/chat', extra: bookingId),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CaregiverAvatar(
                  name: otherName,
                  imageUrl: otherImageUrl,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.isNotEmpty ? category : 'Care booking',
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    switch (status) {
      case 'ACTIVE':
        color = const Color(0xFF52BE80);
        break;
      case 'COMPLETED':
        color = Colors.blueAccent;
        break;
      case 'CANCELLED':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text(
            "No conversations yet",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "Book a caregiver to start chatting",
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
