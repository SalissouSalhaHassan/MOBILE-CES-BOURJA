import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class DirectChatScreen extends StatefulWidget {
  final int recipientId;
  final String recipientName;
  final String? recipientRole;

  const DirectChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientRole,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  bool _isWorkingHours = true;
  String _workingHoursMsg = '';
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson(
        '/api/mobile/messaging/direct?recipientId=${widget.recipientId}',
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _isWorkingHours = data['isWorkingHours'] ?? true;
          _workingHoursMsg = data['workingHoursMessage'] ?? '';
          _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading direct messages: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _isSending = true;
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'content': text,
        'createdAt': DateTime.now().toIso8601String(),
        'isMine': true,
      });
    });
    _scrollToBottom();

    try {
      final res = await _apiClient.postJson('/api/mobile/messaging/direct', {
        'recipientId': widget.recipientId,
        'content': text,
      });

      if (res['data']?['autoReply'] != null) {
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch + 1,
            'content': res['data']['autoReply'],
            'createdAt': DateTime.now().toIso8601String(),
            'isMine': false,
            'isAutoReply': true,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error sending direct message: $e");
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text(
                widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 3.5,
                        backgroundColor: _isWorkingHours ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isWorkingHours ? 'En service (Disponible)' : 'Hors permanence',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isWorkingHours ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Office Hours Banner if outside working hours
          if (!_isWorkingHours && _workingHoursMsg.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _workingHoursMsg,
                      style: const TextStyle(color: Color(0xFF92400E), fontSize: 11.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Démarrez la conversation avec ${widget.recipientName}',
                              style: const TextStyle(color: AppColors.slate600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMine = msg['isMine'] == true;
                          final isAuto = msg['isAutoReply'] == true;

                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF2563EB)
                                    : isAuto
                                        ? const Color(0xFFFEF3C7)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isMine ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (isAuto)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Réponse automatique',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(
                                      color: isMine
                                          ? Colors.white
                                          : isAuto
                                              ? const Color(0xFF92400E)
                                              : AppColors.slate800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message...',
                          hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _isSending ? null : _sendMessage,
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
