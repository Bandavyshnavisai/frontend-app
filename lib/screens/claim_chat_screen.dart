import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ClaimChatScreen extends StatefulWidget {
  final String claimId;
  const ClaimChatScreen({super.key, required this.claimId});

  @override
  State<ClaimChatScreen> createState() => _ClaimChatScreenState();
}

class _ClaimChatScreenState extends State<ClaimChatScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchChat();
    // Simple polling for new messages (since we are using REST API)
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollChat());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChat() async {
    try {
      final messages = await ApiService.getClaimChat(widget.claimId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
      }
    }
  }

  Future<void> _pollChat() async {
    try {
      final messages = await ApiService.getClaimChat(widget.claimId);
      if (mounted && messages.length != _messages.length) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    // Optimistic UI update
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderId': _currentUserId,
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      await ApiService.sendChatMessage(widget.claimId, text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
      _fetchChat(); // Revert on failure
    }
  }

  String _formatTime(dynamic dateData) {
    if (dateData == null) return '';
    try {
      if (dateData is Map && dateData['_seconds'] != null) {
        final sec = dateData['_seconds'] as int;
        return DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(sec * 1000));
      }
      return DateFormat.Hm().format(DateTime.parse(dateData.toString()));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop()),
        title: const Text('Claim Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? const Center(child: Text('No messages yet. Start the conversation!', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['senderId'] == _currentUserId || msg['senderId'] == 'user'; // fallback for 'user' if backend doesn't save uid properly
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white : const Color(0xFF1E1E2F),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['content'] ?? '',
                                style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg['timestamp']),
                                style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.send, color: Colors.black, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
