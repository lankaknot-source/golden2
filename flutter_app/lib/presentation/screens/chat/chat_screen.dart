import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ChatScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider)!;

    _msgCtrl.clear();
    setState(() => _isSending = true);

    await ref.read(chatNotifierProvider.notifier).sendMessage(
          ChatMessage(
            id: '',
            bookingId: widget.bookingId,
            senderId: user.uid,
            senderName: user.name,
            text: text,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: source, imageQuality: 70, maxWidth: 600);
    if (xfile == null) return;

    final user = ref.read(currentUserProvider)!;
    setState(() => _isUploadingImage = true);
    try {
      final bytes = await File(xfile.path).readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await ref.read(chatNotifierProvider.notifier).sendMessage(
            ChatMessage(
              id: '',
              bookingId: widget.bookingId,
              senderId: user.uid,
              senderName: user.name,
              text: '',
              imageUrl: base64Str,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Camera', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Gallery', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final messagesAsync = ref.watch(messagesProvider(widget.bookingId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Chat',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          if (_isUploadingImage)
            LinearProgressIndicator(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              color: AppColors.primary,
            ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 56, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == user.uid;
                    final ts = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
                    final showDate = i == 0 ||
                        !_sameDay(
                          DateTime.fromMillisecondsSinceEpoch(messages[i - 1].timestamp),
                          ts,
                        );
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: ts),
                        _MessageBubble(message: msg, isMine: isMine),
                      ],
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          _InputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
            onImageTap: _showImageSourceSheet,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final label = isToday ? 'Today' : DateFormat('d MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Poppins'),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  String _formatTs(int ms) {
    final ts = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final isToday = ts.year == now.year && ts.month == now.month && ts.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(ts);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = ts.year == yesterday.year &&
        ts.month == yesterday.month &&
        ts.day == yesterday.day;
    if (isYesterday) return 'Yesterday ${DateFormat('h:mm a').format(ts)}';
    return DateFormat('EEE h:mm a').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: hasImage
            ? _Base64ImageContent(
                base64Str: message.imageUrl!,
                isMine: isMine,
                timestamp: _formatTs(message.timestamp),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMine)
                      Text(
                        message.senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMine ? Colors.white : AppColors.textPrimary,
                        fontFamily: 'Poppins',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTs(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine ? Colors.white60 : AppColors.textHint,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Base64ImageContent extends StatelessWidget {
  final String base64Str;
  final bool isMine;
  final String timestamp;

  const _Base64ImageContent({
    required this.base64Str,
    required this.isMine,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    // Handle data:image/jpeg;base64, prefix
    final clean = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    final bytes = base64Decode(clean);

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isMine ? 16 : 4),
        bottomRight: Radius.circular(isMine ? 4 : 16),
      ),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              width: 220, height: 180,
              color: AppColors.shimmerBase,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.textHint, size: 40),
            ),
          ),
          Positioned(
            bottom: 6, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timestamp,
                style: const TextStyle(
                    fontSize: 10, color: Colors.white70, fontFamily: 'Poppins'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onImageTap;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          8, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded,
                color: AppColors.primary, size: 26),
            onPressed: onImageTap,
            tooltip: 'Send image',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(
                    color: AppColors.textHint, fontFamily: 'Poppins'),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: isSending
                ? const Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    onPressed: onSend,
                  ),
          ),
        ],
      ),
    );
  }
}
